import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../utils/constants.dart';
import '../engine/long_cycle/long_cycle_manager.dart';
import '../engine/risk/risk_manager.dart';

class SignalPanel extends StatelessWidget {
  const SignalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        if (!app.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final riskLevel = app.riskState?.level ?? RiskLevel.L0;
        final currentPrice = app.ethPrice;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('风险等级: ${riskLevel.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('ETH价格: \$${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('BTC价格: \$${app.btcPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('状态: ${app.statusMessage}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('SignalPanel简化版 - 逐步排查白屏问题', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }
}
