import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:little_star_app/firebase_options.dart';
import 'package:little_star_app/ui/home/widgets/home_screen.dart';
import 'package:little_star_app/data/services/crash_reporting_service.dart';
import 'package:little_star_app/data/services/log_file_service.dart';
import 'package:little_star_app/utils/logger.dart';

/// Firebase 僅支援 Android/iOS (macOS 尚未配置 GoogleService-Info.plist)
bool get _isFirebaseSupported => Platform.isAndroid || Platform.isIOS;

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Hive for persistent storage
    await Hive.initFlutter();

    // Initialize Firebase（僅支援 Android/iOS/macOS）
    if (_isFirebaseSupported && !DefaultFirebaseOptions.isStub) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        if (!e.toString().contains('duplicate-app')) {
          rethrow;
        }
        Logger('Main').info('Firebase already initialized');
      }
    }

    // Initialize log file service（所有平台都支援）
    final logFileService = LogFileService.instance;
    await logFileService.initialize();

    // Initialize crash reporting (includes global error handlers)
    await CrashReportingService.instance.initialize(
      logFileService: logFileService,
    );

    Logger('Main').info('App starting...');

    runApp(const LittleStarApp());
  }, (error, stack) {
    // 這個處理 runZonedGuarded 區域內的未捕獲錯誤
    Logger('Main').error('Uncaught error in zone', error: error, st: stack);
    CrashReportingService.instance.recordError(error, stack, fatal: true);
  });
}

class LittleStarApp extends StatelessWidget {
  const LittleStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little Star App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
