/// 交易对配置
class TradingPair {
  final String symbol; // 交易所symbol，如 ETHUSDT
  final String displayName; // 显示名称，如 ETH/USDT
  final String baseAsset; // 基础资产，如 ETH
  final String quoteAsset; // 计价资产，如 USDT
  final double pricePrecision; // 价格精度
  final double qtyPrecision; // 数量精度

  const TradingPair({
    required this.symbol,
    required this.displayName,
    required this.baseAsset,
    required this.quoteAsset,
    required this.pricePrecision,
    required this.qtyPrecision,
  });

  /// 支持的交易对列表
  static const List<TradingPair> supportedPairs = [
    TradingPair(
      symbol: 'ETHUSDT',
      displayName: 'ETH/USDT',
      baseAsset: 'ETH',
      quoteAsset: 'USDT',
      pricePrecision: 1,
      qtyPrecision: 4,
    ),
    TradingPair(
      symbol: 'BTCUSDT',
      displayName: 'BTC/USDT',
      baseAsset: 'BTC',
      quoteAsset: 'USDT',
      pricePrecision: 0,
      qtyPrecision: 6,
    ),
    TradingPair(
      symbol: 'SOLUSDT',
      displayName: 'SOL/USDT',
      baseAsset: 'SOL',
      quoteAsset: 'USDT',
      pricePrecision: 2,
      qtyPrecision: 3,
    ),
  ];

  /// 根据symbol获取交易对
  static TradingPair fromSymbol(String symbol) {
    return supportedPairs.firstWhere(
      (p) => p.symbol == symbol,
      orElse: () => supportedPairs.first,
    );
  }
}
