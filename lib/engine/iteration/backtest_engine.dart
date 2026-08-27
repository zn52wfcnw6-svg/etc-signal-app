import '../../models/signal.dart';

/// 回测结果
class BacktestResult {
  final int totalSignals;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double avgRiskReward;
  final double expectancy;
  final double maxDrawdown;
  final double totalPnl;
  final double sharpeRatio;

  BacktestResult({
    required this.totalSignals,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.avgRiskReward,
    required this.expectancy,
    required this.maxDrawdown,
    required this.totalPnl,
    required this.sharpeRatio,
  });
}

/// 回测引擎：用历史K线回放信号生成逻辑
class BacktestEngine {
  /// 简化回测：基于历史信号记录统计表现
  static BacktestResult runFromSignals(List<TradingSignal> signals) {
    if (signals.isEmpty) {
      return BacktestResult(
        totalSignals: 0, winningTrades: 0, losingTrades: 0,
        winRate: 0, avgRiskReward: 0, expectancy: 0,
        maxDrawdown: 0, totalPnl: 0, sharpeRatio: 0,
      );
    }

    int wins = 0, losses = 0;
    double totalPnl = 0;
    double peakPnl = 0;
    double maxDrawdown = 0;
    final pnlList = <double>[];

    for (final sig in signals) {
      if (sig.actualPnl != null) {
        final pnl = sig.actualPnl!;
        pnlList.add(pnl);
        totalPnl += pnl;
        if (totalPnl > peakPnl) peakPnl = totalPnl;
        final dd = peakPnl - totalPnl;
        if (dd > maxDrawdown) maxDrawdown = dd;
        if (pnl > 0) wins++;
        else losses++;
      }
    }

    final executed = wins + losses;
    final winRate = executed > 0 ? wins / executed : 0.0;
    final avgRR = signals.isNotEmpty
        ? signals.map((s) => s.riskRewardRatio).reduce((a, b) => a + b) / signals.length
        : 0.0;
    final expectancy = executed > 0 ? totalPnl / executed : 0.0;

    // 简化夏普
    double sharpe = 0;
    if (pnlList.length > 1) {
      final mean = pnlList.reduce((a, b) => a + b) / pnlList.length;
      double variance = 0;
      for (final p in pnlList) variance += (p - mean) * (p - mean);
      final std = (variance / pnlList.length);
      sharpe = std > 0 ? mean / std : 0;
    }

    return BacktestResult(
      totalSignals: signals.length,
      winningTrades: wins,
      losingTrades: losses,
      winRate: winRate,
      avgRiskReward: avgRR,
      expectancy: expectancy,
      maxDrawdown: maxDrawdown,
      totalPnl: totalPnl,
      sharpeRatio: sharpe,
    );
  }

  /// 按市场状态分组回测
  static Map<String, BacktestResult> runByRegime(List<TradingSignal> signals) {
    final groups = <String, List<TradingSignal>>{};
    for (final sig in signals) {
      groups.putIfAbsent(sig.marketRegime, () => []).add(sig);
    }
    return groups.map((k, v) => MapEntry(k, runFromSignals(v)));
  }

  /// 按置信度区间分组回测
  static Map<String, BacktestResult> runByConfidence(List<TradingSignal> signals) {
    final groups = <String, List<TradingSignal>>{
      '65-69': [],
      '70-79': [],
      '80-89': [],
      '90+': [],
    };
    for (final sig in signals) {
      if (sig.confidenceScore < 70) groups['65-69']!.add(sig);
      else if (sig.confidenceScore < 80) groups['70-79']!.add(sig);
      else if (sig.confidenceScore < 90) groups['80-89']!.add(sig);
      else groups['90+']!.add(sig);
    }
    return groups.map((k, v) => MapEntry(k, runFromSignals(v)));
  }
}
