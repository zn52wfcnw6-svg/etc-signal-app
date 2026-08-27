import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../utils/constants.dart';
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
            title: const Text('ETC永续信号监控'),
            backgroundColor: _appBarColor(app.appState),
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

  Color _appBarColor(AppStateTag tag) {
    switch (tag) {
      case AppStateTag.longCandidate: return Colors.green.shade700;
      case AppStateTag.shortCandidate: return Colors.red.shade700;
      case AppStateTag.marketFrozen: return Colors.orange.shade800;
      case AppStateTag.dataAbnormal: return Colors.deepOrange.shade900;
      case AppStateTag.noSignal: return Colors.grey.shade800;
    }
  }

  Widget _statusBar(AppState app) {
    final tag = app.appState;
    final color = _appBarColor(tag);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusDot(tag),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  app.statusMessage,
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'ETC: \$${app.etcPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (app.freezeState?.isFrozen ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '冻结原因: ${app.freezeState!.reasonText}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              ),
            ),
          Row(
            children: [
              Text('BTC: \$${app.btcPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Text('ETC/BTC: ${app.etcBtcRatio.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Text('账户风险: ${(app.totalRisk * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: app.totalRisk > 0.04 ? Colors.red : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusDot(AppStateTag tag) {
    Color color;
    switch (tag) {
      case AppStateTag.longCandidate: color = Colors.green;
      case AppStateTag.shortCandidate: color = Colors.red;
      case AppStateTag.marketFrozen: color = Colors.orange;
      case AppStateTag.dataAbnormal: color = Colors.deepOrange;
      case AppStateTag.noSignal: color = Colors.grey;
    }
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
