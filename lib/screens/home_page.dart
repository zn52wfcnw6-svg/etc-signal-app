import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('ETH信号 v3.47.1 build3'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Center(
        child: Consumer<AppState>(
          builder: (context, app, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('应用已启动', style: TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 16),
                Text('ETH价格: \$${app.ethPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                Text('BTC价格: \$${app.btcPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                Text('状态: ${app.statusMessage}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            );
          },
        ),
      ),
    );
  }
}
