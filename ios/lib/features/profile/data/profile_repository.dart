import 'package:injectable/injectable.dart';

import '../models/game_history.dart';
import '../../auth/models/user.dart';
import 'profile_api.dart';

/// Репозиторий профиля
@lazySingleton
class ProfileRepository {
  ProfileRepository(this._profileApi);

  final ProfileApi _profileApi;

  /// Получить профиль текущего пользователя
  Future<User> getProfile() async {
    final userData = await _profileApi.getProfile();
    return User.fromJson(userData);
  }

  /// Обновить имя пользователя
  Future<User> updateName(String name) async {
    final userData = await _profileApi.updateName(name);
    return User.fromJson(userData);
  }

  /// Обновить аватар пользователя
  Future<User> updateAvatar(String avatarUrl) async {
    final userData = await _profileApi.updateAvatar(avatarUrl);
    return User.fromJson(userData);
  }

  /// Получить историю игр
  Future<List<GameHistory>> getGameHistory() async {
    final historyData = await _profileApi.getGameHistory();
    return historyData.map((data) => GameHistory.fromJson(data)).toList();
  }
}
