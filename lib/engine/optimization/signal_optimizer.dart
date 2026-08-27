import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/signal.dart';
import '../../utils/constants.dart';
import '../market_regime/market_regime.dart';

/// 信号记录（用于胜率统计）
class SignalRecord {
  final String id;
  final DateTime timestamp;
  final SignalDirection direction;
  final double entryPrice;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final String marketRegime; // 市场状态
  final String regime; // 具体regime名称
  final int mtfResonance; // 多周期共振强度 0-5
  final double confidenceScore;
  final Map<String, bool> gates; // 各闸门通过情况
  SignalOutcome? outcome; // 结果
  double? pnlPercent; // 盈亏百分比

  SignalRecord({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.entryPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.marketRegime,
    required this.regime,
    required this.mtfResonance,
    required this.confidenceScore,
    required this.gates,
    this.outcome,
    this.pnlPercent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'direction': direction.name,
    'entryPrice': entryPrice,
    'stopLoss': stopLoss,
    'tp1': tp1,
    'tp2': tp2,
    'marketRegime': marketRegime,
    'regime': regime,
    'mtfResonance': mtfResonance,
    'confidenceScore': confidenceScore,
    'gates': gates,
    'outcome': outcome?.name,
    'pnlPercent': pnlPercent,
  };

  factory SignalRecord.fromJson(Map<String, dynamic> json) => SignalRecord(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    direction: SignalDirection.values.firstWhere((e) => e.name == json['direction']),
    entryPrice: json['entryPrice'].toDouble(),
    stopLoss: json['stopLoss'].toDouble(),
    tp1: json['tp1'].toDouble(),
    tp2: json['tp2'].toDouble(),
    marketRegime: json['marketRegime'],
    regime: json['regime'],
    mtfResonance: json['mtfResonance'],
    confidenceScore: json['confidenceScore'],
    gates: Map<String, bool>.from(json['gates']),
    outcome: json['outcome'] != null ? SignalOutcome.values.firstWhere((e) => e.name == json['outcome']) : null,
    pnlPercent: json['pnlPercent']?.toDouble(),
  );
}

/// 信号结果
enum SignalOutcome {
  tp1Hit,    // 止盈1
  tp2Hit,    // 止盈2
  stopLoss,  // 止损
  expired,   // 过期未触发
}

/// 胜率统计结果
class WinRateStats {
  final int totalSignals;
  final int winningSignals;
  final int losingSignals;
  final double winRate;
  final double avgWinPercent;
  final double avgLossPercent;
  final double profitFactor;
  final Map<String, double> regimeWinRates; // 各市场状态胜率
  final Map<String, double> gateWinRates; // 各闸门组合胜率

  WinRateStats({
    required this.totalSignals,
    required this.winningSignals,
    required this.losingSignals,
    required this.winRate,
    required this.avgWinPercent,
    required this.avgLossPercent,
    required this.profitFactor,
    required this.regimeWinRates,
    required this.gateWinRates,
  });
}

/// 胜率自优化引擎
class SignalOptimizer {
  final List<SignalRecord> _records = [];
  final Map<String, double> _gateWeights = {}; // 各闸门权重调整
  double _minConfidenceThreshold = 60; // 最低置信度阈值

  List<SignalRecord> get records => List.unmodifiable(_records);
  double get minConfidenceThreshold => _minConfidenceThreshold;

  /// 记录一个信号
  void recordSignal(SignalRecord record) {
    _records.add(record);
    if (_records.length > 500) _records.removeAt(0);
    _recomputeWeights();
  }

  /// 更新信号结果
  void updateOutcome(String signalId, SignalOutcome outcome, double pnlPercent) {
    final idx = _records.indexWhere((r) => r.id == signalId);
    if (idx >= 0) {
      _records[idx] = SignalRecord(
        id: _records[idx].id,
        timestamp: _records[idx].timestamp,
        direction: _records[idx].direction,
        entryPrice: _records[idx].entryPrice,
        stopLoss: _records[idx].stopLoss,
        tp1: _records[idx].tp1,
        tp2: _records[idx].tp2,
        marketRegime: _records[idx].marketRegime,
        regime: _records[idx].regime,
        mtfResonance: _records[idx].mtfResonance,
        confidenceScore: _records[idx].confidenceScore,
        gates: _records[idx].gates,
        outcome: outcome,
        pnlPercent: pnlPercent,
      );
      _recomputeWeights();
    }
  }

  /// 判断当前信号是否应该被过滤（基于历史胜率）
  bool shouldFilter({
    required String regime,
    required int mtfResonance,
    required int confidenceScore,
    required Map<String, bool> gates,
  }) {
    // 样本不足时不过滤
    if (_records.where((r) => r.outcome != null).length < 10) return false;

    // 置信度低于动态阈值则过滤
    if (confidenceScore < _minConfidenceThreshold) return true;

    // 该市场状态胜率低于40%则过滤
    final regimeStats = _statsByRegime(regime);
    if (regimeStats['count'] >= 5 && regimeStats['winRate'] < 0.4) return true;

    // 多周期共振强度低于2则过滤
    if (mtfResonance < 2) return true;

    return false;
  }

  /// 获取胜率统计
  WinRateStats getStats() {
    final resolved = _records.where((r) => r.outcome != null).toList();
    final winners = resolved.where((r) =>
      r.outcome == SignalOutcome.tp1Hit || r.outcome == SignalOutcome.tp2Hit).toList();
    final losers = resolved.where((r) => r.outcome == SignalOutcome.stopLoss).toList();

    final totalWin = winners.fold<double>(0, (sum, r) => sum + (r.pnlPercent ?? 0));
    final totalLoss = losers.fold<double>(0, (sum, r) => sum + (r.pnlPercent ?? 0).abs());

    // 各市场状态胜率
    final regimeWinRates = <String, double>{};
    final regimes = resolved.map((r) => r.regime).toSet();
    for (final regime in regimes) {
      final regimeRecords = resolved.where((r) => r.regime == regime).toList();
      final regimeWins = regimeRecords.where((r) =>
        r.outcome == SignalOutcome.tp1Hit || r.outcome == SignalOutcome.tp2Hit).length;
      regimeWinRates[regime] = regimeRecords.isNotEmpty ? regimeWins / regimeRecords.length : 0;
    }

    // 各闸门胜率（简化：统计通过该闸门的信号胜率）
    final gateWinRates = <String, double>{};
    final allGates = resolved.expand((r) => r.gates.keys).toSet();
    for (final gate in allGates) {
      final gateRecords = resolved.where((r) => r.gates[gate] == true).toList();
      final gateWins = gateRecords.where((r) =>
        r.outcome == SignalOutcome.tp1Hit || r.outcome == SignalOutcome.tp2Hit).length;
      gateWinRates[gate] = gateRecords.isNotEmpty ? gateWins / gateRecords.length : 0;
    }

    return WinRateStats(
      totalSignals: resolved.length,
      winningSignals: winners.length,
      losingSignals: losers.length,
      winRate: resolved.isNotEmpty ? winners.length / resolved.length : 0,
      avgWinPercent: winners.isNotEmpty ? totalWin / winners.length : 0,
      avgLossPercent: losers.isNotEmpty ? totalLoss / losers.length : 0,
      profitFactor: totalLoss > 0 ? totalWin / totalLoss : 0,
      regimeWinRates: regimeWinRates,
      gateWinRates: gateWinRates,
    );
  }

  /// 重新计算权重和阈值
  void _recomputeWeights() {
    final resolved = _records.where((r) => r.outcome != null).toList();
    if (resolved.length < 10) return;

    // 根据整体胜率调整置信度阈值
    final stats = getStats();
    if (stats.winRate < 0.5) {
      _minConfidenceThreshold = 70; // 胜率低，提高门槛
    } else if (stats.winRate > 0.7) {
      _minConfidenceThreshold = 55; // 胜率高，放宽门槛
    } else {
      _minConfidenceThreshold = 60;
    }

    // 计算各闸门权重（胜率高的闸门权重高）
    _gateWeights.clear();
    for (final entry in stats.gateWinRates.entries) {
      // 胜率>60%权重1.2，<40%权重0.8，中间1.0
      if (entry.value > 0.6) {
        _gateWeights[entry.key] = 1.2;
      } else if (entry.value < 0.4) {
        _gateWeights[entry.key] = 0.8;
      } else {
        _gateWeights[entry.key] = 1.0;
      }
    }
  }

  Map<String, dynamic> _statsByRegime(String regime) {
    final regimeRecords = _records.where((r) => r.regime == regime && r.outcome != null).toList();
    final wins = regimeRecords.where((r) =>
      r.outcome == SignalOutcome.tp1Hit || r.outcome == SignalOutcome.tp2Hit).length;
    return {
      'count': regimeRecords.length,
      'winRate': regimeRecords.isNotEmpty ? wins / regimeRecords.length : 0,
    };
  }

  /// 获取闸门权重（用于置信度计算）
  double getGateWeight(String gateName) => _gateWeights[gateName] ?? 1.0;

  /// 导出数据（用于持久化）
  String exportData() {
    return jsonEncode(_records.map((r) => r.toJson()).toList());
  }

  /// 导入数据
  void importData(String data) {
    try {
      final List<dynamic> list = jsonDecode(data);
      _records.clear();
      for (final item in list) {
        _records.add(SignalRecord.fromJson(item));
      }
      _recomputeWeights();
    } catch (e) {
      debugPrint('Failed to import optimizer data: $e');
    }
  }
}
