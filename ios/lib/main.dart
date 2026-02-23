import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/firebase/firebase_service.dart';
import 'core/storage/local_database.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // System UI
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      // Initialize dependencies
      await configureDependencies();

      // Initialize Firebase
      // final firebaseService = getIt<FirebaseService>();
      // await firebaseService.init();

      // Initialize local database
      final localDatabase = getIt<LocalDatabase>();
      await localDatabase.init();

      // Log app start
      // if (AppConfig.current.enableAnalytics) {
      //   await firebaseService.logEvent(name: 'app_start');
      // }

      runApp(const App());
    },
    (error, stackTrace) {
      // Log errors to Firebase Crashlytics
      if (AppConfig.current.enableCrashlytics) {
        getIt<FirebaseService>().recordError(
          error,
          stackTrace,
          fatal: true,
        );
      }
    },
  );
}
