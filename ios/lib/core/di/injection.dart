import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// Глобальный экземпляр сервис-локатора
final getIt = GetIt.instance;

/// Инициализация dependency injection
@InjectableInit(
  preferRelativeImports: true,
)
Future<void> configureDependencies() async => getIt.init();
