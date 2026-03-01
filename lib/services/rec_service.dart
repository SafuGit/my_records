// ignore_for_file: unintended_html_in_doc_comment

import 'dart:convert';

import 'package:my_records/models/academic.rec.dart';
import 'package:my_records/models/record.dart';

/*
academic.rec schema (DO NOT REMOVE – used as documentation):

{
  "version": 1,
  "exportedAt": "2026-03-01T10:00:00Z",
  "deviceId": "device_abc123",
  "authId": "user@gmail.com",        // Google Drive / auth identifier
  "records": [
    { ...record1... },
    { ...record2... }
  ]
}

records:
{
  "id": "a1b2c3d4-e5f6-7890-1234-56789abcdef0",
  "type": "exam",     // "exam" | "homework" | "due"
  "title": "Math Final Exam",
  "description": "Chapter 1-10, multiple choice + essay",
  "subject": "Mathematics",
  "date": "2026-03-15T10:00:00Z",
  "maxMarks": 100,      // exam only
  "obtainedMarks": 88,  // exam only
  "completed": false,   // homework only
  "amount": null,       // due only
  "category": null,
  "images": ["base64string1", "base64string2"],
  "createdAt": "2026-02-28T12:00:00Z",
  "updatedAt": "2026-02-28T12:00:00Z"
}
*/

/// [RecService] owns the in-memory academic record store and manages
/// serialization, deserialization, and conflict-resolution merging of
/// `.rec` files.
///
/// Design principles:
/// ─ Map<String, Record> as primary store for O(1) insert / lookup / delete.
/// ─ Export and import are both O(n + m): n = records, m = total images.
/// ─ Conflict resolution is last-writer-wins on [Record.updatedAt].
/// ─ Image deduplication uses Set<String> for O(m) uniqueness checks.
/// ─ All mutations are synchronous; exportRec() is async-compatible for
///   future I/O work (e.g. file write, network upload).
class RecService {
  // Keyed by record.id for O(1) access on every operation.
  final Map<String, Record> _records = {};

  String _deviceId = '';
  String _authId = '';

  /// Must be called once before export/import to set device and auth identity.
  void init({required String deviceId, required String authId}) {
    _deviceId = deviceId;
    _authId = authId;
  }

  /// Returns an unmodifiable view of all in-memory records. O(1) – no copy.
  Map<String, Record> getRecords() => Map.unmodifiable(_records);

  /// Returns a single record by [id], or null if absent. O(1).
  Record? getRecord(String id) => _records[id];

  /// Loads a record directly into memory, preserving its [syncPending] state.
  /// Intended for seeding from DB on startup — does NOT set syncPending=true.
  /// O(1).
  void seedRecord(Record r) => _records[r.id] = r;

  /// Inserts or replaces a record. Marks it [syncPending] = true. O(1).
  void upsertRecord(Record record) {
    _records[record.id] = Record(
      id: record.id,
      type: record.type,
      title: record.title,
      description: record.description,
      subject: record.subject,
      date: record.date,
      maxMarks: record.maxMarks,
      obtainedMarks: record.obtainedMarks,
      completed: record.completed,
      amount: record.amount,
      category: record.category,
      images: record.images,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      syncPending: true, // flag for next incremental export / DB sync
    );
  }

  /// Removes a record by [id]. O(1).
  void deleteRecord(String id) => _records.remove(id);

  /// Clears all records from memory.
  void clearRecords() => _records.clear();

  /// Clears the [syncPending] flag for a single record in memory. O(1).
  /// No-op when [id] is not present.
  void markSynced(String id) {
    final Record? r = _records[id];
    if (r == null) return;
    _records[id] = Record(
      id: r.id,
      type: r.type,
      title: r.title,
      description: r.description,
      subject: r.subject,
      date: r.date,
      maxMarks: r.maxMarks,
      obtainedMarks: r.obtainedMarks,
      completed: r.completed,
      amount: r.amount,
      category: r.category,
      images: r.images,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      syncPending: false,
    );
  }

  /// Clears [syncPending] for a batch of [ids]. O(k) where k = ids.length.
  void markAllSynced(List<String> ids) {
    for (final String id in ids) {
      markSynced(id);
    }
  }

  /// Serialises in-memory records into a `.rec` JSON string.
  ///
  /// [onlyPending] – when true, only records with [syncPending] == true are
  /// included, enabling lightweight incremental exports.
  ///
  /// Complexity: O(n) — single linear pass over the record map.
  Future<String> exportRec({bool onlyPending = false}) async {
    final DateTime now = DateTime.now().toUtc();

    // O(n) filter + map; short-circuits to identity when onlyPending=false.
    final Iterable<Record> toExport = onlyPending
        ? _records.values.where((r) => r.syncPending == true)
        : _records.values;

    final AcademicRec bundle = AcademicRec(
      exportedAt: now,
      deviceId: _deviceId,
      authId: _authId,
      records: {for (final r in toExport) r.id: r},
    );

    // jsonEncode performs a single O(n) serialisation pass.
    return jsonEncode(bundle.toJson());
  }

  /// Parses a `.rec` JSON string and merges its records into memory.
  ///
  /// Merge algorithm (O(n + m)):
  ///   For each incoming record:
  ///   1. O(1) lookup in [_records] by id.
  ///   2. No existing record → insert directly.
  ///   3. Conflict → keep the record with the later [updatedAt] (LWW).
  ///      Ties are broken in favour of the incoming record.
  ///   4. Regardless of winner, images from both sides are union-merged
  ///      via Set<String> to preserve attachments. O(m_i) per record.
  ///
  /// All mutating state is applied only after successful per-record parsing,
  /// so a single bad record does not roll back previously merged records.
  ///
  /// Edge cases handled:
  ///   • Corrupted / non-JSON input         → warns, returns without mutation.
  ///   • Missing required fields (id/type/title) → skips that record, warns.
  ///   • Future-dated [updatedAt]            → clamped to now, warns.
  ///   • Self-import (same deviceId)         → warns, continues.
  ///   • Unknown .rec version                → warns, still attempts parse.
  ///
  /// Complexity: O(n + m) — n records, m total images.
  void importRec(String jsonString) {
    // Step 1: Parse outer JSON 
    final Map<String, dynamic> raw;
    try {
      raw = jsonDecode(jsonString) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _warn('importRec: corrupted .rec JSON — ${e.message}');
      return;
    } catch (e) {
      _warn('importRec: unexpected parse error — $e');
      return;
    }

    // Step 2: Header validation
    final int version = (raw['version'] as num?)?.toInt() ?? 1;
    if (version != 1) {
      _warn('importRec: unknown .rec version $version — attempting parse anyway.');
    }

    final String incomingDeviceId = raw['deviceId'] as String? ?? '';
    if (incomingDeviceId.isNotEmpty &&
        _deviceId.isNotEmpty &&
        incomingDeviceId == _deviceId) {
      _warn('importRec: deviceId matches this device ($incomingDeviceId) — possible self-import.');
    }

    // Step 3: Validate records list
    final dynamic rawList = raw['records'];
    if (rawList == null || rawList is! List) {
      _warn('importRec: "records" field is missing or not a list.');
      return;
    }

    final DateTime now = DateTime.now().toUtc();

    // Step 4: Merge each record — O(n) outer loop
    for (final dynamic entry in rawList) {
      if (entry is! Map<String, dynamic>) {
        _warn('importRec: skipping non-object record entry.');
        continue;
      }

      final Record incoming;
      try {
        incoming = _parseRecordSafe(entry, now);
      } catch (e) {
        _warn('importRec: skipping record — $e');
        continue;
      }

      final Record? existing = _records[incoming.id]; // O(1)

      if (existing == null) {
        // No conflict: insert directly.
        _records[incoming.id] = incoming;
      } else {
        // Conflict: last-writer-wins on updatedAt; ties favour incoming.
        // Also union-merge images from both sides regardless of LWW winner.
        if (!incoming.updatedAt.isBefore(existing.updatedAt)) {
          _records[incoming.id] = _unionImages(primary: incoming, secondary: existing);
        } else {
          _records[existing.id] = _unionImages(primary: existing, secondary: incoming);
        }
      }
    }
  }

  // Private helpers 

  /// Returns [primary] with any images from [secondary] that are not already
  /// present appended to the end of the image list.
  ///
  /// Uses Set<String> for O(m) deduplication where m = total combined images.
  /// Returns [primary] unchanged if [secondary] contributes no new images.
  Record _unionImages({required Record primary, required Record secondary}) {
    final List<String> primaryImages = primary.images ?? const [];
    final List<String> secondaryImages = secondary.images ?? const [];

    if (secondaryImages.isEmpty) return primary;

    // Seed a Set with primary images; O(p) where p = primary image count.
    final Set<String> seen = primaryImages.toSet();
    List<String>? merged;

    for (final String img in secondaryImages) {
      // Set.add returns true only when the element is genuinely new.
      if (seen.add(img)) {
        // Lazy-initialise to avoid an allocation when nothing is new.
        merged ??= List<String>.from(primaryImages);
        merged.add(img);
      }
    }

    // No new images were found — return the original reference unchanged.
    if (merged == null) return primary;

    return Record(
      id: primary.id,
      type: primary.type,
      title: primary.title,
      description: primary.description,
      subject: primary.subject,
      date: primary.date,
      maxMarks: primary.maxMarks,
      obtainedMarks: primary.obtainedMarks,
      completed: primary.completed,
      amount: primary.amount,
      category: primary.category,
      images: merged,
      createdAt: primary.createdAt,
      updatedAt: primary.updatedAt,
      // Image union added new attachments not yet in DB/remote → must re-sync.
      syncPending: true,
    );
  }

  /// Converts a raw JSON map into a [Record], applying safe defaults for
  /// optional fields and clamping any future-dated timestamps to [now].
  ///
  /// Throws [FormatException] if a required field (id / type / title) is
  /// absent or empty, so the caller can skip this record and log a warning.
  Record _parseRecordSafe(Map<String, dynamic> json, DateTime now) {
    final String id = _requireString(json, 'id');
    final String type = _requireString(json, 'type');
    final String title = _requireString(json, 'title');

    final DateTime date = _parseDateTime(json['date'], fallback: now);
    final DateTime createdAt = _parseDateTime(json['createdAt'], fallback: now);
    DateTime updatedAt = _parseDateTime(json['updatedAt'], fallback: now);

    // Clamp future-dated updatedAt to prevent a rogue record from
    // permanently "winning" every future conflict resolution.
    if (updatedAt.isAfter(now)) {
      _warn('importRec: future-dated updatedAt on record "$id" — clamping to now.');
      updatedAt = now;
    }

    return Record(
      id: id,
      type: type,
      title: title,
      description: json['description'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      date: date,
      maxMarks: (json['maxMarks'] as num?)?.toInt(),
      obtainedMarks: (json['obtainedMarks'] as num?)?.toInt(),
      completed: json['completed'] as bool?,
      amount: (json['amount'] as num?)?.toDouble(),
      category: json['category'] as String?,
      images: json['images'] != null
          ? List<String>.from(json['images'] as List<dynamic>)
          : [],
      createdAt: createdAt,
      updatedAt: updatedAt,
      // syncPending is a DB-only flag; imported records are not pending.
      syncPending: false,
    );
  }

  /// Extracts a required non-empty String field from [json].
  /// Throws [FormatException] when the key is absent, null, or empty.
  String _requireString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Missing or empty required field: "$key"');
  }

  /// Parses an ISO 8601 DateTime string, converting it to UTC.
  /// Returns [fallback] if [value] is null, not a String, or unparseable.
  DateTime _parseDateTime(dynamic value, {required DateTime fallback}) {
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).toUtc();
      } catch (_) {
        _warn('importRec: unparseable datetime "$value" — using fallback.');
      }
    }
    return fallback;
  }

  /// Structured warning logger. Swap out for your preferred logging package
  /// (e.g. package:logging) without changing any call-sites.
  // ignore: avoid_print
  void _warn(String message) => print('[RecService WARN] $message');
}
