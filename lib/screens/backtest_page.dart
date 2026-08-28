import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/backtest_result.dart';
import '../engine/backtest_engine.dart';

/// 历史回测页面
class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});

  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  BacktestResult? _result;
  bool _isRunning = false;
  String _selectedInterval = '4h';
  final List<String> _intervals = ['1h', '4h', '1d'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBacktest());
  }

  Future<void> _runBacktest() async {
    setState(() => _isRunning = true);
    final app = context.read<AppState>();
    var klines = <dynamic>[];
    switch (_selectedInterval) {
      case '1h':
        klines = app.marketData.getEth1h();
        break;
      case '4h':
        klines = app.marketData.getEth4h();
        break;
      case '1d':
        klines = app.marketData.getEth1d();
        break;
    }
    if (klines.length < 50) {
      setState(() => _isRunning = false);
      return;
    }
    final result = BacktestEngine.runBacktest(klines.cast());
    setState(() {
      _result = result;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史回测'),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          DropdownButton<String>(
            value: _selectedInterval,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: _intervals.map((interval) => DropdownMenuItem(
              value: interval,
              child: Text(interval.toUpperCase()),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedInterval = value);
                _runBacktest();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runBacktest,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: _isRunning
          ? const Center(child: CircularProgressIndicator())
          : _result == null
              ? const Center(child: Text('K线数据不足，无法回测', style: TextStyle(color: Colors.grey)))
              : _buildResult(),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 核心指标
          _buildMetricGrid(r),
          const SizedBox(height: 16),
          // 交易明细
          const Text('交易明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          ...r.trades.reversed.take(20).map((t) => _buildTradeItem(t)),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(BacktestResult r) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        _metricCard('总交易数', '${r.totalSignals}', Colors.blue),
        _metricCard('胜率', r.winRateText, r.winRate >= 0.5 ? Colors.green : Colors.red),
        _metricCard('盈亏比', r.profitFactorText, r.profitFactor >= 1.5 ? Colors.green : Colors.red),
        _metricCard('总收益率', r.totalReturnText, r.totalReturn >= 0 ? Colors.green : Colors.red),
        _metricCard('最大回撤', r.maxDrawdownText, Colors.orange),
        _metricCard('夏普比率', r.sharpeRatioText, r.sharpeRatio >= 1 ? Colors.green : Colors.orange),
      ],
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeItem(BacktestTrade t) {
    final isWin = t.pnl > 0;
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              color: t.direction == 'long' ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.direction == 'long' ? '做多' : '做空',
                          style: TextStyle(
                              color: t.direction == 'long' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('入场 \$${t.entryPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(width: 8),
                      Text('出场 \$${t.exitPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${t.exitReason.toUpperCase()} | ${t.entryTime.month}/${t.entryTime.day} ${t.entryTime.hour}:${t.entryTime.minute}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Text(
              '${isWin ? '+' : ''}\$${t.pnl.toStringAsFixed(2)}',
              style: TextStyle(color: isWin ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
