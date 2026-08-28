import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_state.dart';
import 'screens/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局构建错误处理 - 任何widget构建失败都显示详细错误
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _GlobalErrorWidget(
      error: details.exception,
      stackTrace: details.stack,
      library: details.library,
      context: details.context?.toString() ?? '',
    );
  };

  // 全局框架错误处理
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runZonedGuarded(
    () {
      runApp(const EthSignalApp());
    },
    (Object error, StackTrace stack) {
      // 异步错误 - 直接替换整个应用为错误页面
      runApp(_GlobalErrorWidget(error: error, stackTrace: stack, library: 'async', context: ''));
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

/// 全局错误显示widget - 显示具体错误位置和信息
class _GlobalErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final String library;
  final String context;

  const _GlobalErrorWidget({
    required this.error,
    required this.stackTrace,
    required this.library,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final errorStr = error.toString();
    final stackStr = stackTrace?.toString() ?? 'No stack trace';

    // 从堆栈中提取文件名和行号
    final fileMatch = RegExp(r'package:([a-zA-Z0-9_/]+)\.dart:(\d+):(\d+)').firstMatch(stackStr);
    final fileName = fileMatch?.group(1) ?? 'unknown';
    final lineNum = fileMatch?.group(2) ?? '?';
    final colNum = fileMatch?.group(3) ?? '?';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.red, size: 32),
                    const SizedBox(width: 12),
                    const Text(
                      '错误检测报告',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '应用运行时检测到错误，以下是详细信息：',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // 错误位置
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📍 错误位置', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('文件: lib/$fileName.dart', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace')),
                      Text('行号: $lineNum 列号: $colNum', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace')),
                      if (library.isNotEmpty) Text('库: $library', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 错误信息
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ 错误信息', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText(
                        errorStr,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 堆栈跟踪
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📋 堆栈跟踪（前15行）', style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText(
                        stackStr.split('\n').take(15).join('\n'),
                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    '请截图此页面发送给开发者修复',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
