import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

      // Request permissions
      await _requestPermissions();

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

Future<void> _requestPermissions() async {
  // permission_handler doesn't support macOS
  if (!kIsWeb && Platform.isIOS) {
    // Request microphone permission for voice input
    final microphoneStatus = await Permission.microphone.status;
    if (microphoneStatus.isDenied) {
      await Permission.microphone.request();
    }

    // Request speech recognition permission
    final speechStatus = await Permission.speech.status;
    if (speechStatus.isDenied) {
      await Permission.speech.request();
    }
  }
}
