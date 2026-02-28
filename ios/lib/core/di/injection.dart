import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';

import '../storage/local_database.dart';
import 'injection.config.dart';

/// Глобальный экземпляр сервис-локатора
final getIt = GetIt.instance;

/// Инициализация dependency injection
@InjectableInit(
  preferRelativeImports: true,
)
Future<void> configureDependencies() async {
  getIt.registerLazySingleton(AudioPlayer.new);
  await getIt.init();

  // Инициализировать LocalDatabase
  final localDb = getIt<LocalDatabase>();
  await localDb.init();
}
