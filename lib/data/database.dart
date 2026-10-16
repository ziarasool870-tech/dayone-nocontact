/// Local SQLite database for Day One: No Contact.
///
/// Everything stays on the device. Tables:
/// - streak_history: closed streak periods (relapse history — never erased)
/// - checkins: one row per calendar day (held 0/1, mood 0-4)
/// - journal: dated free-text entries
///
/// Simple settings (name, start date, onboarding flag, pro status) live in
/// SharedPreferences via [PrefsService], not here.
library;

import 'package:sqflite/sqflite.dart';

class DayOneDatabase {
  DayOneDatabase._();

  static final DayOneDatabase instance = DayOneDatabase._();

  static const _version = 2;
  Database? _db;

  Future<Database> get database async {
    final db = _db;
    if (db != null) return db;
    return _db = await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    // Join manually to avoid the `path` dependency.
    final path = '$dir/day_one.db';
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2(db);
        }
      },
    );
  }

  /// v1 tables: streak_history, checkins, journal.
  Future<void> _createV1(Database db) async {
    await db.execute('''
          CREATE TABLE streak_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            days INTEGER NOT NULL
          )
        ''');
    await db.execute('''
          CREATE TABLE checkins(
            date TEXT PRIMARY KEY,
            held INTEGER NOT NULL,
            mood INTEGER NOT NULL DEFAULT 2
          )
        ''');
    await db.execute('''
          CREATE TABLE journal(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_ms INTEGER NOT NULL,
            updated_ms INTEGER NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT ''
          )
        ''');
  }

  /// v2: letter vault (unsent letters).
  Future<void> _createV2(Database db) async {
    await db.execute('''
          CREATE TABLE letters(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_ms INTEGER NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT ''
          )
        ''');
  }

  // ---------------------------------------------------------------- check-ins

  /// Upserts today's check-in. [date] is `yyyy-MM-dd` in local time.
  Future<void> upsertCheckIn(String date,
      {required bool held, required int mood}) async {
    final db = await database;
    await db.insert(
      'checkins',
      {'date': date, 'held': held ? 1 : 0, 'mood': mood},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> checkInFor(String date) async {
    final db = await database;
    final rows =
        await db.query('checkins', where: 'date = ?', whereArgs: [date]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns all check-ins ordered by date ascending.
  Future<List<Map<String, Object?>>> allCheckIns() async {
    final db = await database;
    return db.query('checkins', orderBy: 'date ASC');
  }

  /// Fraction of held check-ins (0.0–1.0). 0 when there are none.
  Future<double> checkInRate() async {
    final db = await database;
    final rows = await db
        .rawQuery('SELECT COUNT(*) AS total, SUM(held) AS held FROM checkins');
    final total = (rows.first['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return 0.0;
    final held = (rows.first['held'] as num?)?.toInt() ?? 0;
    return held / total;
  }

  // ------------------------------------------------------------------- journal

  Future<int> insertJournal(
      {required String title, required String body}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('journal', {
      'created_ms': now,
      'updated_ms': now,
      'title': title,
      'body': body,
    });
  }

  Future<void> updateJournal(
      {required int id, required String title, required String body}) async {
    final db = await database;
    await db.update(
      'journal',
      {
        'title': title,
        'body': body,
        'updated_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteJournal(int id) async {
    final db = await database;
    await db.delete('journal', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes every user row (journal, letters, check-ins, streak history).
  /// Used by "Delete my data" — the tables themselves are kept, so the
  /// app keeps working without a restart.
  Future<void> wipeAll() async {
    final db = await database;
    await db.delete('journal');
    await db.delete('letters');
    await db.delete('checkins');
    await db.delete('streak_history');
  }

  Future<List<Map<String, Object?>>> allJournalEntries() async {
    final db = await database;
    return db.query('journal', orderBy: 'created_ms DESC');
  }

  Future<int> journalCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM journal');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  // -------------------------------------------------------------------- letters
  // Unsent-letter vault: sealed letters the user will never send.

  Future<int> insertLetter({required String title, required String body}) async {
    final db = await database;
    return db.insert('letters', {
      'created_ms': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'body': body,
    });
  }

  Future<List<Map<String, Object?>>> allLetters() async {
    final db = await database;
    return db.query('letters', orderBy: 'created_ms DESC');
  }

  Future<int> letterCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM letters');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteLetter(int id) async {
    final db = await database;
    await db.delete('letters', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ streak history

  Future<void> insertStreakRecord(
      {required int startMs, required int endMs, required int days}) async {
    final db = await database;
    await db.insert('streak_history', {
      'start_ms': startMs,
      'end_ms': endMs,
      'days': days,
    });
  }

  Future<List<Map<String, Object?>>> allStreakHistory() async {
    final db = await database;
    return db.query('streak_history', orderBy: 'end_ms DESC');
  }

  // ------------------------------------------------------------------- backup

  /// Dumps every table for the encrypted export feature.
  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final db = await database;
    return {
      'streak_history': await db.query('streak_history'),
      'checkins': await db.query('checkins'),
      'journal': await db.query('journal'),
      'letters': await db.query('letters'),
    };
  }

  /// Restores tables from an export dump. Wipes current rows first —
  /// the caller must confirm with the user before invoking.
  Future<void> restoreAll(Map<String, dynamic> dump) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in ['streak_history', 'checkins', 'journal', 'letters']) {
        await txn.delete(table);
        final rows = dump[table];
        if (rows is List) {
          for (final row in rows) {
            if (row is Map) {
              await txn.insert(table, Map<String, Object?>.from(row));
            }
          }
        }
      }
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
