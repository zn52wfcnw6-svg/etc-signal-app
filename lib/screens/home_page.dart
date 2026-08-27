import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import 'backtest_page.dart';
import '../engine/risk/risk_manager.dart';
import 'signal_panel.dart';
import 'positions_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const SignalPanel(),
    const PositionsPage(),
    const HistoryPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ETH永续信号监控'),
            backgroundColor: _riskColor(app.riskState?.level ?? RiskLevel.L0),
            actions: [
              IconButton(
                icon: Icon(app.isRunning ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (app.isRunning) app.stop();
                  else app.start();
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => app.manualRefresh(),
              ),
              IconButton(
                icon: const Icon(Icons.assessment),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BacktestPage())),
              ),
            ],
          ),
          body: Column(
            children: [
              _statusBar(app),
              Expanded(child: _pages[_currentIndex]),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.analytics), label: '信号'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: '持仓'),
              NavigationDestination(icon: Icon(Icons.history), label: '历史'),
              NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.L0: return Colors.grey.shade800;
      case RiskLevel.L1: return Colors.yellow.shade800;
      case RiskLevel.L2: return Colors.orange.shade800;
      case RiskLevel.L3: return Colors.red.shade900;
    }
  }

  Widget _statusBar(AppState app) {
    final riskLevel = app.riskState?.level ?? RiskLevel.L0;
    final color = _riskColor(riskLevel);
    final hasSignal = app.currentSignal != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: hasSignal ? (app.currentSignal!.direction.name == 'long' ? Colors.green : Colors.red) : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${riskLevel.name}: ${app.riskState?.reasonText ?? "正常"} | ${app.statusMessage}',
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'ETH: \$${app.ethPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('BTC: \$${app.btcPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 12),
              Text('ETH/BTC: ${app.ethBtcRatio.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 12),
              Text('风险: ${(app.totalRisk * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: app.totalRisk > 0.04 ? Colors.red : Colors.grey)),
              const SizedBox(width: 12),
              if (app.adaptiveParams != null)
                Text(app.adaptiveParams!.volatilityLabel, style: const TextStyle(fontSize: 11, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }
}
