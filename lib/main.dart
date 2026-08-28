import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_state.dart';
import 'screens/home_page.dart';
import 'widgets/global_error_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局错误处理 - 捕获所有错误并显示
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    GlobalErrorDetector.detectorKey.currentState?.reportError(
      details.exception,
      details.stack,
    );
  };

  runZonedGuarded(
    () {
      runApp(const EthSignalApp());
    },
    (Object error, StackTrace stack) {
      GlobalErrorDetector.detectorKey.currentState?.reportError(error, stack);
    },
  );
}

class EthSignalApp extends StatelessWidget {
  const EthSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'ETH永续信号监控',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          cardTheme: CardThemeData(
            color: Colors.grey.shade900,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        home: GlobalErrorDetector(
          key: GlobalErrorDetector.detectorKey,
          child: const HomePage(),
        ),
      ),
    );
  }
}
