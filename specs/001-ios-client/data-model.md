# Модель данных: iOS-клиент AI Dungeon Master

**Функция**: 001-ios-client
**Дата**: 2026-02-21

## Обзор

Клиентские модели данных, использующие freezed для иммутабельности и json_serializable для сериализации API. Модели отражают серверные сущности, но оптимизированы для рендеринга UI и локального кэширования.

## Основные модели

### Пользователь и аутентификация

```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    String? avatarUrl,
    required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class AuthTokens with _$AuthTokens {
  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);
}

@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required AuthTokens tokens,
    required User user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
}
```

---

### Персонаж

```dart
@freezed
class AbilityScores with _$AbilityScores {
  const factory AbilityScores({
    required int strength,
    required int dexterity,
    required int constitution,
    required int intelligence,
    required int wisdom,
    required int charisma,
  }) = _AbilityScores;

  factory AbilityScores.fromJson(Map<String, dynamic> json) => _$AbilityScoresFromJson(json);
}

extension AbilityScoresX on AbilityScores {
  int get strengthModifier => (strength - 10) ~/ 2;
  int get dexterityModifier => (dexterity - 10) ~/ 2;
  int get constitutionModifier => (constitution - 10) ~/ 2;
  int get intelligenceModifier => (intelligence - 10) ~/ 2;
  int get wisdomModifier => (wisdom - 10) ~/ 2;
  int get charismaModifier => (charisma - 10) ~/ 2;

  int getModifier(String ability) {
    switch (ability.toLowerCase()) {
      case 'strength': return strengthModifier;
      case 'dexterity': return dexterityModifier;
      case 'constitution': return constitutionModifier;
      case 'intelligence': return intelligenceModifier;
      case 'wisdom': return wisdomModifier;
      case 'charisma': return charismaModifier;
      default: return 0;
    }
  }
}

@freezed
class Character with _$Character {
  const factory Character({
    required String id,
    required String name,
    required String characterClass,
    required String race,
    @Default(1) int level,
    required AbilityScores abilityScores,
    String? backstory,
    required DateTime createdAt,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) => _$CharacterFromJson(json);
}

@freezed
class CreateCharacterRequest with _$CreateCharacterRequest {
  const factory CreateCharacterRequest({
    required String name,
    required String characterClass,
    required String race,
    required AbilityScores abilityScores,
    String? backstory,
  }) = _CreateCharacterRequest;

  factory CreateCharacterRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCharacterRequestFromJson(json);
}
```

---

### Справочные данные D&D (статические)

```dart
@freezed
class DndClass with _$DndClass {
  const factory DndClass({
    required String id,
    required String name,
    required String nameRu,
    required String hitDie,
    required List<String> primaryAbilities,
    required List<String> savingThrows,
    required String description,
  }) = _DndClass;

  factory DndClass.fromJson(Map<String, dynamic> json) => _$DndClassFromJson(json);
}

@freezed
class DndRace with _$DndRace {
  const factory DndRace({
    required String id,
    required String name,
    required String nameRu,
    required Map<String, int> abilityBonuses,
    required int speed,
    required String description,
  }) = _DndRace;

  factory DndRace.fromJson(Map<String, dynamic> json) => _$DndRaceFromJson(json);
}
```

---

### Сценарий

```dart
@freezed
class Scene with _$Scene {
  const factory Scene({
    required String id,
    required bool mandatory,
    required String descriptionForAi,
    required List<String> dmHints,
    required List<String> possibleOutcomes,
  }) = _Scene;

  factory Scene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);
}

@freezed
class Act with _$Act {
  const factory Act({
    required String id,
    required String entryCondition,
    required List<String> exitConditions,
    required List<Scene> scenes,
  }) = _Act;

  factory Act.fromJson(Map<String, dynamic> json) => _$ActFromJson(json);
}

@freezed
class Npc with _$Npc {
  const factory Npc({
    required String id,
    required String name,
    required String role, // ally, enemy, neutral
    required String personality,
    required String speechStyle,
    required List<String> secrets,
    required String motivation,
  }) = _Npc;

  factory Npc.fromJson(Map<String, dynamic> json) => _$NpcFromJson(json);
}

@freezed
class Location with _$Location {
  const factory Location({
    required String id,
    required String name,
    required String atmosphere,
    required List<Map<String, dynamic>> rooms,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
}

@freezed
class ScenarioContent with _$ScenarioContent {
  const factory ScenarioContent({
    required String tone,
    required String difficulty,
    required int playersMin,
    required int playersMax,
    required String worldLore,
    required List<Act> acts,
    required List<Npc> npcs,
    required List<Location> locations,
  }) = _ScenarioContent;

  factory ScenarioContent.fromJson(Map<String, dynamic> json) => _$ScenarioContentFromJson(json);
}

@freezed
class ScenarioVersion with _$ScenarioVersion {
  const factory ScenarioVersion({
    required String id,
    required int version,
    required ScenarioContent content,
    List<String>? validationErrors,
    required DateTime createdAt,
  }) = _ScenarioVersion;

  factory ScenarioVersion.fromJson(Map<String, dynamic> json) => _$ScenarioVersionFromJson(json);
}

@freezed
class Scenario with _$Scenario {
  const factory Scenario({
    required String id,
    required String title,
    required String status, // draft, published, archived
    String? currentVersionId,
    ScenarioVersion? currentVersion,
    required DateTime createdAt,
  }) = _Scenario;

  factory Scenario.fromJson(Map<String, dynamic> json) => _$ScenarioFromJson(json);
}

@freezed
class ScenarioVersionSummary with _$ScenarioVersionSummary {
  const factory ScenarioVersionSummary({
    required String id,
    required int version,
    required String userPrompt,
    required DateTime createdAt,
  }) = _ScenarioVersionSummary;

  factory ScenarioVersionSummary.fromJson(Map<String, dynamic> json) =>
      _$ScenarioVersionSummaryFromJson(json);
}
```

---

### Комната и лобби

```dart
@freezed
class RoomPlayer with _$RoomPlayer {
  const factory RoomPlayer({
    required String id,
    required String odlerId,
    required String name,
    Character? character,
    required String status, // pending, approved, ready, declined
    required bool isHost,
  }) = _RoomPlayer;

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => _$RoomPlayerFromJson(json);
}

@freezed
class RoomSummary with _$RoomSummary {
  const factory RoomSummary({
    required String id,
    required String name,
    required String scenarioTitle,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    required String status,
  }) = _RoomSummary;

  factory RoomSummary.fromJson(Map<String, dynamic> json) => _$RoomSummaryFromJson(json);
}

@freezed
class Room with _$Room {
  const factory Room({
    required String id,
    required String name,
    required Scenario scenario,
    required String status, // waiting, active, completed
    required int maxPlayers,
    required List<RoomPlayer> players,
    required DateTime createdAt,
  }) = _Room;

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
}

@freezed
class CreateRoomRequest with _$CreateRoomRequest {
  const factory CreateRoomRequest({
    required String name,
    required String scenarioVersionId,
    @Default(5) int maxPlayers,
  }) = _CreateRoomRequest;

  factory CreateRoomRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRoomRequestFromJson(json);
}
```

---

### Игровая сессия

```dart
@freezed
class WorldState with _$WorldState {
  const factory WorldState({
    required String currentAct,
    String? currentScene,
    String? currentLocation,
    required List<String> completedScenes,
    required Map<String, bool> flags,
    required bool combatActive,
  }) = _WorldState;

  factory WorldState.fromJson(Map<String, dynamic> json) => _$WorldStateFromJson(json);
}

@freezed
class DiceRequest with _$DiceRequest {
  const factory DiceRequest({
    required String type, // d4, d6, d8, d10, d12, d20, d100
    required int modifier,
    required int dc,
    required String skill,
  }) = _DiceRequest;

  factory DiceRequest.fromJson(Map<String, dynamic> json) => _$DiceRequestFromJson(json);
}

@freezed
class DiceResult with _$DiceResult {
  const factory DiceResult({
    required String type,
    required int baseRoll,
    required int modifier,
    required int total,
    int? dc,
    String? skill,
    bool? success,
  }) = _DiceResult;

  factory DiceResult.fromJson(Map<String, dynamic> json) => _$DiceResultFromJson(json);
}

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    String? authorId,
    String? authorName,
    required String role, // player, dm, system
    required String content,
    DiceResult? diceResult,
    required DateTime createdAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

@freezed
class GameSession with _$GameSession {
  const factory GameSession({
    required String id,
    required String roomId,
    required WorldState worldState,
    required DateTime startedAt,
    DateTime? endedAt,
  }) = _GameSession;

  factory GameSession.fromJson(Map<String, dynamic> json) => _$GameSessionFromJson(json);
}

@freezed
class SessionWithMessages with _$SessionWithMessages {
  const factory SessionWithMessages({
    required GameSession session,
    required List<Message> messages,
  }) = _SessionWithMessages;

  factory SessionWithMessages.fromJson(Map<String, dynamic> json) =>
      _$SessionWithMessagesFromJson(json);
}
```

---

### WebSocket-сообщения

```dart
// Клиент → Сервер
@freezed
class ClientMessage with _$ClientMessage {
  const factory ClientMessage.playerAction({
    required String content,
  }) = PlayerActionMessage;

  const factory ClientMessage.diceRoll({
    required DiceResult result,
  }) = DiceRollMessage;

  factory ClientMessage.fromJson(Map<String, dynamic> json) => _$ClientMessageFromJson(json);
}

// Сервер → Клиент
@freezed
class ServerMessage with _$ServerMessage {
  const factory ServerMessage.dmResponse({
    required String content,
    DiceRequest? diceRequired,
  }) = DmResponseMessage;

  const factory ServerMessage.diceRequest({
    required DiceRequest dice,
  }) = DiceRequestMessage;

  const factory ServerMessage.stateUpdate({
    required WorldState worldState,
  }) = StateUpdateMessage;

  const factory ServerMessage.playerJoined({
    required RoomPlayer player,
  }) = PlayerJoinedMessage;

  const factory ServerMessage.playerLeft({
    required String playerId,
  }) = PlayerLeftMessage;

  const factory ServerMessage.error({
    required String message,
    String? code,
  }) = ErrorMessage;

  factory ServerMessage.fromJson(Map<String, dynamic> json) => _$ServerMessageFromJson(json);
}
```

---

## Модели локального кэша (Isar)

```dart
@collection
class CachedCharacter {
  Id get isarId => fastHash(id);

  final String id;
  final String name;
  final String characterClass;
  final String race;
  final int level;
  final String abilityScoresJson; // Сериализованные AbilityScores
  final String? backstory;
  final DateTime cachedAt;

  CachedCharacter({
    required this.id,
    required this.name,
    required this.characterClass,
    required this.race,
    required this.level,
    required this.abilityScoresJson,
    this.backstory,
    required this.cachedAt,
  });

  Character toCharacter() => Character(
    id: id,
    name: name,
    characterClass: characterClass,
    race: race,
    level: level,
    abilityScores: AbilityScores.fromJson(jsonDecode(abilityScoresJson)),
    backstory: backstory,
    createdAt: cachedAt,
  );
}

@collection
class CachedScenario {
  Id get isarId => fastHash(id);

  final String id;
  final String title;
  final String status;
  final String? contentJson; // Сериализованный ScenarioContent (текущая версия)
  final DateTime cachedAt;

  CachedScenario({
    required this.id,
    required this.title,
    required this.status,
    this.contentJson,
    required this.cachedAt,
  });
}
```

---

## Классы состояния (Bloc)

```dart
// Состояние авторизации
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;
}

// Состояние сессии
@freezed
class SessionState with _$SessionState {
  const factory SessionState.initial() = SessionInitial;
  const factory SessionState.loading() = SessionLoading;
  const factory SessionState.active({
    required GameSession session,
    required List<Message> messages,
    DiceRequest? pendingDiceRequest,
    required bool isWaitingForDm,
  }) = SessionActive;
  const factory SessionState.disconnected(GameSession session) = SessionDisconnected;
  const factory SessionState.ended(GameSession session) = SessionEnded;
  const factory SessionState.error(String message) = SessionError;
}

// Состояние создания персонажа
@freezed
class CharacterCreateState with _$CharacterCreateState {
  const factory CharacterCreateState({
    DndClass? selectedClass,
    DndRace? selectedRace,
    AbilityScores? abilityScores,
    String? name,
    String? backstory,
    @Default([]) List<String> validationErrors,
    @Default(false) bool isSubmitting,
  }) = _CharacterCreateState;
}
```

---

## Правила валидации

### Валидация персонажа

```dart
class CharacterValidator {
  static List<String> validate(CreateCharacterRequest request) {
    final errors = <String>[];

    if (request.name.isEmpty || request.name.length > 100) {
      errors.add('Имя должно быть от 1 до 100 символов');
    }

    if (!DndData.classes.containsKey(request.characterClass)) {
      errors.add('Недопустимый класс');
    }

    if (!DndData.races.containsKey(request.race)) {
      errors.add('Недопустимая раса');
    }

    errors.addAll(_validateAbilityScores(request.abilityScores));

    return errors;
  }

  static List<String> _validateAbilityScores(AbilityScores scores) {
    final errors = <String>[];
    final values = [
      scores.strength,
      scores.dexterity,
      scores.constitution,
      scores.intelligence,
      scores.wisdom,
      scores.charisma,
    ];

    for (final value in values) {
      if (value < 1 || value > 20) {
        errors.add('Характеристики должны быть от 1 до 20');
        break;
      }
    }

    final total = values.reduce((a, b) => a + b);
    if (total < 60 || total > 90) {
      errors.add('Сумма характеристик должна быть от 60 до 90');
    }

    return errors;
  }
}
```
