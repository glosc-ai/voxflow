import 'dart:io';

import 'package:sqflite/sqflite.dart' show databaseFactorySqflitePlugin;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/path_utils.dart';
import '../models/history_record.dart';

typedef DatabasePathProvider = Future<String> Function();

class HistoryRepository {
  HistoryRepository({
    DatabaseFactory? factory,
    DatabasePathProvider? pathProvider,
  })  : _factory = factory,
        _pathProvider = pathProvider ?? PathUtils.getDatabasePath;

  final DatabaseFactory? _factory;
  final DatabasePathProvider _pathProvider;
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) {
      return _database!;
    }
    try {
      final factory = _factory ?? _platformFactory();
      final path = await _pathProvider();
      _database = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE history_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                text TEXT NOT NULL,
                audio_path TEXT NOT NULL,
                created_at INTEGER NOT NULL
              )
            ''');
            await database.execute('''
              CREATE INDEX history_records_created_at_idx
              ON history_records(created_at DESC)
            ''');
          },
        ),
      );
      return _database!;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法打开本地历史数据库。',
      );
    }
  }

  DatabaseFactory _platformFactory() {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    if (Platform.isAndroid) {
      return databaseFactorySqflitePlugin;
    }
    throw const AppException(
      AppErrorCode.storageFailure,
      '当前平台不支持历史数据库。',
    );
  }

  Future<HistoryRecord> insert(HistoryRecord record) async {
    try {
      final database = await _db;
      final id = await database.insert(
        'history_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return HistoryRecord(
        id: id,
        type: record.type,
        text: record.text,
        audioPath: record.audioPath,
        createdAt: record.createdAt,
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法保存历史记录。',
      );
    }
  }

  Future<List<HistoryRecord>> search([String query = '']) async {
    try {
      final database = await _db;
      final trimmed = query.trim();
      final rows = await database.query(
        'history_records',
        where:
            trimmed.isEmpty ? null : "text LIKE ? ESCAPE '\\' COLLATE NOCASE",
        whereArgs: trimmed.isEmpty ? null : ['%${_escapeLike(trimmed)}%'],
        orderBy: 'created_at DESC, id DESC',
      );
      return rows.map(HistoryRecord.fromMap).toList(growable: false);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法读取历史记录。',
      );
    }
  }

  Future<void> delete(int id) async {
    try {
      final database = await _db;
      await database.delete(
        'history_records',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法删除历史记录。',
      );
    }
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) {
      try {
        await database.close();
      } catch (_) {
        // Database shutdown is best-effort during provider disposal.
      }
    }
  }

  static String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
