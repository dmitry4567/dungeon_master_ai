import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Локальная база данных SQLite для кэширования
@lazySingleton
class LocalDatabase {
  Database? _database;

  /// Получить экземпляр базы данных
  Database get database {
    if (_database == null) {
      throw StateError('LocalDatabase not initialized. Call init() first.');
    }
    return _database!;
  }

  /// Инициализировать базу данных
  Future<void> init() async {
    if (_database != null) return;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'ai_dungeon_master.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Создание таблиц
  Future<void> _onCreate(Database db, int version) async {
    // Characters cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_characters (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Scenarios cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_scenarios (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Rooms cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_rooms (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Messages cache (for offline access)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_messages (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_room_id ON cached_messages(room_id)',
    );
  }

  /// Миграции
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Миграции будут добавляться по мере необходимости
  }

  /// Закрыть базу данных
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Очистить все данные
  Future<void> clear() async {
    await _database?.delete('cached_characters');
    await _database?.delete('cached_scenarios');
    await _database?.delete('cached_rooms');
    await _database?.delete('cached_messages');
  }

  /// Очистить устаревшие записи (старше указанного времени)
  Future<void> clearStale({Duration maxAge = const Duration(days: 7)}) async {
    final threshold =
        DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    await _database?.delete(
      'cached_characters',
      where: 'updated_at < ?',
      whereArgs: [threshold],
    );
    await _database?.delete(
      'cached_scenarios',
      where: 'updated_at < ?',
      whereArgs: [threshold],
    );
    await _database?.delete(
      'cached_rooms',
      where: 'updated_at < ?',
      whereArgs: [threshold],
    );
  }
}
