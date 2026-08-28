import 'package:flutter/material.dart';

/// 全局错误检测器 - 捕获并显示具体错误信息（文件、行号、堆栈）
class GlobalErrorDetector extends StatefulWidget {
  final Widget child;
  const GlobalErrorDetector({super.key, required this.child});

  static final GlobalKey<GlobalErrorDetectorState> detectorKey = GlobalKey<GlobalErrorDetectorState>();

  @override
  State<GlobalErrorDetector> createState() => GlobalErrorDetectorState();
}

class GlobalErrorDetectorState extends State<GlobalErrorDetector> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;

  void reportError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
      _hasError = true;
    });
  }

  void clearError() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _stackTrace = null;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorScreen();
    }
    return widget.child;
  }

  Widget _buildErrorScreen() {
    final errorStr = _error?.toString() ?? 'Unknown error';
    final stackStr = _stackTrace?.toString() ?? 'No stack trace';

    // 从堆栈中提取文件名和行号
    final fileMatch = RegExp(r'package:([a-zA-Z0-9_/]+)\.dart:(\d+):(\d+)').firstMatch(stackStr);
    final fileName = fileMatch?.group(1) ?? 'unknown';
    final lineNum = fileMatch?.group(2) ?? '?';
    final colNum = fileMatch?.group(3) ?? '?';

    return Scaffold(
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
                    const Text('📋 堆栈跟踪（前10行）', style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText(
                      stackStr.split('\n').take(10).join('\n'),
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: clearError,
                      icon: const Icon(Icons.refresh),
                      label: const Text('继续运行'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => widget.child),
                      ),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重启应用'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
    );
  }
}
