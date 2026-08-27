import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../utils/constants.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TradingSignal> _signals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSignals();
    });
  }

  Future<void> _loadSignals() async {
    final app = context.read<AppState>();
    final signals = await app.database.getRecentSignals(limit: 100);
    setState(() {
      _signals = signals;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_signals.isEmpty) return const Center(child: Text('暂无历史信号', style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _loadSignals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _signals.length,
        itemBuilder: (context, i) => _signalTile(_signals[i]),
      ),
    );
  }

  Widget _signalTile(TradingSignal signal) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.green : Colors.red;
    final executed = signal.userExecuted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color),
        title: Text(
          '${isLong ? "多头" : "空头"} · 置信度${signal.confidenceScore}',
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        subtitle: Text(
          '${DateTime.fromMillisecondsSinceEpoch(signal.createdAt).toString().substring(0, 16)} · ${signal.status.name}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: executed == null
            ? const Icon(Icons.help_outline, color: Colors.grey, size: 18)
            : Icon(executed ? Icons.check_circle : Icons.cancel, color: executed ? Colors.green : Colors.grey, size: 18),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('开仓区间', '\$${signal.entryLower.toStringAsFixed(2)} - \$${signal.entryUpper.toStringAsFixed(2)}'),
                _detail('止损', '\$${signal.stopLoss.toStringAsFixed(2)}'),
                _detail('TP1', '\$${signal.tp1.toStringAsFixed(2)}'),
                _detail('TP2', '\$${signal.tp2.toStringAsFixed(2)}'),
                _detail('盈亏比', '${signal.riskRewardRatio.toStringAsFixed(2)}:1'),
                _detail('市场环境', '${signal.marketRegime} / ${signal.volatilityState}'),
                if (signal.actualPnl != null) _detail('实际盈亏', '\$${signal.actualPnl!.toStringAsFixed(2)}', color: signal.actualPnl! >= 0 ? Colors.green : Colors.red),
                if (signal.resultNote != null) _detail('备注', signal.resultNote!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
