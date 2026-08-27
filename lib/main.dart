import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Test v3.47.1')),
        body: const Center(child: Text('Flutter 3.47.1 测试成功', style: TextStyle(color: Colors.white, fontSize: 24))),
      ),
    );
  }
}
