import '../utils/constants.dart';

/// 持仓模型
class Position {
  final String id;
  final String? signalId;
  final SignalDirection direction;
  final double entryPrice;
  final double quantity;
  final double stopLoss;
  final double tp1;
  final double tp2;
  final int openedAt;
  final int? closedAt;
  final double? closePrice;
  final bool isClosed;
  final double? realizedPnl;
  final int batchNumber; // 分批建仓批次号

  Position({
    required this.id,
    this.signalId,
    required this.direction,
    required this.entryPrice,
    required this.quantity,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.openedAt,
    this.closedAt,
    this.closePrice,
    this.isClosed = false,
    this.realizedPnl,
    this.batchNumber = 1,
  });

  /// 单笔风险金额
  double get riskAmount {
    final priceDiff = (direction == SignalDirection.long)
        ? entryPrice - stopLoss
        : stopLoss - entryPrice;
    return priceDiff * quantity;
  }

  /// 当前浮盈浮亏
  double unrealizedPnl(double currentPrice) {
    final diff = (direction == SignalDirection.long)
        ? currentPrice - entryPrice
        : entryPrice - currentPrice;
    return diff * quantity;
  }

  /// 风险回报率（基于当前价）
  double currentRiskReward(double currentPrice) {
    final risk = (direction == SignalDirection.long)
        ? entryPrice - stopLoss
        : stopLoss - entryPrice;
    final reward = (direction == SignalDirection.long)
        ? tp2 - currentPrice
        : currentPrice - tp2;
    return risk > 0 ? reward / risk : 0;
  }

  /// 是否触及TP1
  bool shouldTakeProfit1(double currentPrice) {
    if (isClosed) return false;
    return (direction == SignalDirection.long)
        ? currentPrice >= tp1
        : currentPrice <= tp1;
  }

  /// 是否触及TP2
  bool shouldTakeProfit2(double currentPrice) {
    if (isClosed) return false;
    return (direction == SignalDirection.long)
        ? currentPrice >= tp2
        : currentPrice <= tp2;
  }

  /// 是否触及止损
  bool shouldStopLoss(double currentPrice) {
    if (isClosed) return false;
    return (direction == SignalDirection.long)
        ? currentPrice <= stopLoss
        : currentPrice >= stopLoss;
  }

  Position copyWith({
    double? stopLoss,
    bool? isClosed,
    int? closedAt,
    double? closePrice,
    double? realizedPnl,
    double? quantity,
  }) {
    return Position(
      id: id,
      signalId: signalId,
      direction: direction,
      entryPrice: entryPrice,
      quantity: quantity ?? this.quantity,
      stopLoss: stopLoss ?? this.stopLoss,
      tp1: tp1,
      tp2: tp2,
      openedAt: openedAt,
      closedAt: closedAt ?? this.closedAt,
      closePrice: closePrice ?? this.closePrice,
      isClosed: isClosed ?? this.isClosed,
      realizedPnl: realizedPnl ?? this.realizedPnl,
      batchNumber: batchNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'signal_id': signalId,
      'direction': direction.name,
      'entry_price': entryPrice,
      'quantity': quantity,
      'stop_loss': stopLoss,
      'tp1': tp1,
      'tp2': tp2,
      'opened_at': openedAt,
      'closed_at': closedAt,
      'close_price': closePrice,
      'is_closed': isClosed ? 1 : 0,
      'realized_pnl': realizedPnl,
      'batch_number': batchNumber,
    };
  }
}
