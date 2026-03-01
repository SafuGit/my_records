import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:my_records/models/record.dart';
import 'package:my_records/services/db_service.dart';
import 'package:my_records/services/rec_service.dart';

/// [RecSyncManager] is the single entry point for all record mutations.
///
/// It coordinates three data layers:
///
///   ┌─────────────┐   always first   ┌────────────────┐
///   │  RecService │ ◄──────────────► │   SQLite DB    │
///   │  (memory)   │   async persist  │  (DBService)   │
///   └─────────────┘                  └────────────────┘
///          ▲                                ▲
///          │  import/export                 │  batch upsert after import
///          ▼                                │
///   ┌─────────────┐                         │
///   │  .rec file  │─────────────────────────┘
///   └─────────────┘
///
/// Design guarantees:
///   • Memory-first: every mutation hits [RecService] synchronously before
///     any async DB call, so the UI always reads a consistent in-memory state.
///   • DB writes use batch transactions to minimise round-trips.
///   • Import merges are atomic in memory (no await inside the merge loop)
///     and then batch-persisted only for changed records — O(n + m) total.
///   • Export is O(n); optional incremental mode exports only pending records.
///   • markSynced clears syncPending in memory + DB after a confirmed upload.
class RecSyncManager {
  final RecService _rec;

  /// Inject a custom [RecService] instance (e.g. for testing).
  /// Defaults to a fresh [RecService].
  RecSyncManager({RecService? recService}) : _rec = recService ?? RecService();

  /// Unmodifiable view of all in-memory records. O(1) – no copy.
  Map<String, Record> getRecords() => _rec.getRecords();

  /// Returns a single record by [id], or null. O(1).
  Record? getRecord(String id) => _rec.getRecord(id);

  /// Initialises device/auth identity, loads all records from SQLite, and
  /// bootstraps the local `.rec` file if needed.
  ///
  /// Startup logic:
  ///   1. Load all DB rows into memory.
  ///   2. If `academic.rec` **does not exist** → export one from DB records
  ///      so a backup is always present after the first run.
  ///   3. If `academic.rec` **exists** → merge it into memory using LWW
  ///      conflict resolution, then batch-persist any changes back to DB.
  ///
  /// Must be awaited once at app startup before any other call.
  Future<void> initialize({
    required String deviceId,
    required String authId,
  }) async {
    _rec.init(deviceId: deviceId, authId: authId);
    await loadAll(); // Step 1: DB → memory

    final File recFile = await _getDefaultRecFile();
    if (!await recFile.exists()) {
      // Step 2: No .rec file — create one from the current DB contents.
      if (_rec.getRecords().isNotEmpty) {
        await exportRec(); // writes academic.rec, does NOT markSynced
        // ignore: avoid_print
        print('[RecSyncManager] Bootstrap: created .rec from ${_rec.getRecords().length} DB record(s).');
      }
    } else {
      // Step 3: .rec file exists — merge into memory + DB.
      await importRec(); // filePath defaults to academic.rec
    }
  }

  /// Reads all records from SQLite into [RecService] memory.
  ///
  /// Uses [RecService.seedRecord] to preserve the existing [syncPending]
  /// state from DB — no records are spuriously dirtied on startup.
  ///
  /// Complexity: O(n) DB read + O(n) memory seed.
  Future<void> loadAll() async {
    final List<Record> rows = await DBService.getAllRecords(); // O(n)
    _rec.clearRecords();
    for (final Record r in rows) {
      _rec.seedRecord(r); // O(1), preserves syncPending from DB
    }
  }

  /// Inserts or replaces a record in memory and persists it to SQLite.
  ///
  /// Steps:
  ///   1. [RecService.upsertRecord] — synchronous O(1), sets syncPending=true.
  ///   2. [DBService.insertRecord]  — async upsert via ConflictAlgorithm.replace.
  ///
  /// Await this call when guaranteed DB durability is required (e.g. before
  /// navigating away). Fire-and-forget when optimistic UI is acceptable.
  Future<void> addOrUpdateRecord(Record r) async {
    _rec.upsertRecord(r); // memory-first
    await DBService.insertRecord(r, syncPending: true);
  }

  /// Removes a record by [id] from memory and SQLite.
  ///
  /// No-op when the [id] does not exist in either layer.
  Future<void> deleteRecord(String id) async {
    _rec.deleteRecord(id); // O(1) memory remove
    await DBService.deleteRecord(id); // async DB delete
  }

  //File helpers

  /// Returns the canonical [File] handle for the local `.rec` backup.
  /// The file may not exist yet — callers should check [File.exists].
  Future<File> _getDefaultRecFile() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/academic.rec');
  }

  /// Returns the absolute path to the local `.rec` file without creating it.
  /// Useful for sharing / showing the path in UI.
  Future<String> getRecFilePath() async => (await _getDefaultRecFile()).path;

  /// Writes the in-memory records to the local `academic.rec` file.
  ///
  /// Parameters:
  ///   [onlyPending] — when true, only records with syncPending=true are
  ///                   written (incremental/delta export). Default: false.
  ///   [markSynced]  — when true, clears syncPending in memory and DB for
  ///                   every exported record. Only fires after a successful
  ///                   file write, so a failed write never clears flags.
  ///
  /// Exported IDs are captured *before* serialisation so the markSynced set
  /// is always consistent with what was actually written to disk.
  ///
  /// Returns the absolute path of the written `.rec` file.
  ///
  /// Complexity: O(n) serialisation + O(k) sync-clear, where k ≤ n.
  Future<String> exportRec({
    bool onlyPending = false,
    bool markSynced = false,
  }) async {
    // Capture IDs before serialisation to guarantee consistency.
    final List<String> exportedIds = onlyPending
        ? _rec
              .getRecords()
              .values
              .where((r) => r.syncPending == true)
              .map((r) => r.id)
              .toList()
        : _rec.getRecords().keys.toList();

    // O(n) serialisation pass in RecService — returns raw JSON string.
    final String json = await _rec.exportRec(onlyPending: onlyPending);

    // Write JSON to the canonical .rec file location.
    final File file = await _getDefaultRecFile();
    await file.writeAsString(json);
    // ignore: avoid_print
    print('[RecSyncManager] Exported .rec → ${file.path}');

    // Only mark synced after the file write succeeded — prevents silent
    // data loss if writeAsString throws (e.g. out of storage).
    if (markSynced && exportedIds.isNotEmpty) {
      _rec.markAllSynced(exportedIds);                 // O(k) in-memory
      await DBService.markAllAsSynced(exportedIds);    // O(k) DB batch
    }

    return file.path;
  }

  /// Reads a `.rec` file from [filePath] (defaults to the local
  /// `academic.rec`) and merges its records into memory + SQLite.
  ///
  /// Returns `false` if the file does not exist and [silent] is true, or
  /// throws a [FileSystemException] if [silent] is false (default).
  ///
  /// Algorithm (O(n + m) total):
  ///
  ///   Step 0 — Read file from disk.                                    O(1 I/O)
  ///   Step 1 — Snapshot {id → updatedAt} from current memory.          O(n)
  ///   Step 2 — Synchronous LWW merge via [RecService.importRec].       O(n+m)
  ///            • No await inside merge loop → merge is atomic in memory.
  ///            • Conflict resolution: last-writer-wins on updatedAt.
  ///            • Images from both sides are union-merged (Set dedup).
  ///   Step 3 — Diff memory against snapshot to find new/changed records. O(n)
  ///            • New:     id not present in snapshot.
  ///            • Updated: winner's updatedAt is later than snapshot value.
  ///            • Records where existing won but gained images are detected
  ///              because _unionImages sets syncPending=true (and updatedAt
  ///              is unchanged).
  ///   Step 4 — Batch-upsert only the Δ records to SQLite.              O(Δn)
  ///
  /// All JSON-level edge cases (corrupted file, missing fields, future-dated
  /// timestamps, self-import, version mismatch) are handled by [RecService].
  Future<bool> importRec({String? filePath, bool silent = false}) async {
    // Step 0: resolve and read the .rec file.
    final File file =
        filePath != null ? File(filePath) : await _getDefaultRecFile();

    if (!await file.exists()) {
      if (silent) return false;
      throw FileSystemException('importRec: .rec file not found', file.path);
    }

    final String jsonString = await file.readAsString();
    // ignore: avoid_print
    print('[RecSyncManager] Importing .rec ← ${file.path}');

    // Step 1: snapshot {id → updatedAt}. O(n)
    final Map<String, DateTime> snapshot = {
      for (final MapEntry<String, Record> e in _rec.getRecords().entries)
        e.key: e.value.updatedAt,
    };

    // Step 2: synchronous in-memory merge. O(n + m)
    // No await inside → merge is atomic; DB is eventually consistent.
    _rec.importRec(jsonString);

    // Step 3: find records that changed (new OR later updatedAt). O(n)
    //
    // Note: records where only images were union-merged (existing record won)
    // will have syncPending=true (set by _unionImages) even though updatedAt
    // didn't change. We detect those separately via syncPending check.
    final List<Record> changed =
        _rec.getRecords().values.where((Record r) {
      final DateTime? prev = snapshot[r.id];
      if (prev == null) return true;                         // new record
      if (r.updatedAt.isAfter(prev)) return true;           // LWW winner
      if (r.syncPending == true && prev == r.updatedAt) return true; // image merge
      return false;
    }).toList();

    if (changed.isEmpty) return true;

    // Step 4: batch-upsert changed records. O(Δn)
    await _batchUpsertToDb(changed);
    return true;
  }

  /// Batch-upserts [records] into SQLite inside a single transaction.
  ///
  /// All rows are queued synchronously via [Batch], then committed in one
  /// write cycle — minimising DB round-trips compared to per-record inserts.
  ///
  /// Complexity: O(n) where n = records.length.
  Future<void> _batchUpsertToDb(List<Record> records) async {
    if (records.isEmpty) return;
    final Database db = await DBService.getDb();

    await db.transaction((txn) async {
      final Batch batch = txn.batch();

      for (final Record r in records) {
        // Mirror the encoding used by DBService.insertRecord:
        //   • images  → JSON-encoded string (SQLite TEXT column)
        //   • completed → INTEGER 0/1 (SQLite has no BOOLEAN type)
        //   • syncPending → INTEGER 0/1
        batch.insert('records', {
          ...r.toJson(), // base fields (completed/images overridden below)
          'images': jsonEncode(r.images ?? []),
          'completed': r.completed == true ? 1 : 0,
          'syncPending': (r.syncPending == true) ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // noResult=true skips collecting row-IDs, reducing allocation. O(n)
      await batch.commit(noResult: true);
    });
  }
}
