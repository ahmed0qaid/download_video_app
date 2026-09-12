import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

class MediaJobStore {
  MediaJobStore({DatabaseFactory? databaseFactory, String? databasePath})
      : _databaseFactory = databaseFactory,
        _databasePath = databasePath;

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;

    final factory = _databaseFactory ?? databaseFactory;
    final root = _databasePath == null ? await factory.getDatabasesPath() : null;
    final database = await factory.openDatabase(
      _databasePath ?? p.join(root!, 'download_video_app.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
CREATE TABLE media_jobs (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  title TEXT NOT NULL,
  formatLabel TEXT NOT NULL,
  formatSelector TEXT NOT NULL,
  audioFormat TEXT,
  thumbnail TEXT,
  createdAt INTEGER NOT NULL,
  state TEXT NOT NULL,
  progress INTEGER NOT NULL,
  etaSeconds INTEGER,
  outputPath TEXT,
  error TEXT,
  sizeBytes INTEGER,
  playlist INTEGER NOT NULL,
  wifiOnly INTEGER NOT NULL,
  useAria2 INTEGER NOT NULL
)
''');
          await db.execute(
            'CREATE INDEX media_jobs_created_at ON media_jobs(createdAt DESC)',
          );
        },
      ),
    );
    _database = database;
    return database;
  }

  Future<List<MediaJob>> loadAll() async {
    final rows = await (await _db).query(
      'media_jobs',
      orderBy: 'createdAt DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(MediaJob job) async {
    await (await _db).insert(
      'media_jobs',
      _toRow(job),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(Iterable<MediaJob> jobs) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final job in jobs) {
        await txn.insert(
          'media_jobs',
          _toRow(job),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> delete(String id) async {
    await (await _db).delete('media_jobs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  static MediaJob _fromRow(Map<String, Object?> row) {
    return MediaJob.fromMap({
      ...row,
      'playlist': row['playlist'] == 1,
      'wifiOnly': row['wifiOnly'] == 1,
      'useAria2': row['useAria2'] == 1,
    });
  }

  static Map<String, Object?> _toRow(MediaJob job) {
    return {
      ...job.toMap(),
      'playlist': job.playlist ? 1 : 0,
      'wifiOnly': job.wifiOnly ? 1 : 0,
      'useAria2': job.useAria2 ? 1 : 0,
    };
  }
}
