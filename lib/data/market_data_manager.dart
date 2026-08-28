import 'dart:async';
import 'apis/exchange_api.dart';
import 'market_validator.dart';
import 'websocket_manager.dart';
import '../models/market_data.dart';
import '../monitor/performance_monitor.dart';
import '../utils/constants.dart';

/// 行情数据管理器：统一调度5家API、交叉校验、K线缓存
class MarketDataManager {
  final Map<String, List<Kline>> _klineCache = {};
  final Map<String, MarketSnapshot?> _lastSnapshots = {};
  ValidatedMarketData? _ethData;
  ValidatedMarketData? _btcData;
  final OrderFlowManager _orderFlowManager = OrderFlowManager();

  final StreamController<ValidatedMarketData> _ethDataController = StreamController.broadcast();
  final StreamController<ValidatedMarketData> _btcDataController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();

  Stream<ValidatedMarketData> get ethDataStream => _ethDataController.stream;
  Stream<ValidatedMarketData> get btcDataStream => _btcDataController.stream;
  Stream<String> get errorStream => _errorController.stream;
  ValidatedMarketData? get ethData => _ethData;
  ValidatedMarketData? get btcData => _btcData;
  OrderFlowManager get orderFlow => _orderFlowManager;

  Timer? _pollTimer;
  bool _isRunning = false;
  bool _isDisposed = false;
  int _pollCount = 0;
  bool _klinesLoaded = false;
  bool get klinesLoaded => _klinesLoaded;
  ValidatedMarketData? _latestEthData;

  Future<void> init() async {
    // 订单流初始化（带超时，不阻塞主流程）
    try {
      await _orderFlowManager.init().timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (_) {}
    // K线预加载改为后台异步，不阻塞初始化
    _preloadKlinesAsync();
  }

  /// 后台异步预加载K线，不阻塞主界面
  Future<void> _preloadKlinesAsync() async {
    try {
      await _preloadKlines().timeout(const Duration(seconds: 45), onTimeout: () {});
      _klinesLoaded = true;
      _notifyKlinesLoaded();
    } catch (_) {
      _klinesLoaded = true; // 即使部分失败也标记为已加载，避免一直等待
    }
  }

  void _notifyKlinesLoaded() {
    // 通知监听器K线已加载
    if (_latestEthData != null && !_ethDataController.isClosed) {
      _ethDataController.add(_latestEthData!);
    }
  }

  Future<void> _preloadKlines() async {
    // 只预加载最关键的周期，并行加载加快速度
    final tasks = [
      ('eth', '1m', 100),
      ('eth', '5m', 100),
      ('eth', '1h', 100),
      ('eth', '4h', 100),
      ('btc', '5m', 100),
      ('btc', '15m', 100),
    ];
    // 并行加载
    await Future.wait(tasks.map((t) async {
      final symbol = t.$1 == 'eth' ? AppConstants.ethSymbol : AppConstants.btcSymbol;
      try {
        await _fetchAndCacheKlines(symbol, t.$2, t.$3).timeout(const Duration(seconds: 15));
      } catch (_) {}
    }));
    // 长周期K线后台异步加载，不阻塞初始化
    _preloadLongCycleKlines();
  }

  Future<void> _preloadLongCycleKlines() async {
    // 后台异步加载长周期K线
    final tasks = [
      ('eth', '1d', 100),
      ('btc', '4h', 100),
    ];
    for (final t in tasks) {
      final symbol = t.$1 == 'eth' ? AppConstants.ethSymbol : AppConstants.btcSymbol;
      try {
        await _fetchAndCacheKlines(symbol, t.$2, t.$3).timeout(const Duration(seconds: 15));
      } catch (_) {}
    }
  }

  /// 检查K线是否充足
  bool _hasEnoughKlines(String symbol, String interval, int minCount) {
    final key = '${symbol}_$interval';
    final cached = _klineCache[key];
    return cached != null && cached.length >= minCount;
  }

  Future<void> _fetchAndCacheKlines(String symbol, String interval, int limit) async {
    final key = '${symbol}_$interval';
    // 遍历所有交易所，直到获取到K线数据
    for (final ex in AppConstants.exchanges) {
      try {
        final api = ExchangeFactory.get(ex);
        final klines = await api.fetchKlines(symbol, interval, limit);
        if (klines.isNotEmpty) {
          _klineCache[key] = klines;
          return;
        }
      } catch (_) {
        // 继续尝试下一个交易所
      }
    }
  }

  void startPolling() {
    if (_isRunning) return;
    _isRunning = true;
    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.pollIntervalSeconds),
      (_) => _poll(),
    );
    _poll(); // 立即执行一次
  }

  Future<void> _poll() async {
    try {
      final ethResult = await _fetchAndValidate(AppConstants.ethSymbol);
      if (ethResult.data != null) {
        _ethData = ethResult.data;
        _latestEthData = ethResult.data;
        _ethDataController.add(ethResult.data!);
      } else if (ethResult.isFailed) {
        _errorController.add('ETH行情校验失败: ${ethResult.reason}');
      }

      final btcResult = await _fetchAndValidate(AppConstants.btcSymbol);
      if (btcResult.data != null) {
        _btcData = btcResult.data;
        _btcDataController.add(btcResult.data!);
      } else if (btcResult.isFailed) {
        _errorController.add('BTC行情校验失败: ${btcResult.reason}');
      }

      // 更新K线缓存
      await _updateKlineCache(AppConstants.ethSymbol, '1m');
      await _updateKlineCache(AppConstants.ethSymbol, '5m');
      await _updateKlineCache(AppConstants.btcSymbol, '5m');
      await _updateKlineCache(AppConstants.btcSymbol, '15m');

      // 长周期K线不足时重新加载（每10次轮询检查一次）
      _pollCount++;
      if (_pollCount % 5 == 0) {
        if (!_hasEnoughKlines(AppConstants.ethSymbol, '4h', 10)) {
          await _fetchAndCacheKlines(AppConstants.ethSymbol, '4h', 100);
        }
        if (!_hasEnoughKlines(AppConstants.ethSymbol, '1d', 10)) {
          await _fetchAndCacheKlines(AppConstants.ethSymbol, '1d', 100);
        }
        if (!_hasEnoughKlines(AppConstants.ethSymbol, '1h', 10)) {
          await _fetchAndCacheKlines(AppConstants.ethSymbol, '1h', 100);
        }
        if (!_hasEnoughKlines(AppConstants.btcSymbol, '4h', 10)) {
          await _fetchAndCacheKlines(AppConstants.btcSymbol, '4h', 100);
        }
      }
    } catch (e) {
      if (!_isDisposed && !_errorController.isClosed) {
        _errorController.add('行情轮询异常: $e');
      }
    }
  }

  Future<ValidationResult> _fetchAndValidate(String symbol) async {
    final snapshots = <MarketSnapshot>[];
    for (final ex in AppConstants.exchanges) {
      try {
        final api = ExchangeFactory.get(ex);
        final ticker = await api.fetchTicker(symbol);
        if (ticker == null || ticker.price <= 0) continue;

        // 资金费率和OI获取失败不影响ticker
        double funding = 0;
        double oi = 0;
        if (AppConstants.orderFlowExchanges.contains(ex)) {
          try {
            funding = (await api.fetchFundingRate(symbol)) ?? 0;
            oi = (await api.fetchOpenInterest(symbol)) ?? 0;
          } catch (_) {}
        }

        snapshots.add(MarketSnapshot(
          exchange: ticker.exchange,
          symbol: ticker.symbol,
          price: ticker.price,
          fundingRate: funding,
          openInterest: oi,
          timestamp: ticker.timestamp,
        ));
      } catch (_) {
        // 继续尝试下一个交易所
      }
    }
    final result = MarketValidator.validate(snapshots);
    // S级容错：校验失败但有数据时，降级使用第一个有效源
    if (result.isFailed && snapshots.isNotEmpty) {
      final fallback = snapshots.first;
      return ValidationResult(
        data: ValidatedMarketData(
          price: fallback.price,
          fundingRate: fallback.fundingRate,
          openInterest: fallback.openInterest,
          validSources: [fallback.exchange],
          excludedSources: const [],
          isDegraded: true,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        abnormalSources: const [],
        reason: '多源校验失败，降级使用${fallback.exchange}单源',
      );
    }
    return result;
  }

  Future<void> _updateKlineCache(String symbol, String interval) async {
    final key = '${symbol}_$interval';
    if (!_klineCache.containsKey(key)) {
      // 缓存不存在，重新预加载
      await _fetchAndCacheKlines(symbol, interval, 100);
      return;
    }
    // 遍历所有交易所获取最新K线
    List<Kline> klines = [];
    for (final ex in AppConstants.exchanges) {
      try {
        final api = ExchangeFactory.get(ex);
        final result = await api.fetchKlines(symbol, interval, 10);
        if (result.isNotEmpty) {
          klines = result;
          break;
        }
      } catch (_) {}
    }
    if (klines.isNotEmpty) {
      final cached = _klineCache[key]!;
      final lastCachedTime = cached.last.closeTime;
      final newKlines = klines.where((k) => k.closeTime > lastCachedTime).toList();
      if (newKlines.isNotEmpty) {
        cached.addAll(newKlines);
        if (cached.length > 500) {
          cached.removeRange(0, cached.length - 500);
        }
      } else if (klines.last.closeTime == cached.last.closeTime) {
        cached[cached.length - 1] = klines.last;
      }
    }
  }

  /// 手动刷新
  Future<void> manualRefresh() async {
    await _poll();
  }

  /// 获取K线缓存
  List<Kline> getKlines(String symbol, String interval) {
    return _klineCache['${symbol}_$interval'] ?? [];
  }

  /// 获取ETH 1m K线
  List<Kline> getEth1m() => getKlines(AppConstants.ethSymbol, '1m');

  /// 获取ETH 5m K线
  List<Kline> getEth5m() => getKlines(AppConstants.ethSymbol, '5m');

  /// 获取ETH 1h K线
  List<Kline> getEth1h() => getKlines(AppConstants.ethSymbol, '1h');

  /// 获取ETH 4h K线
  List<Kline> getEth4h() => getKlines(AppConstants.ethSymbol, '4h');

  /// 获取ETH 1d K线
  List<Kline> getEth1d() => getKlines(AppConstants.ethSymbol, '1d');

  /// 获取BTC 5m K线
  List<Kline> getBtc5m() => getKlines(AppConstants.btcSymbol, '5m');

  /// 获取BTC 15m K线
  List<Kline> getBtc15m() => getKlines(AppConstants.btcSymbol, '15m');

  /// 获取BTC 4h K线
  List<Kline> getBtc4h() => getKlines(AppConstants.btcSymbol, '4h');

  void stopPolling() {
    _isRunning = false;
    _pollTimer?.cancel();
  }

  void dispose() {
    _isDisposed = true;
    stopPolling();
    _orderFlowManager.dispose();
    if (!_ethDataController.isClosed) _ethDataController.close();
    if (!_btcDataController.isClosed) _btcDataController.close();
    if (!_errorController.isClosed) _errorController.close();
  }
}
