import 'dart:collection';
import '../models/market_data.dart';

/// 信号状态枚举
enum SignalLifecycleState {
  newlyGenerated, // 新生成
  candidate, // 候选信号
  confirmed, // 确认信号
  triggered, // 已触发（价格到达入场区）
  closed, // 已平仓
  expired, // 已失效
}

/// 信号生命周期记录
class SignalLifecycleRecord {
  final String id; // 唯一ID
  final String direction; // 'long' or 'short'
  final double entryLower; // 入场区间下限
  final double entryUpper; // 入场区间上限
  final double stopLoss; // 止损
  final double tp1; // 止盈1
  final double tp2; // 止盈2
  final DateTime generatedAt; // 生成时间
  DateTime? confirmedAt; // 确认时间
  DateTime? firstTriggeredAt; // 首次触发时间
  DateTime? closedAt; // 平仓时间
  DateTime? expiredAt; // 失效时间
  SignalLifecycleState state; // 当前状态
  int triggerCount; // 触发次数（价格进入入场区的次数）
  Duration totalTriggerDuration; // 累计触发停留时间
  DateTime? lastTriggerEnterAt; // 最近一次进入入场区的时间
  double? exitPrice; // 平仓价格
  double? pnlPercent; // 盈亏百分比
  double sssScore; // SSS综合评分
  List<TriggerEvent> triggerEvents; // 触发事件记录

  SignalLifecycleRecord({
    required this.id,
    required this.direction,
    required this.entryLower,
    required this.entryUpper,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.generatedAt,
    this.state = SignalLifecycleState.newlyGenerated,
    this.triggerCount = 0,
    this.totalTriggerDuration = Duration.zero,
    this.sssScore = 0,
    List<TriggerEvent>? triggerEvents,
  }) : triggerEvents = triggerEvents ?? [];

  /// 入场区间中点
  double get entryMid => (entryLower + entryUpper) / 2;

  /// 信号持续时间
  Duration get duration {
    final end = closedAt ?? expiredAt ?? DateTime.now();
    return end.difference(generatedAt);
  }

  /// 状态文本
  String get stateText {
    switch (state) {
      case SignalLifecycleState.newlyGenerated:
        return '新生成';
      case SignalLifecycleState.candidate:
        return '候选信号';
      case SignalLifecycleState.confirmed:
        return '已确认';
      case SignalLifecycleState.triggered:
        return '已触发';
      case SignalLifecycleState.closed:
        return '已平仓';
      case SignalLifecycleState.expired:
        return '已失效';
    }
  }

  /// 是否活跃（未平仓未失效）
  bool get isActive =>
      state != SignalLifecycleState.closed &&
      state != SignalLifecycleState.expired;
}

/// 触发事件记录
class TriggerEvent {
  final DateTime enterAt; // 进入时间
  final DateTime? exitAt; // 离开时间
  final double enterPrice; // 进入时价格
  final double? exitPrice; // 离开时价格

  TriggerEvent({
    required this.enterAt,
    this.exitAt,
    required this.enterPrice,
    this.exitPrice,
  });

  Duration get duration =>
      exitAt?.difference(enterAt) ?? Duration.zero;
}

/// 信号生命周期管理器
class SignalLifecycleManager {
  final Map<String, SignalLifecycleRecord> _signals = {};
  final Queue<SignalLifecycleRecord> _history = Queue();
  static const int _maxHistorySize = 500;

  /// 获取所有活跃信号
  List<SignalLifecycleRecord> get activeSignals =>
      _signals.values.where((s) => s.isActive).toList();

  /// 获取所有历史信号
  List<SignalLifecycleRecord> get historySignals => _history.toList();

  /// 获取当前活跃信号（如果有）
  SignalLifecycleRecord? get currentActiveSignal {
    final active = activeSignals;
    return active.isNotEmpty ? active.first : null;
  }

  /// 生成新信号（带重复识别）
  SignalLifecycleRecord? generateSignal({
    required String direction,
    required double entryLower,
    required double entryUpper,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required double sssScore,
  }) {
    // 重复识别：检查是否有相似的活跃信号
    final existing = _findSimilarSignal(
      direction: direction,
      entryLower: entryLower,
      entryUpper: entryUpper,
    );

    if (existing != null) {
      // 同一个信号的延续，更新评分，不生成新信号
      existing.sssScore = sssScore;
      return existing;
    }

    // 生成新信号
    final id = _generateId();
    final signal = SignalLifecycleRecord(
      id: id,
      direction: direction,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      generatedAt: DateTime.now(),
      sssScore: sssScore,
    );

    _signals[id] = signal;
    return signal;
  }

  /// 更新信号状态（基于价格和时间）
  void updateSignals({
    required double currentPrice,
    required DateTime currentTime,
  }) {
    final toRemove = <String>[];

    for (final signal in _signals.values) {
      if (!signal.isActive) continue;

      // 1. 状态流转：新生成 → 候选 → 确认
      final age = currentTime.difference(signal.generatedAt);
      if (signal.state == SignalLifecycleState.newlyGenerated &&
          age.inSeconds >= 8) {
        signal.state = SignalLifecycleState.candidate;
      }
      if (signal.state == SignalLifecycleState.candidate &&
          age.inSeconds >= 24) {
        // 连续3次轮询（8秒×3=24秒）后确认
        signal.state = SignalLifecycleState.confirmed;
        signal.confirmedAt = currentTime;
      }

      // 2. 触达检测：价格是否进入入场区
      final inEntryZone = currentPrice >= signal.entryLower &&
          currentPrice <= signal.entryUpper;

      if (inEntryZone && signal.state != SignalLifecycleState.triggered) {
        // 首次进入入场区
        signal.state = SignalLifecycleState.triggered;
        signal.triggerCount++;
        signal.firstTriggeredAt ??= currentTime;
        signal.lastTriggerEnterAt = currentTime;
        signal.triggerEvents.add(TriggerEvent(
          enterAt: currentTime,
          enterPrice: currentPrice,
        ));
      } else if (!inEntryZone &&
          signal.state == SignalLifecycleState.triggered &&
          signal.lastTriggerEnterAt != null) {
        // 离开入场区，更新累计停留时间
        final event = signal.triggerEvents.last;
        if (event.exitAt == null) {
          event.exitAt = currentTime;
          event.exitPrice = currentPrice;
          signal.totalTriggerDuration += event.duration;
        }
        // 回到确认状态，等待再次触发
        signal.state = SignalLifecycleState.confirmed;
      }

      // 3. 平仓检测：价格到达止盈或止损
      if (signal.state == SignalLifecycleState.triggered ||
          signal.state == SignalLifecycleState.confirmed) {
        if (signal.direction == 'long') {
          if (currentPrice <= signal.stopLoss) {
            _closeSignal(signal, currentPrice, currentTime, isWin: false);
          } else if (currentPrice >= signal.tp2) {
            _closeSignal(signal, currentPrice, currentTime, isWin: true);
          }
        } else {
          if (currentPrice >= signal.stopLoss) {
            _closeSignal(signal, currentPrice, currentTime, isWin: false);
          } else if (currentPrice <= signal.tp2) {
            _closeSignal(signal, currentPrice, currentTime, isWin: true);
          }
        }
      }

      // 4. 失效检测：信号超过30分钟未触发，或价格远离入场区超过2%
      if (signal.state != SignalLifecycleState.triggered) {
        if (age.inMinutes > 30) {
          signal.state = SignalLifecycleState.expired;
          signal.expiredAt = currentTime;
          _moveToHistory(signal);
          toRemove.add(signal.id);
        }
        final distancePercent =
            (currentPrice - signal.entryMid).abs() / signal.entryMid * 100;
        if (distancePercent > 3 && age.inMinutes > 10) {
          signal.state = SignalLifecycleState.expired;
          signal.expiredAt = currentTime;
          _moveToHistory(signal);
          toRemove.add(signal.id);
        }
      }
    }

    // 移除已平仓/失效的信号
    for (final id in toRemove) {
      _signals.remove(id);
    }
  }

  /// 平仓信号
  void _closeSignal(
    SignalLifecycleRecord signal,
    double exitPrice,
    DateTime closeTime, {
    required bool isWin,
  }) {
    signal.state = SignalLifecycleState.closed;
    signal.closedAt = closeTime;
    signal.exitPrice = exitPrice;

    // 计算盈亏
    if (signal.direction == 'long') {
      signal.pnlPercent =
          ((exitPrice - signal.entryMid) / signal.entryMid) * 100;
    } else {
      signal.pnlPercent =
          ((signal.entryMid - exitPrice) / signal.entryMid) * 100;
    }

    // 更新最后一个触发事件的离开时间
    if (signal.triggerEvents.isNotEmpty &&
        signal.triggerEvents.last.exitAt == null) {
      signal.triggerEvents.last.exitAt = closeTime;
      signal.triggerEvents.last.exitPrice = exitPrice;
      signal.totalTriggerDuration += signal.triggerEvents.last.duration;
    }

    _moveToHistory(signal);
    _signals.remove(signal.id);
  }

  /// 移动到历史记录
  void _moveToHistory(SignalLifecycleRecord signal) {
    _history.addFirst(signal);
    if (_history.length > _maxHistorySize) {
      _history.removeLast();
    }
  }

  /// 查找相似信号（重复识别）
  SignalLifecycleRecord? _findSimilarSignal({
    required String direction,
    required double entryLower,
    required double entryUpper,
  }) {
    final entryMid = (entryLower + entryUpper) / 2;
    for (final signal in _signals.values) {
      if (!signal.isActive) continue;
      if (signal.direction != direction) continue;

      // 入场区间重叠度>70%视为同一个信号
      final overlap = _calculateOverlap(
        entryLower,
        entryUpper,
        signal.entryLower,
        signal.entryUpper,
      );
      if (overlap > 0.7) return signal;

      // 入场中点距离<1%也视为同一个信号
      final distance =
          (entryMid - signal.entryMid).abs() / signal.entryMid * 100;
      if (distance < 1) return signal;
    }
    return null;
  }

  /// 计算两个区间的重叠度
  double _calculateOverlap(
    double a1,
    double a2,
    double b1,
    double b2,
  ) {
    final overlapStart = a1 > b1 ? a1 : b1;
    final overlapEnd = a2 < b2 ? a2 : b2;
    if (overlapStart >= overlapEnd) return 0;
    final overlapLength = overlapEnd - overlapStart;
    final totalLength = (a2 - a1) + (b2 - b1) - overlapLength;
    return totalLength > 0 ? overlapLength / totalLength : 0;
  }

  /// 生成信号ID
  String _generateId() {
    final now = DateTime.now();
    return 'SIG-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${_signals.length + 1}';
  }

  /// 获取历史统计
  SignalHistoryStats getHistoryStats() {
    final closed = _history
        .where((s) => s.state == SignalLifecycleState.closed)
        .toList();
    if (closed.isEmpty) {
      return SignalHistoryStats(
        totalSignals: 0,
        winRate: 0,
        avgPnl: 0,
        maxDrawdown: 0,
        currentStreak: 0,
        maxWinStreak: 0,
        maxLossStreak: 0,
      );
    }

    final wins = closed.where((s) => (s.pnlPercent ?? 0) > 0).toList();
    final losses = closed.where((s) => (s.pnlPercent ?? 0) <= 0).toList();
    final winRate = wins.length / closed.length * 100;
    final avgPnl =
        closed.map((s) => s.pnlPercent ?? 0).reduce((a, b) => a + b) /
            closed.length;

    // 计算最大回撤
    double peak = 0;
    double maxDrawdown = 0;
    double cumulative = 0;
    for (final s in closed.reversed) {
      cumulative += s.pnlPercent ?? 0;
      if (cumulative > peak) peak = cumulative;
      final drawdown = peak - cumulative;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }

    // 计算连续盈亏
    int currentStreak = 0;
    int maxWinStreak = 0;
    int maxLossStreak = 0;
    int tempWin = 0;
    int tempLoss = 0;
    for (final s in closed.reversed) {
      if ((s.pnlPercent ?? 0) > 0) {
        tempWin++;
        tempLoss = 0;
        if (tempWin > maxWinStreak) maxWinStreak = tempWin;
      } else {
        tempLoss++;
        tempWin = 0;
        if (tempLoss > maxLossStreak) maxLossStreak = tempLoss;
      }
    }
    currentStreak = tempWin > 0 ? tempWin : -tempLoss;

    return SignalHistoryStats(
      totalSignals: closed.length,
      winRate: winRate,
      avgPnl: avgPnl,
      maxDrawdown: maxDrawdown,
      currentStreak: currentStreak,
      maxWinStreak: maxWinStreak,
      maxLossStreak: maxLossStreak,
    );
  }

  /// 清空所有数据
  void clear() {
    _signals.clear();
    _history.clear();
  }
}

/// 信号历史统计
class SignalHistoryStats {
  final int totalSignals;
  final double winRate;
  final double avgPnl;
  final double maxDrawdown;
  final int currentStreak; // 正数=连续盈利，负数=连续亏损
  final int maxWinStreak;
  final int maxLossStreak;

  SignalHistoryStats({
    required this.totalSignals,
    required this.winRate,
    required this.avgPnl,
    required this.maxDrawdown,
    required this.currentStreak,
    required this.maxWinStreak,
    required this.maxLossStreak,
  });

  String get winRateText => '${winRate.toStringAsFixed(1)}%';
  String get avgPnlText =>
      '${avgPnl >= 0 ? '+' : ''}${avgPnl.toStringAsFixed(2)}%';
  String get currentStreakText => currentStreak >= 0
      ? '连盈$currentStreak次'
      : '连亏${currentStreak.abs()}次';
}
