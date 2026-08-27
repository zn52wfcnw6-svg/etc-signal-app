import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_state.dart';
import '../models/signal.dart';
import '../utils/constants.dart';

class SignalPanel extends StatelessWidget {
  const SignalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, child) {
        if (!app.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final signal = app.currentSignal;
        final isFrozen = app.freezeState?.isFrozen ?? false;

        return RefreshIndicator(
          onRefresh: () => app.manualRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (signal != null && signal.status == SignalStatus.confirmed && !isFrozen)
                _signalCard(signal, app)
              else
                _noSignalCard(app),
              const SizedBox(height: 16),
              _marketInfoCard(app),
              const SizedBox(height: 16),
              _confirmationChainCard(app),
            ],
          ),
        );
      },
    );
  }

  Widget _signalCard(TradingSignal signal, AppState app) {
    final isLong = signal.direction == SignalDirection.long;
    final color = isLong ? Colors.green : Colors.red;
    final suggestedSize = app.riskManager.suggestedPositionSize(
      (signal.entryLower + signal.entryUpper) / 2,
      signal.stopLoss,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isLong ? Icons.trending_up : Icons.trending_down, color: color, size: 28),
                const SizedBox(width: 8),
                Text(
                  isLong ? '多头候选' : '空头候选',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('置信度 ${signal.confidenceScore}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _priceRow('开仓区间', '\$${signal.entryLower.toStringAsFixed(2)} - \$${signal.entryUpper.toStringAsFixed(2)}', Colors.blue),
            _priceRow('止损 SL', '\$${signal.stopLoss.toStringAsFixed(2)}', Colors.red),
            _priceRow('止盈 TP1', '\$${signal.tp1.toStringAsFixed(2)} (减仓60%)', Colors.orange),
            _priceRow('止盈 TP2', '\$${signal.tp2.toStringAsFixed(2)} (全平)', Colors.green),
            _priceRow('盈亏比', signal.riskRewardRatio.toStringAsFixed(2) + ':1', signal.riskRewardRatio >= 4 ? Colors.green : Colors.orange),
            const Divider(height: 24),
            _infoRow('建议仓位', '${suggestedSize.toStringAsFixed(4)} 张'),
            _infoRow('单笔风险', '1% 账户净值'),
            _infoRow('市场环境', '${signal.marketRegime} / ${signal.volatilityState}'),
            _infoRow('资金费率', '${(signal.fundingRateAtSignal * 100).toStringAsFixed(4)}%'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check),
                    label: const Text('已执行'),
                    onPressed: () => app.markSignalExecuted(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                    icon: const Icon(Icons.close),
                    label: const Text('忽略'),
                    onPressed: () => app.markSignalExecuted(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noSignalCard(AppState app) {
    final isFrozen = app.freezeState?.isFrozen ?? false;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isFrozen ? Icons.lock : Icons.hourglass_empty,
              size: 48,
              color: isFrozen ? Colors.orange : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isFrozen ? '大盘冻结' : '无有效信号',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isFrozen ? Colors.orange : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              app.statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            if (!isFrozen) ...[
              const SizedBox(height: 16),
              const Text('系统正在监控关键位与订单流...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _marketInfoCard(AppState app) {
    final status = app.signalStatus;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('市场结构', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow('长周期状态', status['longCycleState'] ?? '-'),
            _infoRow('市场结构', status['structure'] ?? '-'),
            _infoRow('波动率', status['volatility'] ?? '-'),
            _infoRow('资金费率状态', status['fundingState'] ?? '-'),
            if (status['support'] != null) _infoRow('最近支撑', '\$${(status['support'] as double).toStringAsFixed(2)}'),
            if (status['resistance'] != null) _infoRow('最近压力', '\$${(status['resistance'] as double).toStringAsFixed(2)}'),
            if (status['confirmationCount'] != null && status['confirmationCount'] > 0)
              _infoRow('信号确认', '${status['pendingDirection']} ${status['confirmationCount']}/${AppConstants.confirmationPolls}'),
          ],
        ),
      ),
    );
  }

  Widget _confirmationChainCard(AppState app) {
    final signal = app.currentSignal;
    if (signal == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确认链', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...signal.confirmationGates.entries.map((e) => _gateItem(e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _gateItem(String name, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.cancel, size: 18, color: passed ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 13, color: passed ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
