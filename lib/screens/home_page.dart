import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import 'backtest_page.dart';
import '../models/trading_pair.dart';
import '../engine/risk/risk_manager.dart';
import 'signal_panel.dart';
import 'positions_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'performance_monitor_page.dart';

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
    const PerformanceMonitorPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => _showPairSelector(app),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(app.currentPair.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
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
              NavigationDestination(icon: Icon(Icons.monitor_heart), label: '监控'),
              NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
    );
  }

  void _showPairSelector(AppState app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择交易对', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            ...app.supportedPairs.map((pair) => ListTile(
              leading: CircleAvatar(
                backgroundColor: pair == app.currentPair ? Colors.blue : Colors.grey.shade800,
                child: Text(pair!.baseAsset.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              title: Text(pair!.displayName, style: const TextStyle(color: Colors.white)),
              trailing: pair == app.currentPair ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                app.setCurrentPair(pair);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
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
              Text('BTC: ' + (app.btcPrice > 0 ? '\$' + app.btcPrice.toStringAsFixed(0) : '获取中'), style: const TextStyle(fontSize: 11)),
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
