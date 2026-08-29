import 'dart:math';
import '../models/market_data.dart';
import '../models/signal.dart';

/// ============================================================
/// 1. 专业NLP消息面情绪分析器
/// ============================================================
class AdvancedSentimentAnalyzer {
  /// 正面关键词权重
  static final Map<String, double> positiveKeywords = {
    'surge': 2.0, 'rally': 2.0, 'bullish': 3.0, 'breakout': 2.5,
    'soar': 2.0, 'jump': 1.5, 'gain': 1.5, 'pump': 2.0,
    'moon': 3.0, 'lambo': 2.5, 'adoption': 2.0, 'institutional': 2.5,
    'etf': 3.0, 'approval': 2.5, 'partnership': 1.5, 'upgrade': 1.5,
    'mainnet': 2.0, 'launch': 1.5, 'record': 2.0, 'high': 1.0,
    'growth': 1.5, 'profit': 1.5, 'buy': 1.5, 'long': 1.5,
    'accumulate': 2.0, 'accumulation': 2.0, 'support': 1.0,
    'rebound': 1.5, 'recovery': 1.5, 'momentum': 1.5,
  };

  /// 负面关键词权重
  static final Map<String, double> negativeKeywords = {
    'crash': 3.0, 'dump': 2.5, 'bearish': 3.0, 'plunge': 2.5,
    'drop': 1.5, 'loss': 1.5, 'hack': 3.0, 'ban': 2.5,
    'fraud': 3.0, 'scam': 3.0, 'exploit': 2.5, 'rug': 3.0,
    'pull': 2.0, 'sell': 1.5, 'short': 1.5, 'fear': 2.0,
    'panic': 2.5, 'liquidation': 2.0, 'liquidate': 2.0,
    'decline': 1.5, 'fall': 1.5, 'low': 1.0, 'risk': 1.0,
    'warning': 1.5, 'concern': 1.0, 'uncertainty': 1.5,
    'regulation': 1.5, 'crackdown': 2.5, 'sec': 2.0,
    'lawsuit': 2.0, 'investigation': 2.0, 'inflation': 1.5,
    'recession': 2.0, 'crisis': 2.5,
  };

  /// 分析新闻标题的情绪
  static SentimentResult analyzeTitle(String title, String source) {
    final lowerTitle = title.toLowerCase();
    double positiveScore = 0;
    double negativeScore = 0;
    final matchedKeywords = <String>[];

    // 匹配正面关键词
    positiveKeywords.forEach((keyword, weight) {
      if (lowerTitle.contains(keyword)) {
        positiveScore += weight;
        matchedKeywords.add('+$keyword');
      }
    });

    // 匹配负面关键词
    negativeKeywords.forEach((keyword, weight) {
      if (lowerTitle.contains(keyword)) {
        negativeScore += weight;
        matchedKeywords.add('-$keyword');
      }
    });

    // 来源权重
    double sourceWeight = 1.0;
    if (source.contains('CoinDesk') || source.contains('CoinTelegraph') || source.contains('The Block')) {
      sourceWeight = 1.3; // 权威媒体权重更高
    } else if (source.contains('Twitter') || source.contains('Reddit')) {
      sourceWeight = 0.7; // 社交媒体权重较低
    }

    // 标题长度权重（越长信息越多）
    double lengthWeight = title.length > 80 ? 1.2 : title.length > 50 ? 1.0 : 0.8;

    // 计算最终情绪分数（-100到+100）
    final totalScore = positiveScore + negativeScore;
    double sentiment = 0;
    if (totalScore > 0) {
      sentiment = ((positiveScore - negativeScore) / totalScore) * 100;
    }
    sentiment = sentiment * sourceWeight * lengthWeight;
    sentiment = sentiment.clamp(-100, 100).toDouble();

    // 影响度
    int impact = 1;
    if (totalScore > 5) impact = 3;
    else if (totalScore > 2) impact = 2;
    if (title.contains(RegExp(r'ETF|SEC|Fed|Bitcoin|Ethereum|institutional', caseSensitive: false))) {
      impact = impact >= 3 ? 4 : impact + 1;
    }

    return SentimentResult(
      sentiment: sentiment,
      positiveScore: positiveScore,
      negativeScore: negativeScore,
      impact: impact,
      matchedKeywords: matchedKeywords,
      label: sentiment > 20 ? '看涨' : sentiment < -20 ? '看跌' : '中性',
    );
  }

  /// 批量分析新闻，计算综合情绪
  static double analyzeBatch(List<dynamic> newsItems) {
    if (newsItems.isEmpty) return 50;
    double totalSentiment = 0;
    double totalWeight = 0;
    for (final item in newsItems) {
      final title = item['title'] ?? '';
      final source = item['source_info']?['name'] ?? '';
      final result = analyzeTitle(title, source);
      final weight = result.impact.toDouble();
      totalSentiment += result.sentiment * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) return 50;
    // 转换为0-100的贪婪恐惧指数风格
    final avgSentiment = totalSentiment / totalWeight;
    return ((avgSentiment + 100) / 2).clamp(0, 100).toDouble();
  }
}

class SentimentResult {
  final double sentiment; // -100到+100
  final double positiveScore;
  final double negativeScore;
  final int impact; // 1-4
  final List<String> matchedKeywords;
  final String label;

  SentimentResult({
    required this.sentiment,
    required this.positiveScore,
    required this.negativeScore,
    required this.impact,
    required this.matchedKeywords,
    required this.label,
  });
}

/// ============================================================
/// 2. 机器学习参数优化器（基于历史表现的自适应参数调整）
/// ============================================================
class MLParameterOptimizer {
  // 参数历史记录
  final List<ParameterSnapshot> _history = [];
  // 当前参数
  Map<String, double> _currentParams = {};
  // 最佳参数
  Map<String, double>? _bestParams;
  double _bestWinRate = 0;
  double _bestProfitFactor = 0;

  // 参数范围
  static final Map<String, Map<String, double>> paramRanges = {
    'rsi_oversold': {'min': 20, 'max': 40, 'default': 30},
    'rsi_overbought': {'min': 60, 'max': 80, 'default': 70},
    'min_risk_reward': {'min': 2.0, 'max': 5.0, 'default': 3.0},
    'confirmation_count': {'min': 1, 'max': 5, 'default': 2},
    'atr_stop_multiplier': {'min': 1.0, 'max': 3.0, 'default': 1.5},
    'volume_threshold': {'min': 1.5, 'max': 4.0, 'default': 2.0},
  };

  MLParameterOptimizer() {
    _initDefaultParams();
  }

  void _initDefaultParams() {
    paramRanges.forEach((key, range) {
      _currentParams[key] = range['default']!;
    });
  }

  Map<String, double> get currentParams => Map.unmodifiable(_currentParams);
  Map<String, double>? get bestParams => _bestParams != null ? Map.unmodifiable(_bestParams!) : null;
  double get bestWinRate => _bestWinRate;
  double get bestProfitFactor => _bestProfitFactor;

  /// 记录一次参数快照和结果
  void recordResult(Map<String, double> params, double winRate, double profitFactor, int tradeCount) {
    final snapshot = ParameterSnapshot(
      params: Map.from(params),
      winRate: winRate,
      profitFactor: profitFactor,
      tradeCount: tradeCount,
      timestamp: DateTime.now(),
    );
    _history.add(snapshot);

    // 更新最佳参数（至少10笔交易才考虑）
    if (tradeCount >= 10 && winRate > _bestWinRate) {
      _bestWinRate = winRate;
      _bestProfitFactor = profitFactor;
      _bestParams = Map.from(params);
    }

    // 限制历史记录数量
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  /// 基于历史表现优化参数（梯度下降风格）
  Map<String, double> optimize() {
    if (_history.length < 5) return _currentParams;

    // 找到表现最好的20%快照
    final sorted = List<ParameterSnapshot>.from(_history)
      ..sort((a, b) => b.winRate.compareTo(a.winRate));
    final topCount = (sorted.length * 0.2).ceil();
    final topSnapshots = sorted.take(topCount).toList();

    // 计算最佳参数的平均值
    final optimizedParams = <String, double>{};
    paramRanges.forEach((key, range) {
      final values = topSnapshots.map((s) => s.params[key] ?? range['default']!).toList();
      final avg = values.reduce((a, b) => a + b) / values.length;
      // 添加小幅度随机探索（5%）
      final exploration = (Random().nextDouble() - 0.5) * 0.1 * avg;
      optimizedParams[key] = (avg + exploration).clamp(range['min']!, range['max']!);
    });

    _currentParams = optimizedParams;
    return optimizedParams;
  }

  /// 获取参数建议
  String getRecommendation() {
    if (_history.isEmpty) return '数据不足，建议先积累至少20笔交易记录';
    if (_bestParams == null) return '正在积累数据，暂无最佳参数';
    final improvements = <String>[];
    _bestParams!.forEach((key, value) {
      final current = _currentParams[key]!;
      if ((value - current).abs() > 0.1) {
        improvements.add('$key: ${current.toStringAsFixed(1)} → ${value.toStringAsFixed(1)}');
      }
    });
    if (improvements.isEmpty) return '当前参数已接近最佳，建议保持';
    return '建议调整: ${improvements.join(', ')}';
  }
}

class ParameterSnapshot {
  final Map<String, double> params;
  final double winRate;
  final double profitFactor;
  final int tradeCount;
  final DateTime timestamp;

  ParameterSnapshot({
    required this.params,
    required this.winRate,
    required this.profitFactor,
    required this.tradeCount,
    required this.timestamp,
  });
}

/// ============================================================
/// 3. 完善的回测系统
/// ============================================================
class BacktestEngine {
  /// 回测结果
  static BacktestResult runBacktest({
    required List<Kline> klines,
    required Map<String, double> params,
    double initialCapital = 10000,
    double riskPerTrade = 0.01,
  }) {
    if (klines.length < 50) {
      return BacktestResult(
        totalTrades: 0,
        winRate: 0,
        profitFactor: 0,
        totalReturn: 0,
        maxDrawdown: 0,
        avgWin: 0,
        avgLoss: 0,
        trades: [],
      );
    }

    final trades = <BacktestTrade>[];
    double capital = initialCapital;
    double peakCapital = initialCapital;
    double maxDrawdown = 0;

    final rsiPeriod = 14;
    final rsiOversold = params['rsi_oversold'] ?? 30;
    final rsiOverbought = params['rsi_overbought'] ?? 70;
    final minRiskReward = params['min_risk_reward'] ?? 3.0;
    final atrMultiplier = params['atr_stop_multiplier'] ?? 1.5;

    // 计算RSI
    final rsiValues = _calculateRSI(klines, rsiPeriod);
    // 计算ATR
    final atrValues = _calculateATR(klines, 14);

    for (int i = 50; i < klines.length - 20; i++) {
      final rsi = rsiValues[i];
      final atr = atrValues[i];
      if (rsi == null || atr == null || atr == 0) continue;

      final currentPrice = klines[i].close;

      // 做多信号：RSI超卖
      if (rsi < rsiOversold) {
        final stopLoss = currentPrice - atr * atrMultiplier;
        final takeProfit = currentPrice + atr * atrMultiplier * minRiskReward;
        final riskDistance = currentPrice - stopLoss;
        if (riskDistance <= 0) continue;

        final positionSize = (capital * riskPerTrade) / riskDistance;

        // 模拟未来20根K线的走势
        double exitPrice = stopLoss;
        int exitBar = i + 20;
        for (int j = i + 1; j < klines.length && j < i + 20; j++) {
          if (klines[j].low <= stopLoss) {
            exitPrice = stopLoss;
            exitBar = j;
            break;
          }
          if (klines[j].high >= takeProfit) {
            exitPrice = takeProfit;
            exitBar = j;
            break;
          }
        }

        final pnl = (exitPrice - currentPrice) * positionSize;
        capital += pnl;
        if (capital > peakCapital) peakCapital = capital;
        final drawdown = (peakCapital - capital) / peakCapital * 100;
        if (drawdown > maxDrawdown) maxDrawdown = drawdown;

        trades.add(BacktestTrade(
          direction: 'long',
          entryPrice: currentPrice,
          exitPrice: exitPrice,
          stopLoss: stopLoss,
          takeProfit: takeProfit,
          pnl: pnl,
          pnlPercent: pnl / capital * 100,
          entryBar: i,
          exitBar: exitBar,
          isWin: pnl > 0,
        ));
      }

      // 做空信号：RSI超买
      if (rsi > rsiOverbought) {
        final stopLoss = currentPrice + atr * atrMultiplier;
        final takeProfit = currentPrice - atr * atrMultiplier * minRiskReward;
        final riskDistance = stopLoss - currentPrice;
        if (riskDistance <= 0) continue;

        final positionSize = (capital * riskPerTrade) / riskDistance;

        double exitPrice = stopLoss;
        int exitBar = i + 20;
        for (int j = i + 1; j < klines.length && j < i + 20; j++) {
          if (klines[j].high >= stopLoss) {
            exitPrice = stopLoss;
            exitBar = j;
            break;
          }
          if (klines[j].low <= takeProfit) {
            exitPrice = takeProfit;
            exitBar = j;
            break;
          }
        }

        final pnl = (currentPrice - exitPrice) * positionSize;
        capital += pnl;
        if (capital > peakCapital) peakCapital = capital;
        final drawdown = (peakCapital - capital) / peakCapital * 100;
        if (drawdown > maxDrawdown) maxDrawdown = drawdown;

        trades.add(BacktestTrade(
          direction: 'short',
          entryPrice: currentPrice,
          exitPrice: exitPrice,
          stopLoss: stopLoss,
          takeProfit: takeProfit,
          pnl: pnl,
          pnlPercent: pnl / capital * 100,
          entryBar: i,
          exitBar: exitBar,
          isWin: pnl > 0,
        ));
      }
    }

    // 计算统计数据
    final wins = trades.where((t) => t.isWin).toList();
    final losses = trades.where((t) => !t.isWin).toList();
    final winRate = trades.isNotEmpty ? wins.length / trades.length * 100 : 0;
    final totalWin = wins.fold(0.0, (sum, t) => sum + t.pnl);
    final totalLoss = losses.fold(0.0, (sum, t) => sum + t.pnl.abs());
    final profitFactor = totalLoss > 0 ? totalWin / totalLoss : 0;
    final totalReturn = (capital - initialCapital) / initialCapital * 100;
    final avgWin = wins.isNotEmpty ? totalWin / wins.length : 0;
    final avgLoss = losses.isNotEmpty ? totalLoss / losses.length : 0;

    return BacktestResult(
      totalTrades: trades.length,
      winRate: winRate,
      profitFactor: profitFactor,
      totalReturn: totalReturn,
      maxDrawdown: maxDrawdown,
      avgWin: avgWin,
      avgLoss: avgLoss,
      trades: trades,
    );
  }

  /// 计算RSI
  static List<double?> _calculateRSI(List<Kline> klines, int period) {
    final result = List<double?>.filled(klines.length, null);
    if (klines.length < period + 1) return result;

    double gains = 0;
    double losses = 0;
    for (int i = 1; i <= period; i++) {
      final change = klines[i].close - klines[i - 1].close;
      if (change > 0) gains += change;
      else losses += change.abs();
    }

    double avgGain = gains / period;
    double avgLoss = losses / period;
    result[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));

    for (int i = period + 1; i < klines.length; i++) {
      final change = klines[i].close - klines[i - 1].close;
      final gain = change > 0 ? change : 0;
      final loss = change < 0 ? change.abs() : 0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      result[i] = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));
    }
    return result;
  }

  /// 计算ATR
  static List<double?> _calculateATR(List<Kline> klines, int period) {
    final result = List<double?>.filled(klines.length, null);
    if (klines.length < period + 1) return result;

    final trList = <double>[];
    for (int i = 0; i < klines.length; i++) {
      double tr;
      if (i == 0) {
        tr = klines[i].high - klines[i].low;
      } else {
        final hl = klines[i].high - klines[i].low;
        final hc = (klines[i].high - klines[i - 1].close).abs();
        final lc = (klines[i].low - klines[i - 1].close).abs();
        tr = [hl, hc, lc].reduce((a, b) => a > b ? a : b);
      }
      trList.add(tr);
    }

    for (int i = period - 1; i < trList.length; i++) {
      if (i == period - 1) {
        double sum = 0;
        for (int j = 0; j < period; j++) sum += trList[j];
        result[i] = sum / period;
      } else {
        result[i] = (result[i - 1]! * (period - 1) + trList[i]) / period;
      }
    }
    return result;
  }

  /// 参数优化：网格搜索最佳参数
  static Map<String, double> optimizeParams(List<Kline> klines) {
    final bestParams = <String, double>{
      'rsi_oversold': 30,
      'rsi_overbought': 70,
      'min_risk_reward': 3.0,
      'atr_stop_multiplier': 1.5,
    };
    double bestScore = 0;

    // 网格搜索
    for (int rsiOS = 20; rsiOS <= 40; rsiOS += 5) {
      for (int rsiOB = 60; rsiOB <= 80; rsiOB += 5) {
        for (double rr = 2.0; rr <= 5.0; rr += 1.0) {
          for (double atr = 1.0; atr <= 3.0; atr += 0.5) {
            final params = {
              'rsi_oversold': rsiOS.toDouble(),
              'rsi_overbought': rsiOB.toDouble(),
              'min_risk_reward': rr,
              'atr_stop_multiplier': atr,
            };
            final result = runBacktest(klines: klines, params: params);
            // 综合评分：胜率×盈亏因子×总收益，至少10笔交易
            if (result.totalTrades >= 10) {
              final score = result.winRate * result.profitFactor * (1 + result.totalReturn / 100);
              if (score > bestScore) {
                bestScore = score;
                bestParams.addAll(params);
              }
            }
          }
        }
      }
    }
    return bestParams;
  }
}

class BacktestResult {
  final int totalTrades;
  final double winRate;
  final double profitFactor;
  final double totalReturn;
  final double maxDrawdown;
  final double avgWin;
  final double avgLoss;
  final List<BacktestTrade> trades;

  BacktestResult({
    required this.totalTrades,
    required this.winRate,
    required this.profitFactor,
    required this.totalReturn,
    required this.maxDrawdown,
    required this.avgWin,
    required this.avgLoss,
    required this.trades,
  });

  String get summary =>
      '交易:$totalTrades 胜率:${winRate.toStringAsFixed(1)}% 盈亏比:${profitFactor.toStringAsFixed(2)} 收益:${totalReturn.toStringAsFixed(1)}% 回撤:${maxDrawdown.toStringAsFixed(1)}%';
}

class BacktestTrade {
  final String direction;
  final double entryPrice;
  final double exitPrice;
  final double stopLoss;
  final double takeProfit;
  final double pnl;
  final double pnlPercent;
  final int entryBar;
  final int exitBar;
  final bool isWin;

  BacktestTrade({
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.pnl,
    required this.pnlPercent,
    required this.entryBar,
    required this.exitBar,
    required this.isWin,
  });
}
