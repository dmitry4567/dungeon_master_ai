/// Константы маршрутов приложения
abstract final class Routes {
  // Auth
  static const login = '/login';
  static const register = '/register';

  // Main tabs
  static const home = '/';
  static const lobby = '/lobby';
  static const scenarios = '/scenarios';
  static const characters = '/characters';
  static const profile = '/profile';

  // Lobby
  static const roomCreate = '/lobby/create';
  static const waitingRoom = '/lobby/room/:roomId';
  static String waitingRoomPath(String roomId) => '/lobby/room/$roomId';

  // Scenarios
  static const scenarioBuilder = '/scenarios/builder';
  static const scenarioPreview = '/scenarios/:scenarioId';
  static String scenarioPreviewPath(String scenarioId) =>
      '/scenarios/$scenarioId';

  // Characters
  static const characterCreate = '/characters/create';
  static const characterDetail = '/characters/:characterId';
  static String characterDetailPath(String characterId) =>
      '/characters/$characterId';

  // Game Session
  static const gameSession = '/game/:roomId';
  static String gameSessionPath(String roomId) => '/game/$roomId';

  // Profile
  static const settings = '/profile/settings';
}
