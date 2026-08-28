import 'dart:collection';
import '../engine/sss/sss_analyzer.dart';

/// 信号历史统计模块
/// 记录推单区历史信号，统计实际胜率和盈亏比
class SignalHistoryTracker {
  static final SignalHistoryTracker _instance = SignalHistoryTracker._internal();
  factory SignalHistoryTracker() => _instance;
  SignalHistoryTracker._internal();

  final List<SignalRecord> _records = [];
  final Queue<SignalRecord> _pendingSignals = Queue<SignalRecord>();

  /// 记录新信号
  void recordSignal({
    required String direction,
    required double entryPrice,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required double sssScore,
    required String grade,
  }) {
    final record = SignalRecord(
      id: DateTime.now().millisecondsSinceEpoch,
      direction: direction,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      sssScore: sssScore,
      grade: grade,
      createdAt: DateTime.now(),
      status: SignalStatus.pending,
    );
    _records.add(record);
    _pendingSignals.add(record);
    // 只保留最近1000条记录
    if (_records.length > 1000) {
      _records.removeAt(0);
    }
  }

  /// 更新信号状态（根据当前价格判断是否触发止损/止盈）
  void updateSignals(double currentPrice) {
    for (final record in _pendingSignals.toList()) {
      if (record.status != SignalStatus.pending) continue;

      if (record.direction == 'long') {
        if (currentPrice <= record.stopLoss) {
          record.status = SignalStatus.stopped;
          record.exitPrice = record.stopLoss;
          record.pnl = (record.stopLoss - record.entryPrice) / record.entryPrice;
          _pendingSignals.remove(record);
        } else if (currentPrice >= record.tp2) {
          record.status = SignalStatus.tp2;
          record.exitPrice = record.tp2;
          record.pnl = (record.tp2 - record.entryPrice) / record.entryPrice;
          _pendingSignals.remove(record);
        } else if (currentPrice >= record.tp1) {
          record.status = SignalStatus.tp1;
          record.exitPrice = record.tp1;
          record.pnl = (record.tp1 - record.entryPrice) / record.entryPrice * 0.6;
          // TP1后继续持有剩余仓位，不立即移除
        }
      } else {
        // 做空
        if (currentPrice >= record.stopLoss) {
          record.status = SignalStatus.stopped;
          record.exitPrice = record.stopLoss;
          record.pnl = (record.entryPrice - record.stopLoss) / record.entryPrice;
          _pendingSignals.remove(record);
        } else if (currentPrice <= record.tp2) {
          record.status = SignalStatus.tp2;
          record.exitPrice = record.tp2;
          record.pnl = (record.entryPrice - record.tp2) / record.entryPrice;
          _pendingSignals.remove(record);
        } else if (currentPrice <= record.tp1) {
          record.status = SignalStatus.tp1;
          record.exitPrice = record.tp1;
          record.pnl = (record.entryPrice - record.tp1) / record.entryPrice * 0.6;
        }
      }
    }
  }

  /// 获取统计数据
  SignalStats getStats() {
    final closed = _records.where((r) => r.status != SignalStatus.pending).toList();
    final wins = closed.where((r) => r.pnl > 0).toList();
    final losses = closed.where((r) => r.pnl <= 0).toList();
    final totalPnl = closed.fold<double>(0, (sum, r) => sum + r.pnl);
    final avgWin = wins.isNotEmpty ? wins.map((r) => r.pnl).reduce((a, b) => a + b) / wins.length : 0;
    final avgLoss = losses.isNotEmpty ? losses.map((r) => r.pnl.abs()).reduce((a, b) => a + b) / losses.length : 0;

    // 按SSS评分区间统计
    final highScore = closed.where((r) => r.sssScore >= 80).toList();
    final highWins = highScore.where((r) => r.pnl > 0).length;

    return SignalStats(
      totalSignals: closed.length,
      pendingSignals: _pendingSignals.length,
      winningTrades: wins.length,
      losingTrades: losses.length,
      winRate: closed.isNotEmpty ? (wins.length / closed.length).toDouble() : 0.0,
      totalPnl: totalPnl,
      avgWin: avgWin,
      avgLoss: avgLoss,
      profitFactor: avgLoss > 0 ? (avgWin / avgLoss).toDouble() : 0.0,
      highScoreWinRate: highScore.isNotEmpty ? (highWins / highScore.length).toDouble() : 0.0,
      highScoreCount: highScore.length,
    );
  }

  /// 获取最近信号记录
  List<SignalRecord> getRecentSignals({int count = 20}) {
    return _records.reversed.take(count).toList();
  }

  /// 重置统计
  void reset() {
    _records.clear();
    _pendingSignals.clear();
  }
}

/// 信号记录
class SignalRecord {
  final int id;
  final String direction; // 'long' or 'short'
  final double entryPrice;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final double sssScore;
  final String grade;
  final DateTime createdAt;
  SignalStatus status;
  double? exitPrice;
  double pnl;

  SignalRecord({
    required this.id,
    required this.direction,
    required this.entryPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.sssScore,
    required this.grade,
    required this.createdAt,
    required this.status,
    this.exitPrice,
    this.pnl = 0,
  });
}

/// 信号状态
enum SignalStatus {
  pending, // 待执行
  tp1, // 止盈1
  tp2, // 止盈2
  stopped, // 止损
}

/// 信号统计
class SignalStats {
  final int totalSignals;
  final int pendingSignals;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double totalPnl;
  final double avgWin;
  final double avgLoss;
  final double profitFactor;
  final double highScoreWinRate;
  final int highScoreCount;

  const SignalStats({
    required this.totalSignals,
    required this.pendingSignals,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.totalPnl,
    required this.avgWin,
    required this.avgLoss,
    required this.profitFactor,
    required this.highScoreWinRate,
    required this.highScoreCount,
  });

  String get winRateText => '${(winRate * 100).toStringAsFixed(1)}%';
  String get totalPnlText => '${(totalPnl * 100).toStringAsFixed(2)}%';
  String get highScoreWinRateText => '${(highScoreWinRate * 100).toStringAsFixed(1)}%';
}
// rebuild trigger 1787921288
