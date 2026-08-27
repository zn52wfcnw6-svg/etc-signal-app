import 'dart:convert';

/// 信号结果枚举
enum SignalOutcome {
  pending,
  tp1Hit,
  tp2Hit,
  stopLoss,
  expired,
  cancelled,
}

/// 信号记录
class SignalRecord {
  final String id;
  final DateTime timestamp;
  final dynamic direction; // SignalDirection
  final double entryPrice;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final String marketRegime;
  final String regime;
  final int mtfResonance;
  final double confidenceScore;
  final Map<String, bool> gates;
  SignalOutcome outcome;
  double? actualPnl;

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
    this.outcome = SignalOutcome.pending,
    this.actualPnl,
  });

  String get patternKey {
    final passedGates = gates.entries.where((e) => e.value).map((e) => e.key).toList()..sort();
    return '${regime}_${direction.name}_r$mtfResonance}_${passedGates.join(",")}';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'timestamp': timestamp.millisecondsSinceEpoch,
    'direction': direction.name, 'entryPrice': entryPrice,
    'stopLoss': stopLoss, 'tp1': tp1, 'tp2': tp2,
    'marketRegime': marketRegime, 'regime': regime,
    'mtfResonance': mtfResonance, 'confidenceScore': confidenceScore,
    'gates': gates, 'outcome': outcome.index, 'actualPnl': actualPnl,
  };
}

/// 模式统计
class PatternStat {
  final String patternKey;
  int total;
  int wins;
  int losses;
  double avgWin;
  double avgLoss;

  PatternStat({
    required this.patternKey,
    this.total = 0, this.wins = 0, this.losses = 0,
    this.avgWin = 0, this.avgLoss = 0,
  });

  double get winRate => total > 0 ? wins / total : 0;
  double get expectancy => total > 0
      ? (wins / total) * avgWin - (losses / total) * avgLoss
      : 0;
}

/// 胜率自优化引擎
class SignalOptimizer {
  final Map<String, SignalRecord> _records = {};
  final Map<String, PatternStat> _patternStats = {};
  final Map<String, double> _patternWeights = {};

  int totalSignals = 0;
  int totalWins = 0;

  /// 所有信号记录
  Map<String, SignalRecord> get records => Map.unmodifiable(_records);

  /// 记录新信号
  void recordSignal(SignalRecord record) {
    _records[record.id] = record;
    totalSignals++;
    _updatePatternStats(record);
  }

  /// 更新信号结果
  void updateOutcome(String signalId, SignalOutcome outcome, double pnl) {
    final record = _records[signalId];
    if (record == null) return;

    record.outcome = outcome;
    record.actualPnl = pnl;

    if (outcome == SignalOutcome.tp1Hit || outcome == SignalOutcome.tp2Hit) {
      totalWins++;
      _updatePatternResult(record, true, pnl);
    } else if (outcome == SignalOutcome.stopLoss) {
      _updatePatternResult(record, false, pnl);
    }
  }

  void _updatePatternStats(SignalRecord record) {
    final key = record.patternKey;
    _patternStats.putIfAbsent(key, () => PatternStat(patternKey: key));
    // 不在这里更新胜负，等结果出来再更新
  }

  void _updatePatternResult(SignalRecord record, bool isWin, double pnl) {
    final stat = _patternStats[record.patternKey];
    if (stat == null) return;

    stat.total++;
    if (isWin) {
      stat.wins++;
      stat.avgWin = (stat.avgWin * (stat.wins - 1) + pnl.abs()) / stat.wins;
    } else {
      stat.losses++;
      stat.avgLoss = (stat.avgLoss * (stat.losses - 1) + pnl.abs()) / stat.losses;
    }

    _updateWeights();
  }

  void _updateWeights() {
    _patternWeights.clear();
    for (final entry in _patternStats.entries) {
      final stat = entry.value;
      if (stat.total < 3) {
        _patternWeights[entry.key] = 1.0;
        continue;
      }
      final sampleFactor = stat.total >= 10 ? 1.0 : stat.total / 10;
      final weight = stat.winRate * (stat.expectancy > 0 ? stat.expectancy.abs() + 0.5 : 0.3) * sampleFactor;
      _patternWeights[entry.key] = weight.clamp(0.1, 2.0);
    }
  }

  /// 判断是否应该过滤该信号（基于历史胜率）
  bool shouldFilter({
    required String regime,
    required int mtfResonance,
    required int confidenceScore,
    required Map<String, bool> gates,
  }) {
    // 构建临时patternKey
    final passedGates = gates.entries.where((e) => e.value).map((e) => e.key).toList()..sort();
    final direction = gates.containsKey('G1_position') ? 'long' : 'short';
    final key = '${regime}_${direction}_r${mtfResonance}_${passedGates.join(",")}';

    final stat = _patternStats[key];
    if (stat == null || stat.total < 5) return false; // 样本不足不过滤
    return stat.winRate < 0.3; // 胜率低于30%过滤
  }

  /// 获取模式权重
  double getPatternWeight(String patternKey) => _patternWeights[patternKey] ?? 1.0;

  /// 整体胜率
  double get overallWinRate => totalSignals > 0 ? totalWins / totalSignals : 0;

  /// 最佳模式TOP3
  List<PatternStat> getBestPatterns() {
    final list = _patternStats.values.where((s) => s.total >= 3).toList();
    list.sort((a, b) => b.expectancy.compareTo(a.expectancy));
    return list.take(3).toList();
  }

  /// 最差模式TOP3
  List<PatternStat> getWorstPatterns() {
    final list = _patternStats.values.where((s) => s.total >= 3).toList();
    list.sort((a, b) => a.expectancy.compareTo(b.expectancy));
    return list.take(3).toList();
  }

  /// 序列化
  String serialize() {
    return jsonEncode({
      'totalSignals': totalSignals,
      'totalWins': totalWins,
      'records': _records.values.map((r) => r.toJson()).toList(),
    });
  }

  /// 反序列化
  void deserialize(String data) {
    try {
      final json = jsonDecode(data);
      totalSignals = json['totalSignals'] ?? 0;
      totalWins = json['totalWins'] ?? 0;
      _records.clear();
      for (final r in json['records'] ?? []) {
        // 简化处理，只恢复统计
      }
    } catch (_) {}
  }
}
