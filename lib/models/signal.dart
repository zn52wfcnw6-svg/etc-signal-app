import '../utils/constants.dart';

/// 交易信号模型
class TradingSignal {
  final String id;
  final SignalDirection direction;
  final SignalStatus status;
  final int createdAt;
  final int confirmedAt;
  final int expiresAt;

  // 价格点位
  final double entryLower;
  final double entryUpper;
  final double stopLoss;
  final double tp1;
  final double tp2;

  // 评分
  final int confidenceScore;
  final Map<String, dynamic> confidenceBreakdown;

  // 确认链状态
  final Map<String, bool> confirmationGates;

  // 市场环境标签
  final String marketRegime; // trend/ranging
  final String volatilityState; // low/normal/high
  final double fundingRateAtSignal;

  // 执行结果（用户标记）
  final bool? userExecuted;
  final double? actualPnl;
  final String? resultNote;

  TradingSignal({
    required this.id,
    required this.direction,
    required this.status,
    required this.createdAt,
    required this.confirmedAt,
    required this.expiresAt,
    required this.entryLower,
    required this.entryUpper,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.confidenceScore,
    required this.confidenceBreakdown,
    required this.confirmationGates,
    required this.marketRegime,
    required this.volatilityState,
    required this.fundingRateAtSignal,
    this.userExecuted,
    this.actualPnl,
    this.resultNote,
  });

  double get riskRewardRatio {
    final risk = (direction == SignalDirection.long)
        ? entryUpper - stopLoss
        : stopLoss - entryLower;
    final reward = (direction == SignalDirection.long)
        ? tp2 - entryLower
        : entryUpper - tp2;
    return risk > 0 ? reward / risk : 0;
  }

  double get entryMid => (entryLower + entryUpper) / 2;

  TradingSignal copyWith({
    SignalStatus? status,
    int? confirmedAt,
    bool? userExecuted,
    double? actualPnl,
    String? resultNote,
  }) {
    return TradingSignal(
      id: id,
      direction: direction,
      status: status ?? this.status,
      createdAt: createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      expiresAt: expiresAt,
      entryLower: entryLower,
      entryUpper: entryUpper,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      confidenceScore: confidenceScore,
      confidenceBreakdown: confidenceBreakdown,
      confirmationGates: confirmationGates,
      marketRegime: marketRegime,
      volatilityState: volatilityState,
      fundingRateAtSignal: fundingRateAtSignal,
      userExecuted: userExecuted ?? this.userExecuted,
      actualPnl: actualPnl ?? this.actualPnl,
      resultNote: resultNote ?? this.resultNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'direction': direction.name,
      'status': status.name,
      'created_at': createdAt,
      'confirmed_at': confirmedAt,
      'expires_at': expiresAt,
      'entry_lower': entryLower,
      'entry_upper': entryUpper,
      'stop_loss': stopLoss,
      'tp1': tp1,
      'tp2': tp2,
      'confidence_score': confidenceScore,
      'confidence_breakdown': confidenceBreakdown.toString(),
      'confirmation_gates': confirmationGates.toString(),
      'market_regime': marketRegime,
      'volatility_state': volatilityState,
      'funding_rate': fundingRateAtSignal,
      'user_executed': userExecuted == null ? null : (userExecuted! ? 1 : 0),
      'actual_pnl': actualPnl,
      'result_note': resultNote,
    };
  }
}
