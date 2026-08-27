/// K线数据模型
class Kline {
  final int openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final int closeTime;

  Kline({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
  });

  factory Kline.fromJson(List<dynamic> json) {
    return Kline(
      openTime: json[0] is int ? json[0] : int.parse(json[0].toString()),
      open: double.parse(json[1].toString()),
      high: double.parse(json[2].toString()),
      low: double.parse(json[3].toString()),
      close: double.parse(json[4].toString()),
      volume: double.parse(json[5].toString()),
      closeTime: json[6] is int ? json[6] : int.parse(json[6].toString()),
    );
  }

  double get bodySize => (close - open).abs();
  double get upperWick => high - (close > open ? close : open);
  double get lowerWick => (close > open ? open : close) - low;
  bool get isBullish => close >= open;
  bool get isBearish => close < open;

  bool isPinBar({double ratio = 2.0}) {
    if (bodySize == 0) return false;
    return lowerWick > bodySize * ratio || upperWick > bodySize * ratio;
  }

  bool isBullishEngulfing(Kline prev) {
    return prev.isBearish &&
        isBullish &&
        close > prev.open &&
        open < prev.close;
  }

  bool isBearishEngulfing(Kline prev) {
    return prev.isBullish &&
        isBearish &&
        close < prev.open &&
        open > prev.close;
  }
}

/// 逐笔成交数据
class Trade {
  final int id;
  final int time;
  final double price;
  final double quantity;
  final bool isBuyerMaker; // true=主动卖, false=主动买

  Trade({
    required this.id,
    required this.time,
    required this.price,
    required this.quantity,
    required this.isBuyerMaker,
  });

  double get signedVolume => isBuyerMaker ? -quantity : quantity;
}

/// 订单流聚合数据（1分钟）
class OrderFlowBar {
  final int time;
  final double cvd; // 累计成交量增量
  final double buyVolume;
  final double sellVolume;
  final double delta; // buyVolume - sellVolume

  OrderFlowBar({
    required this.time,
    required this.cvd,
    required this.buyVolume,
    required this.sellVolume,
  }) : delta = buyVolume - sellVolume;
}

/// 交易所行情快照
class MarketSnapshot {
  final String exchange;
  final String symbol;
  final double price;
  final double markPrice;
  final double fundingRate;
  final double openInterest;
  final int timestamp;

  MarketSnapshot({
    required this.exchange,
    required this.symbol,
    required this.price,
    this.markPrice = 0,
    this.fundingRate = 0,
    this.openInterest = 0,
    required this.timestamp,
  });
}

/// 校验后的基准行情
class ValidatedMarketData {
  final double price;
  final double fundingRate;
  final double openInterest;
  final List<String> validSources;
  final List<String> excludedSources;
  final bool isDegraded;
  final int timestamp;

  ValidatedMarketData({
    required this.price,
    required this.fundingRate,
    required this.openInterest,
    required this.validSources,
    required this.excludedSources,
    required this.isDegraded,
    required this.timestamp,
  });
}

/// 摆动点
class SwingPoint {
  final int index;
  final int time;
  final double price;
  final bool isHigh;

  SwingPoint({
    required this.index,
    required this.time,
    required this.price,
    required this.isHigh,
  });
}

/// 关键价位
class KeyLevel {
  final double lower;
  final double upper;
  final double mid;
  final int strength; // 1-3
  final String type; // 'support' or 'resistance'
  final bool hasLiquidityPool;
  final bool hasVPVR;
  final bool hasSwing;

  KeyLevel({
    required this.lower,
    required this.upper,
    required this.mid,
    required this.strength,
    required this.type,
    this.hasLiquidityPool = false,
    this.hasVPVR = false,
    this.hasSwing = false,
  });

  bool contains(double price) => price >= lower && price <= upper;
}
