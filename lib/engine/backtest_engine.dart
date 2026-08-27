import 'dart:math';
import '../models/market_data.dart';
import '../models/backtest_result.dart';
import '../utils/indicators.dart';

/// 历史回测引擎
/// S级标准：基于历史K线模拟信号生成和交易执行
class BacktestEngine {
  /// 运行回测
  static BacktestResult runBacktest(
    List<Kline> klines, {
    double riskPerTrade = 0.01, // 每笔风险1%
    double minRiskReward = 3.0, // 最低盈亏比3:1
    int confirmationBars = 3, // 确认K线数
    int lookbackPeriod = 20, // 关键位回看周期
  }) {
    if (klines.length < lookbackPeriod + confirmationBars + 10) {
      return BacktestResult(
        totalSignals: 0,
        winningTrades: 0,
        losingTrades: 0,
        winRate: 0,
        avgProfit: 0,
        avgLoss: 0,
        profitFactor: 0,
        maxDrawdown: 0,
        totalReturn: 0,
        sharpeRatio: 0,
        trades: const [],
      );
    }

    final trades = <BacktestTrade>[];
    double equity = 10000; // 初始资金10000
    final equityCurve = <double>[equity];
    double peakEquity = equity;
    double maxDrawdown = 0;

    int i = lookbackPeriod;

    while (i < klines.length - confirmationBars - 5) {
      // 计算关键位
      final lookback = klines.sublist(i - lookbackPeriod, i);
      final support = _findSupport(lookback);
      final resistance = _findResistance(lookback);
      final currentPrice = klines[i].close;

      // 计算RSI
      final rsi = Indicators.rsi(
        lookback.map((k) => k.close).toList(),
        14,
      );
      final currentRsi = rsi.isNotEmpty ? (rsi.last ?? 50.0) : 50.0;

      // 检测信号
      String? direction;
      double? entryPrice;
      double? stopLoss;
      double? tp1;
      double? tp2;

      // 做多信号：价格接近支撑位 + RSI超卖
      if (support != null &&
          (currentPrice - support!).abs() / support! < 0.02 &&
          currentRsi < 35) {
        direction = 'long';
        entryPrice = currentPrice;
        stopLoss = support! * 0.985;
        final risk = entryPrice - stopLoss;
        tp1 = entryPrice + risk * 1.5;
        tp2 = entryPrice + risk * 3.0;
      }

      // 做空信号：价格接近压力位 + RSI超买
      if (resistance != null &&
          (resistance! - currentPrice).abs() / currentPrice < 0.02 &&
          currentRsi > 65) {
        direction = 'short';
        entryPrice = currentPrice;
        stopLoss = resistance! * 1.015;
        final risk = stopLoss - entryPrice;
        tp1 = entryPrice - risk * 1.5;
        tp2 = entryPrice - risk * 3.0;
      }

      if (direction != null && entryPrice != null && stopLoss != null && tp1 != null && tp2 != null) {
        // 确认信号（连续N根K线维持方向）
        bool confirmed = true;
        for (int j = 1; j <= confirmationBars; j++) {
          if (i + j >= klines.length) {
            confirmed = false;
            break;
          }
          final bar = klines[i + j];
          if (direction == 'long' && bar.close < stopLoss) {
            confirmed = false;
            break;
          }
          if (direction == 'short' && bar.close > stopLoss) {
            confirmed = false;
            break;
          }
        }

        if (confirmed) {
          // 模拟交易执行
          final entryIndex = i + confirmationBars;
          final result = _simulateTrade(
            klines,
            entryIndex,
            direction!,
            entryPrice!,
            stopLoss!,
            tp1!,
            tp2!,
            equity,
            riskPerTrade,
          );

          if (result != null) {
            trades.add(result);
            equity += result.pnl;
            equityCurve.add(equity);
            if (equity > peakEquity) peakEquity = equity;
            final drawdown = (peakEquity - equity) / peakEquity;
            if (drawdown > maxDrawdown) maxDrawdown = drawdown;
            i = entryIndex + 5; // 跳过交易期
            continue;
          }
        }
      }

      i++;
    }

    // 计算统计指标
    final winningTrades = trades.where((t) => t.pnl > 0).toList();
    final losingTrades = trades.where((t) => t.pnl <= 0).toList();
    final winRate = trades.isNotEmpty ? winningTrades.length / trades.length : 0.0;
    final avgProfit = winningTrades.isNotEmpty
        ? winningTrades.map((t) => t.pnl).reduce((a, b) => a + b) / winningTrades.length
        : 0.0;
    final avgLoss = losingTrades.isNotEmpty
        ? losingTrades.map((t) => t.pnl.abs()).reduce((a, b) => a + b) / losingTrades.length
        : 0.0;
    final profitFactor = avgLoss > 0 ? avgProfit / avgLoss : (avgProfit > 0 ? 99.0 : 0.0);
    final totalReturn = (equity - 10000) / 10000;

    // 计算夏普比率
    final returns = <double>[];
    for (int j = 1; j < equityCurve.length; j++) {
      returns.add((equityCurve[j] - equityCurve[j - 1]) / equityCurve[j - 1]);
    }
    final avgReturn = returns.isNotEmpty ? returns.reduce((a, b) => a + b) / returns.length : 0.0;
    final variance = returns.isNotEmpty
        ? returns.map((r) => (r - avgReturn) * (r - avgReturn)).reduce((a, b) => a + b) / returns.length
        : 0.0;
    final stdReturn = sqrt(variance);
    final sharpeRatio = stdReturn > 0 ? (avgReturn / stdReturn) * 15.87 : 0.0; // 年化

    return BacktestResult(
      totalSignals: trades.length,
      winningTrades: winningTrades.length,
      losingTrades: losingTrades.length,
      winRate: winRate,
      avgProfit: avgProfit,
      avgLoss: avgLoss,
      profitFactor: profitFactor,
      maxDrawdown: maxDrawdown,
      totalReturn: totalReturn,
      sharpeRatio: sharpeRatio,
      trades: trades,
    );
  }

  /// 查找支撑位
  static double? _findSupport(List<Kline> klines) {
    if (klines.length < 5) return null;
    final lows = klines.map((k) => k.low).toList();
    lows.sort();
    return lows[lows.length ~/ 4]; // 25%分位数作为支撑
  }

  /// 查找压力位
  static double? _findResistance(List<Kline> klines) {
    if (klines.length < 5) return null;
    final highs = klines.map((k) => k.high).toList();
    highs.sort();
    return highs[(highs.length * 3) ~/ 4]; // 75%分位数作为压力
  }

  /// 模拟单笔交易
  static BacktestTrade? _simulateTrade(
    List<Kline> klines,
    int entryIndex,
    String direction,
    double entryPrice,
    double stopLoss,
    double tp1,
    double tp2,
    double equity,
    double riskPerTrade,
  ) {
    if (entryIndex >= klines.length) return null;

    final riskAmount = equity * riskPerTrade;
    final riskPerUnit = (entryPrice - stopLoss).abs();
    final positionSize = riskAmount / riskPerUnit;

    for (int i = entryIndex; i < klines.length && i < entryIndex + 50; i++) {
      final bar = klines[i];

      if (direction == 'long') {
        // 止损
        if (bar.low <= stopLoss) {
          final pnl = (stopLoss - entryPrice) * positionSize;
          return BacktestTrade(
            entryTime: DateTime.fromMillisecondsSinceEpoch(bar.openTime),
            exitTime: DateTime.fromMillisecondsSinceEpoch(bar.closeTime),
            direction: direction,
            entryPrice: entryPrice,
            exitPrice: stopLoss,
            stopLoss: stopLoss,
            tp1: tp1,
            tp2: tp2,
            pnl: pnl,
            pnlPercent: pnl / equity,
            exitReason: 'sl',
          );
        }
        // TP1
        if (bar.high >= tp1) {
          final pnl = (tp1 - entryPrice) * positionSize * 0.6 + (entryPrice - entryPrice) * positionSize * 0.4;
          return BacktestTrade(
            entryTime: DateTime.fromMillisecondsSinceEpoch(bar.openTime),
            exitTime: DateTime.fromMillisecondsSinceEpoch(bar.closeTime),
            direction: direction,
            entryPrice: entryPrice,
            exitPrice: tp1,
            stopLoss: stopLoss,
            tp1: tp1,
            tp2: tp2,
            pnl: pnl,
            pnlPercent: pnl / equity,
            exitReason: 'tp1',
          );
        }
        // TP2
        if (bar.high >= tp2) {
          final pnl = (tp2 - entryPrice) * positionSize;
          return BacktestTrade(
            entryTime: DateTime.fromMillisecondsSinceEpoch(bar.openTime),
            exitTime: DateTime.fromMillisecondsSinceEpoch(bar.closeTime),
            direction: direction,
            entryPrice: entryPrice,
            exitPrice: tp2,
            stopLoss: stopLoss,
            tp1: tp1,
            tp2: tp2,
            pnl: pnl,
            pnlPercent: pnl / equity,
            exitReason: 'tp2',
          );
        }
      } else {
        // 做空
        if (bar.high >= stopLoss) {
          final pnl = (entryPrice - stopLoss) * positionSize;
          return BacktestTrade(
            entryTime: DateTime.fromMillisecondsSinceEpoch(bar.openTime),
            exitTime: DateTime.fromMillisecondsSinceEpoch(bar.closeTime),
            direction: direction,
            entryPrice: entryPrice,
            exitPrice: stopLoss,
            stopLoss: stopLoss,
            tp1: tp1,
            tp2: tp2,
            pnl: pnl,
            pnlPercent: pnl / equity,
            exitReason: 'sl',
          );
        }
        if (bar.low <= tp1) {
          final pnl = (entryPrice - tp1) * positionSize * 0.6;
          return BacktestTrade(
            entryTime: DateTime.fromMillisecondsSinceEpoch(bar.openTime),
            exitTime: DateTime.fromMillisecondsSinceEpoch(bar.closeTime),
            direction: direction,
            entryPrice: entryPrice,
            exitPrice: tp1,
            stopLoss: stopLoss,
            tp1: tp1,
            tp2: tp2,
            pnl: pnl,
            pnlPercent: pnl / equity,
            exitReason: 'tp1',
          );
        }
        if (bar.low <= tp2) {
          final pnl = (entryPrice - tp2) * positionSize;
          return BacktestTrade(
            entryTime: DateTime.fromMillisecondsSinceEpoch(bar.openTime),
            exitTime: DateTime.fromMillisecondsSinceEpoch(bar.closeTime),
            direction: direction,
            entryPrice: entryPrice,
            exitPrice: tp2,
            stopLoss: stopLoss,
            tp1: tp1,
            tp2: tp2,
            pnl: pnl,
            pnlPercent: pnl / equity,
            exitReason: 'tp2',
          );
        }
      }
    }

    // 超时平仓
    final lastBar = klines[entryIndex + 49 < klines.length ? entryIndex + 49 : klines.length - 1];
    final pnl = direction == 'long'
        ? (lastBar.close - entryPrice) * positionSize
        : (entryPrice - lastBar.close) * positionSize;
    return BacktestTrade(
      entryTime: DateTime.fromMillisecondsSinceEpoch(lastBar.openTime),
      exitTime: DateTime.fromMillisecondsSinceEpoch(lastBar.closeTime),
      direction: direction,
      entryPrice: entryPrice,
      exitPrice: lastBar.close,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      pnl: pnl,
      pnlPercent: pnl / equity,
      exitReason: 'timeout',
    );
  }
}
