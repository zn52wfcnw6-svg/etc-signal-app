import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_state.dart';
import 'screens/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 判断是否为非致命网络错误
  bool isNonFatalError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('websocket') ||
        lower.contains('socket') ||
        lower.contains('http') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('connection') ||
        lower.contains('failed to connect') ||
        lower.contains('connection refused') ||
        lower.contains('handshake') ||
        lower.contains('certificate');
  }

  // 全局错误处理 - 忽略非致命错误
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorStr = details.exception.toString();
    if (isNonFatalError(errorStr)) return;
    FlutterError.presentError(details);
  };
  
  runZonedGuarded(
    () {
      runApp(const EthSignalApp());
    },
    (Object error, StackTrace stack) {
      final errorStr = error.toString();
      if (isNonFatalError(errorStr)) return;
      // 致命错误输出到控制台
      debugPrint('Fatal Error: $errorStr');
      debugPrint('Stack: $stack');
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
        home: const HomePage(),
      ),
    );
  }
}
