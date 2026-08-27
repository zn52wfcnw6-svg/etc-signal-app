/// 回测结果模型
class BacktestResult {
  final int totalSignals;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double avgProfit;
  final double avgLoss;
  final double profitFactor;
  final double maxDrawdown;
  final double totalReturn;
  final double sharpeRatio;
  final List<BacktestTrade> trades;

  const BacktestResult({
    required this.totalSignals,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.avgProfit,
    required this.avgLoss,
    required this.profitFactor,
    required this.maxDrawdown,
    required this.totalReturn,
    required this.sharpeRatio,
    required this.trades,
  });

  String get winRateText => '${(winRate * 100).toStringAsFixed(1)}%';
  String get profitFactorText => profitFactor.toStringAsFixed(2);
  String get maxDrawdownText => '${(maxDrawdown * 100).toStringAsFixed(2)}%';
  String get totalReturnText => '${(totalReturn * 100).toStringAsFixed(2)}%';
  String get sharpeRatioText => sharpeRatio.toStringAsFixed(2);
}

/// 回测交易记录
class BacktestTrade {
  final DateTime entryTime;
  final DateTime exitTime;
  final String direction; // 'long' or 'short'
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final double pnl;
  final double pnlPercent;
  final String exitReason; // 'tp1', 'tp2', 'sl', 'timeout'

  const BacktestTrade({
    required this.entryTime,
    required this.exitTime,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.pnl,
    required this.pnlPercent,
    required this.exitReason,
  });
}
