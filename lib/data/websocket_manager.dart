import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/market_data.dart';
import '../../utils/constants.dart';

/// WebSocket连接状态
enum WsConnectionState { disconnected, connecting, connected, reconnecting }

/// 单交易所WebSocket管理器
class ExchangeWebSocket {
  final String exchange;
  final String symbol;
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  WsConnectionState _state = WsConnectionState.disconnected;
  bool _isDisposed = false;

  final List<Trade> _tradesBuffer = [];
  final StreamController<Trade> _tradeController = StreamController<Trade>.broadcast();
  final StreamController<WsConnectionState> _stateController = StreamController<WsConnectionState>.broadcast();

  Stream<Trade> get tradeStream => _tradeController.stream;
  Stream<WsConnectionState> get stateStream => _stateController.stream;
  WsConnectionState get state => _state;
  List<Trade> get recentTrades => List.unmodifiable(_tradesBuffer);

  ExchangeWebSocket({required this.exchange, required this.symbol});

  String get _wsUrl {
    switch (exchange) {
      case 'binance':
        return 'wss://fstream.binance.com/ws/${symbol.toLowerCase()}@trade';
      case 'okx':
        return 'wss://ws.okx.com:8443/ws/v5/public';
      default:
        return '';
    }
  }

  Future<void> connect() async {
    if (_state == WsConnectionState.connecting || _state == WsConnectionState.connected) return;
    if (_wsUrl.isEmpty) return;

    _setState(WsConnectionState.connecting);
    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      if (exchange == 'okx') {
        // OKX需要订阅
        final instId = '${symbol.substring(0, 3)}-${symbol.substring(3)}-SWAP';
        _channel!.sink.add(json.encode({
          'op': 'subscribe',
          'args': [{'channel': 'trades', 'instId': instId}]
        }));
      }

      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    try {
      final msg = json.decode(data.toString());
      if (exchange == 'binance') {
        final trade = Trade(
          id: msg['t'] is int ? msg['t'] : int.parse(msg['t'].toString()),
          time: msg['T'] is int ? msg['T'] : int.parse(msg['T'].toString()),
          price: double.parse(msg['p'].toString()),
          quantity: double.parse(msg['q'].toString()),
          isBuyerMaker: msg['m'] as bool,
        );
        _addTrade(trade);
      } else if (exchange == 'okx') {
        if (msg['data'] != null) {
          for (final d in msg['data']) {
            final trade = Trade(
              id: int.parse(d['tradeId'].toString()),
              time: int.parse(d['ts'].toString()),
              price: double.parse(d['px'].toString()),
              quantity: double.parse(d['sz'].toString()),
              isBuyerMaker: d['side'] == 'sell',
            );
            _addTrade(trade);
          }
        }
      }
    } catch (_) {}
  }

  void _addTrade(Trade trade) {
    _tradesBuffer.add(trade);
    if (_tradesBuffer.length > 5000) {
      _tradesBuffer.removeRange(0, _tradesBuffer.length - 5000);
    }
    if (!_isDisposed && !_tradeController.isClosed) _tradeController.add(trade);
  }

  void _onError(dynamic error) {
    _scheduleReconnect();
  }

  void _onDone() {
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: AppConstants.websocketHeartbeatSeconds),
      (_) {
        // 检查是否有数据流入
        if (_tradesBuffer.isEmpty ||
            DateTime.now().millisecondsSinceEpoch - _tradesBuffer.last.time > 30000) {
          // 超过30秒无数据，判定为死连接
          disconnect();
          _scheduleReconnect();
        }
      },
    );
  }

  void _scheduleReconnect() {
    if (_state == WsConnectionState.reconnecting) return;
    _setState(WsConnectionState.reconnecting);
    _heartbeatTimer?.cancel();
    _reconnectAttempts++;
    final delays = [1, 2, 4, 8, 16, 30];
    final idx = (_reconnectAttempts - 1).clamp(0, delays.length - 1);
    final delay = Duration(seconds: delays[idx]);
    _reconnectTimer = Timer(delay, connect);
  }

  void _setState(WsConnectionState s) {
    _state = s;
    if (!_isDisposed && !_stateController.isClosed) _stateController.add(s);
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  /// 获取指定时间范围内的逐笔数据
  List<Trade> getTradesSince(int timestamp) {
    return _tradesBuffer.where((t) => t.time >= timestamp).toList();
  }

  /// 清空缓冲（用于K线聚合后）
  void clearTradesBefore(int timestamp) {
    _tradesBuffer.removeWhere((t) => t.time < timestamp);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    if (!_tradeController.isClosed) _tradeController.close();
    if (!_stateController.isClosed) _stateController.close();
  }
}

/// 订单流管理器：聚合多交易所逐笔数据，计算CVD/Delta
class OrderFlowManager {
  final Map<String, ExchangeWebSocket> _sockets = {};
  final Map<String, List<OrderFlowBar>> _orderFlowBars = {};
  double _cumulativeCVD = 0;
  final StreamController<OrderFlowBar> _barController = StreamController<OrderFlowBar>.broadcast();
  Timer? _barAggregatorTimer;
  bool _isDisposed = false;

  Stream<OrderFlowBar> get barStream => _barController.stream;
  double get cumulativeCVD => _cumulativeCVD;
  List<OrderFlowBar> get orderFlowBars => List.unmodifiable(_orderFlowBars['ETH'] ?? []);

  Future<void> init() async {
    for (final ex in AppConstants.orderFlowExchanges) {
      try {
        final ws = ExchangeWebSocket(exchange: ex, symbol: AppConstants.ethSymbol);
        _sockets[ex] = ws;
        ws.tradeStream.listen((_) => _onTrade(), onError: (_) {});
        // 给WebSocket连接添加超时，避免卡住初始化
        await ws.connect().timeout(const Duration(seconds: 3), onTimeout: () {});
      } catch (_) {
        // 单个交易所连接失败不影响其他交易所
      }
    }
    _startBarAggregator();
  }

  void _onTrade() {
    // 实时更新CVD
    double totalDelta = 0;
    for (final ws in _sockets.values) {
      final trades = ws.recentTrades;
      if (trades.isNotEmpty) {
        totalDelta += trades.last.signedVolume;
      }
    }
    _cumulativeCVD += totalDelta;
  }

  void _startBarAggregator() {
    Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      // 10秒bar时间对齐
      final tenSecondStart = (now.millisecondsSinceEpoch ~/ 10000) * 10000;

      double buyVol = 0, sellVol = 0;
      for (final ws in _sockets.values) {
        final trades = ws.getTradesSince(tenSecondStart);
        for (final t in trades) {
          if (t.isBuyerMaker) sellVol += t.quantity;
          else buyVol += t.quantity;
        }
        ws.clearTradesBefore(tenSecondStart);
      }

      final bar = OrderFlowBar(
        time: tenSecondStart,
        cvd: _cumulativeCVD,
        buyVolume: buyVol,
        sellVolume: sellVol,
      );

      _orderFlowBars.putIfAbsent('ETH', () => []).add(bar);
      if ((_orderFlowBars['ETH']?.length ?? 0) > 1440) {
        _orderFlowBars['ETH']!.removeAt(0);
      }
      _barController.add(bar);
    });
  }

  /// 获取最近N根订单流bar
  List<OrderFlowBar> getRecentBars(int count) {
    final bars = _orderFlowBars['ETH'] ?? [];
    return bars.length > count ? bars.sublist(bars.length - count) : bars;
  }

  /// 获取WebSocket连接状态
  Map<String, WsConnectionState> get connectionStates {
    final states = <String, WsConnectionState>{};
    _sockets.forEach((ex, ws) {
      states[ex] = ws.state;
    });
    return states;
  }

  /// 是否有至少一个WebSocket已连接
  bool get isConnected {
    return _sockets.values.any((ws) => ws.state == WsConnectionState.connected);
  }

  /// CVD底背离检测
  bool checkCVDBullishDivergence(List<Kline> klines) {
    final bars = getRecentBars(30);
    if (bars.length < 10 || klines.length < 10) return false;

    // 找最近两个价格低点
    final recentKlines = klines.sublist(klines.length - 30 > 0 ? klines.length - 30 : 0);
    final lows = <int>[];
    for (int i = 2; i < recentKlines.length - 2; i++) {
      if (recentKlines[i].low < recentKlines[i - 1].low &&
          recentKlines[i].low < recentKlines[i - 2].low &&
          recentKlines[i].low < recentKlines[i + 1].low &&
          recentKlines[i].low < recentKlines[i + 2].low) {
        lows.add(i);
      }
    }
    if (lows.length < 2) return false;

    final low1Idx = lows[lows.length - 2];
    final low2Idx = lows.last;
    final priceLowerLow = recentKlines[low2Idx].low < recentKlines[low1Idx].low;

    // 对应时间的CVD
    final time1 = recentKlines[low1Idx].closeTime;
    final time2 = recentKlines[low2Idx].closeTime;
    final cvd1 = bars.where((b) => b.time <= time1).isNotEmpty
        ? bars.where((b) => b.time <= time1).last.cvd
        : bars.first.cvd;
    final cvd2 = bars.where((b) => b.time <= time2).isNotEmpty
        ? bars.where((b) => b.time <= time2).last.cvd
        : bars.last.cvd;

    return priceLowerLow && cvd2 > cvd1 * AppConstants.cvdDivergenceThreshold;
  }

  /// CVD顶背离检测
  bool checkCVDBearishDivergence(List<Kline> klines) {
    final bars = getRecentBars(30);
    if (bars.length < 10 || klines.length < 10) return false;

    final recentKlines = klines.sublist(klines.length - 30 > 0 ? klines.length - 30 : 0);
    final highs = <int>[];
    for (int i = 2; i < recentKlines.length - 2; i++) {
      if (recentKlines[i].high > recentKlines[i - 1].high &&
          recentKlines[i].high > recentKlines[i - 2].high &&
          recentKlines[i].high > recentKlines[i + 1].high &&
          recentKlines[i].high > recentKlines[i + 2].high) {
        highs.add(i);
      }
    }
    if (highs.length < 2) return false;

    final high1Idx = highs[highs.length - 2];
    final high2Idx = highs.last;
    final priceHigherHigh = recentKlines[high2Idx].high > recentKlines[high1Idx].high;

    final time1 = recentKlines[high1Idx].closeTime;
    final time2 = recentKlines[high2Idx].closeTime;
    final cvd1 = bars.where((b) => b.time <= time1).isNotEmpty
        ? bars.where((b) => b.time <= time1).last.cvd
        : bars.first.cvd;
    final cvd2 = bars.where((b) => b.time <= time2).isNotEmpty
        ? bars.where((b) => b.time <= time2).last.cvd
        : bars.last.cvd;

    return priceHigherHigh && cvd2 < cvd1 * (2 - AppConstants.cvdDivergenceThreshold);
  }

  /// Delta反转检测（卖盘衰竭）
  bool checkDeltaReversal(List<Kline> klines, {required bool bullish}) {
    final bars = getRecentBars(10);
    if (bars.length < 5) return false;

    if (bullish) {
      // 卖盘峰值后回落50%，连续3根买量递增
      final sellVols = bars.map((b) => b.sellVolume).toList();
      final peakSell = sellVols.sublist(0, sellVols.length - 3).reduce((a, b) => a > b ? a : b);
      final currentSell = sellVols.last;
      final sellDropped = currentSell < peakSell * AppConstants.deltaReversalDropRatio;

      final buyVols = bars.sublist(bars.length - 3).map((b) => b.buyVolume).toList();
      final buyIncreasing = buyVols[0] < buyVols[1] && buyVols[1] < buyVols[2];

      return sellDropped && buyIncreasing;
    } else {
      final buyVols = bars.map((b) => b.buyVolume).toList();
      final peakBuy = buyVols.sublist(0, buyVols.length - 3).reduce((a, b) => a > b ? a : b);
      final currentBuy = buyVols.last;
      final buyDropped = currentBuy < peakBuy * AppConstants.deltaReversalDropRatio;

      final sellVols = bars.sublist(bars.length - 3).map((b) => b.sellVolume).toList();
      final sellIncreasing = sellVols[0] < sellVols[1] && sellVols[1] < sellVols[2];

      return buyDropped && sellIncreasing;
    }
  }

  void dispose() {
    _isDisposed = true;
    _barAggregatorTimer?.cancel();
    _barAggregatorTimer = null;
    for (final ws in _sockets.values) {
      ws.dispose();
    }
    if (!_barController.isClosed) {
      _barController.close();
    }
  }
}
