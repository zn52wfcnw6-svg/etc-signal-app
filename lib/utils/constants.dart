/// 系统常量定义
class AppConstants {
  // 行情轮询
  static const int pollIntervalSeconds = 8;
  static const int apiTimeoutSeconds = 3;
  static const int maxApiRetries = 2;

  // 交易所配置
  static const List<String> exchanges = ['okx', 'binance', 'bybit', 'bitget', 'gate'];
  static const List<String> orderFlowExchanges = ['okx', 'binance'];

  // 交易对
  static const String ethSymbol = 'ETHUSDT';
  static const String btcSymbol = 'BTCUSDT';

  // 行情校验
  static const double madThresholdMultiplier = 3.0;
  static const double minAbnormalDeviation = 0.002; // 0.2%
  static const int maxDegradedSources = 1; // 超过1家异常则全屏蔽

  // 冻结条件
  static const double btc5mVolatilityThreshold = 0.018; // 1.8%
  static const double btc15mVolatilityThreshold = 0.03; // 3%
  static const double accountRiskLimit = 0.05; // 5%
  static const double singleTradeRiskLimit = 0.01; // 1%

  // 信号确认
  static const int confirmationPolls = 3;
  static const int signalExpiryMinutes = 15;
  static const int minConfidenceScore = 70;
  static const int lowConfidenceScore = 65;

  // 盈亏比
  static const double minRiskRewardRatio = 3.0;
  static const double targetRiskRewardRatio = 4.0;

  // 交易执行
  static const double tp1ReduceRatio = 0.6; // TP1减仓60%

  // 资金费率
  static const double extremeFundingRate = 0.0005; // 0.05% per 8h
  static const double crowdedFundingRate = 0.0008; // 0.08%

  // 清算挤压代理
  static const double oiDropThreshold = 0.03; // 5m OI降3%
  static const double activeTradeRatioThreshold = 3.0; // 主动买卖比3:1

  // 摆动点确认
  static const int swingLookback = 2; // 左右各2根确认

  // CVD/Delta
  static const double deltaReversalDropRatio = 0.5; // 卖量峰值回落50%
  static const int deltaConsecutiveBars = 3; // 连续3根递增
  static const double cvdDivergenceThreshold = 0.95;

  // K线形态
  static const double pinBarWickRatio = 2.0; // 影线>实体2倍

  // 自动迭代
  static const int iterationMinSignals = 20;
  static const int iterationCooldownDays = 7;
  static const double iterationMaxDrawdownMultiplier = 1.5;
  static const double iterationStatSigPValue = 0.1;

  // 自修复
  static const int maxHealAttempts = 3;
  static const int healthCheckIntervalSeconds = 10;
  static const int websocketHeartbeatSeconds = 10;
  static const int frozenRecheckIntervalSeconds = 10;
  static const int frozenConfirmations = 3; // 连续3次确认解冻

  // 数据库
  static const String dbName = 'eth_signal.db';
  static const int dbVersion = 1;

  // 数据保留
  static const int kline1mRetentionDays = 90;
  static const int kline4hRetentionDays = 730; // 2年
  static const int orderflowRetentionDays = 30;
}

/// 信号方向
enum SignalDirection { long, short }

/// 信号状态
enum SignalStatus { candidate, confirmed, active, expired, invalidated, archived }

/// 市场结构状态
enum MarketStructure { uptrend, downtrend, ranging, reversalPending }

/// 长周期状态
enum LongCycleState { supportValid, resistanceValid, neutral, trendExhaustion }

/// APP状态标签
enum AppStateTag { longCandidate, shortCandidate, marketFrozen, dataAbnormal, noSignal }

/// 冻结原因
enum FreezeReason {
  btcVolatility,
  btcStructureBreak,
  dataValidationFailed,
  accountRiskExceeded,
  liquidationSqueeze,
  none,
}
