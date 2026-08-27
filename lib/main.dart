import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_state.dart';
import 'screens/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 全局错误处理 - 显示错误页面而不是白屏
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _showError(details.exception.toString(), details.stack?.toString() ?? '');
  };

  runZonedGuarded(
    () {
      runApp(const EthSignalApp());
    },
    (Object error, StackTrace stack) {
      _showError(error.toString(), stack.toString());
    },
  );
}

void _showError(String error, String stack) {
  // 忽略非致命错误：WebSocket、网络、HTTP、超时等
  final lowerError = error.toLowerCase();
  if (lowerError.contains('websocket') ||
      lowerError.contains('socket') ||
      lowerError.contains('http') ||
      lowerError.contains('network') ||
      lowerError.contains('timeout') ||
      lowerError.contains('connection') ||
      lowerError.contains('failed to connect') ||
      lowerError.contains('connection refused')) {
    return; // 忽略网络错误，不显示错误页面
  }
  // 错误信息通过全局key显示
  if (_errorKey.currentState != null) {
    _errorKey.currentState!.setError(error, stack);
  }
}

final GlobalKey<_ErrorOverlayState> _errorKey = GlobalKey<_ErrorOverlayState>();

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
        home: Stack(
          children: [
            const HomePage(),
            ErrorOverlay(key: _errorKey),
          ],
        ),
      ),
    );
  }
}

class ErrorOverlay extends StatefulWidget {
  const ErrorOverlay({super.key});

  @override
  State<ErrorOverlay> createState() => _ErrorOverlayState();
}

class _ErrorOverlayState extends State<ErrorOverlay> {
  String? _error;
  String? _stack;

  void setError(String error, String stack) {
    setState(() {
      _error = error;
      _stack = stack;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('应用运行出错', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {
                  _error = null;
                  _stack = null;
                }),
                child: const Text('关闭错误提示'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage())),
                child: const Text('刷新重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
