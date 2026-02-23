import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/storage/local_database.dart';
import '../models/character.dart';
import 'cached_character.dart';
import 'character_api.dart';
import 'character_validator.dart';

/// Репозиторий для работы с персонажами
/// Обеспечивает кэширование и синхронизацию с сервером
@lazySingleton
class CharacterRepository {
  CharacterRepository(
    this._api,
    this._database,
    this._validator,
  );

  final CharacterApi _api;
  final LocalDatabase _database;
  final CharacterValidator _validator;

  /// Получить список персонажей
  /// Сначала возвращает кэш, затем обновляет с сервера
  Future<List<Character>> getCharacters({bool forceRefresh = false}) async {
    // Если не требуется принудительное обновление, попробуем вернуть кэш
    if (!forceRefresh) {
      final cached = await _getCachedCharacters();
      if (cached.isNotEmpty) {
        // Запускаем фоновое обновление
        _refreshCharactersInBackground();
        return cached;
      }
    }

    // Загружаем с сервера
    try {
      final characters = await _api.getCharacters();
      await _cacheCharacters(characters);
      return characters;
    } catch (e) {
      // При ошибке сети возвращаем кэш
      final cached = await _getCachedCharacters();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Получить персонажа по ID
  Future<Character> getCharacter(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _getCachedCharacter(id);
      if (cached != null) {
        return cached;
      }
    }

    final character = await _api.getCharacter(id);
    await _cacheCharacter(character);
    return character;
  }

  /// Создать нового персонажа
  Future<Character> createCharacter(CreateCharacterRequest request) async {
    // Валидация
    final errors = _validator.validate(request);
    if (errors.isNotEmpty) {
      throw CharacterValidationException(errors);
    }

    final character = await _api.createCharacter(request);
    await _cacheCharacter(character);
    return character;
  }

  /// Обновить персонажа
  Future<Character> updateCharacter(
    String id,
    UpdateCharacterRequest request,
  ) async {
    final character = await _api.updateCharacter(id, request);
    await _cacheCharacter(character);
    return character;
  }

  /// Удалить персонажа
  Future<void> deleteCharacter(String id) async {
    await _api.deleteCharacter(id);
    await _deleteCachedCharacter(id);
  }

  /// Валидировать запрос на создание
  List<String> validateCharacter(CreateCharacterRequest request) => _validator.validate(request);

  // === Приватные методы для кэширования ===

  Future<List<Character>> _getCachedCharacters() async {
    try {
      final db = _database.database;
      final rows = await db.query('characters');
      return rows.map((row) => CachedCharacter.fromMap(row).toCharacter()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Character?> _getCachedCharacter(String id) async {
    try {
      final db = _database.database;
      final rows = await db.query(
        'characters',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return null;
      return CachedCharacter.fromMap(rows.first).toCharacter();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheCharacters(List<Character> characters) async {
    try {
      final db = _database.database;
      await db.transaction((txn) async {
        await txn.delete('characters');
        for (final character in characters) {
          await txn.insert(
            'characters',
            CachedCharacter.fromCharacter(character).toMap(),
          );
        }
      });
    } catch (_) {
      // Игнорируем ошибки кэширования
    }
  }

  Future<void> _cacheCharacter(Character character) async {
    try {
      final db = _database.database;
      await db.insert(
        'characters',
        CachedCharacter.fromCharacter(character).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Игнорируем ошибки кэширования
    }
  }

  Future<void> _deleteCachedCharacter(String id) async {
    try {
      final db = _database.database;
      await db.delete('characters', where: 'id = ?', whereArgs: [id]);
    } catch (_) {
      // Игнорируем ошибки кэширования
    }
  }

  void _refreshCharactersInBackground() {
    // Фоновое обновление без ожидания
    _api.getCharacters().then(_cacheCharacters).catchError((_) {});
  }
}

/// Исключение валидации персонажа
class CharacterValidationException implements Exception {
  CharacterValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'CharacterValidationException: ${errors.join(', ')}';
}
