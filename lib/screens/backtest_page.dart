import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/backtest_result.dart';
import '../engine/backtest_engine.dart';
import '../config/app_constants.dart';

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
  bool _isLoadingMore = false;
  String _loadStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBacktest());
  }

  Future<void> _runBacktest() async {
    setState(() => _isRunning = true);
    final app = context.read<AppState>();
    var klines = _getCurrentKlines(app);
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

  List<dynamic> _getCurrentKlines(AppState app) {
    switch (_selectedInterval) {
      case '1h':
        return app.marketData.getEth1h();
      case '4h':
        return app.marketData.getEth4h();
      case '1d':
        return app.marketData.getEth1d();
      default:
        return [];
    }
  }

  Future<void> _loadMoreData(int count) async {
    setState(() {
      _isLoadingMore = true;
      _loadStatus = '正在加载${count}根$_selectedInterval K线...';
    });
    final app = context.read<AppState>();
    final loaded = await app.marketData.loadMoreHistoricalKlines(
      AppConstants.ethSymbol,
      _selectedInterval,
      count,
    );
    setState(() {
      _isLoadingMore = false;
      _loadStatus = '已加载$loaded根K线';
    });
    _runBacktest();
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
    final app = context.read<AppState>();
    final klinesCount = _getCurrentKlines(app).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataLoader(klinesCount),
          const SizedBox(height: 12),
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

  Widget _buildDataLoader(int klinesCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('回测数据量: $klinesCount根 $_selectedInterval',
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
              if (_isLoadingMore)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          if (_loadStatus.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_loadStatus, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingMore ? null : () => _loadMoreData(300),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('加载300根', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingMore ? null : () => _loadMoreData(500),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('加载500根', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingMore ? null : () => _loadMoreData(1000),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('加载1000根', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
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
