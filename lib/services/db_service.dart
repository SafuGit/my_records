import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/record.dart';

class DBService {
  static Database? _db;

  static Future<Database> getDb() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'myrecords.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records(
            id TEXT PRIMARY KEY,
            type TEXT,
            title TEXT,
            description TEXT,
            subject TEXT,
            date TEXT,
            maxMarks INTEGER,
            obtainedMarks INTEGER,
            completed INTEGER,
            amount REAL,
            category TEXT,
            images TEXT,
            createdAt TEXT,
            updatedAt TEXT,
            syncPending INTEGER
          )

          CREATE INDEX idx_updatedAt ON records(updatedAt);
          CREATE INDEX idx_type ON records(type);
          CREATE INDEX idx_date ON records(date);
        ''');
      },
    );
    return _db!;
  }

  static Future<void> insertRecord(Record r, {bool syncPending = true}) async {
    final db = await getDb();
    await db.insert('records', {
      ...r.toJson(),
      'syncPending': syncPending ? 1 : 0,
      'images': jsonEncode(r.images ?? []),
      'completed': r.completed == true ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateRecord(Record r, {bool syncPending = true}) async {
    final db = await getDb();
    await db.update(
      'records',
      {
        ...r.toJson(),
        'syncPending': syncPending ? 1 : 0,
        'images': jsonEncode(r.images ?? []),
        'completed': r.completed == true ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [r.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Record>> getAllRecords() async {
    final db = await getDb();
    final maps = await db.query('records');
    return maps.map((m) {
      final record = Record.fromJson({
        ...m,
        'images': jsonDecode(m['images'] as String),
        'completed': (m['completed'] as int?) == 1,
        'syncPending': (m['syncPending'] as int?) == 1,
      });
      return record;
    }).toList();
  }

  static Future<List<Record>> getPendingSyncRecords() async {
    final db = await getDb();
    final maps = await db.query(
      'records',
      where: 'syncPending = ?',
      whereArgs: [1],
      orderBy: 'updatedAt ASC',
    );
    return maps.map((m) {
      return Record.fromJson({
        ...m,
        'images': jsonDecode((m['images'] as String?) ?? '[]'),
        'completed': (m['completed'] as int?) == 1,
        'syncPending': (m['syncPending'] as int?) == 1,
      });
    }).toList();
  }

  static Future<Record?> getRecordById(String id) async {
    final db = await getDb();
    final maps = await db.query(
      'records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final m = maps.first;
    return Record.fromJson({
      ...m,
      'images': jsonDecode((m['images'] as String?) ?? '[]'),
      'completed': (m['completed'] as int?) == 1,
      'syncPending': (m['syncPending'] as int?) == 1,
    });
  }

  static Future<void> markAsSynced(String id) async {
    final db = await getDb();
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'records',
      {
        'syncPending': 0,
        'updatedAt': nowIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markAllAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await getDb();
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.update(
          'records',
          {'syncPending': 0, 'updatedAt': nowIso},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<void> deleteRecord(String id) async {
    final db = await getDb();
    await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}
