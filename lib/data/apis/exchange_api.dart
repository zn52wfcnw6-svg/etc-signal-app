import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../utils/robust_http_client.dart';
import '../../models/market_data.dart';
import '../../utils/constants.dart';

/// CORS代理：Web版通过代理访问交易所API
/// 交易所API基类
abstract class ExchangeApi {
  String get name;
  String get baseUrl;

  Future<MarketSnapshot?> fetchTicker(String symbol);
  Future<List<Kline>> fetchKlines(String symbol, String interval, int limit);
  Future<double?> fetchFundingRate(String symbol);
  Future<double?> fetchOpenInterest(String symbol);
  Future<List<Trade>> fetchRecentTrades(String symbol, int limit);
  Future<List<LiquidationOrder>> fetchLiquidations(String symbol, int limit);
  Future<OrderBookDepth> fetchOrderBookDepth(String symbol, int limit);
}

/// 清算订单
class LiquidationOrder {
  final String symbol;
  final double price;
  final double quantity;
  final String side; // 'buy' or 'sell'
  final int time;
  
  LiquidationOrder({
    required this.symbol,
    required this.price,
    required this.quantity,
    required this.side,
    required this.time,
  });
}

/// 订单簿深度
class OrderBookDepth {
  final List<OrderBookLevel> bids; // 买单
  final List<OrderBookLevel> asks; // 卖单
  final int time;
  
  OrderBookDepth({
    required this.bids,
    required this.asks,
    required this.time,
  });
  
  double get bestBid => bids.isNotEmpty ? bids.first.price : 0;
  double get bestAsk => asks.isNotEmpty ? asks.first.price : 0;
  double get spread => bestAsk - bestBid;
  double get totalBidVolume => bids.fold(0, (sum, b) => sum + b.quantity);
  double get totalAskVolume => asks.fold(0, (sum, a) => sum + a.quantity);
  double get bidAskRatio => totalAskVolume > 0 ? totalBidVolume / totalAskVolume : 1;
}

class OrderBookLevel {
  final double price;
  final double quantity;
  
  OrderBookLevel({required this.price, required this.quantity});
}

/// Binance API
class BinanceApi implements ExchangeApi {
  @override
  String get name => 'binance';
  @override
  String get baseUrl => 'https://fapi.binance.com';

  @override
  Future<MarketSnapshot?> fetchTicker(String symbol) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/ticker/price?symbol=$symbol');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      return MarketSnapshot(
        exchange: name,
        symbol: symbol,
        price: double.parse(data['price'].toString()),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Kline>> fetchKlines(String symbol, String interval, int limit) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/klines?symbol=$symbol&interval=$interval&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final List<dynamic> data = json.decode(resp.body);
      return data.map((e) => Kline.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<double?> fetchFundingRate(String symbol) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/premiumIndex?symbol=$symbol');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      return double.parse(data['lastFundingRate'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> fetchOpenInterest(String symbol) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/openInterest?symbol=$symbol');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      return double.parse(data['openInterest'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Trade>> fetchRecentTrades(String symbol, int limit) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/trades?symbol=$symbol&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final List<dynamic> data = json.decode(resp.body);
      return data.map((e) => Trade(
        id: e['id'] is int ? e['id'] : int.parse(e['id'].toString()),
        time: e['time'] is int ? e['time'] : int.parse(e['time'].toString()),
        price: double.parse(e['price'].toString()),
        quantity: double.parse(e['qty'].toString()),
        isBuyerMaker: e['isBuyerMaker'] as bool,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<LiquidationOrder>> fetchLiquidations(String symbol, int limit) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/forceOrders?symbol=$symbol&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final List<dynamic> data = json.decode(resp.body);
      return data.map((e) => LiquidationOrder(
        symbol: e['symbol'] ?? symbol,
        price: double.parse(e['price']?.toString() ?? '0'),
        quantity: double.parse(e['origQty']?.toString() ?? '0'),
        side: e['side']?.toString().toLowerCase() ?? 'sell',
        time: e['time'] is int ? e['time'] : int.parse(e['time']?.toString() ?? '0'),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<OrderBookDepth> fetchOrderBookDepth(String symbol, int limit) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/fapi/v1/depth?symbol=$symbol&limit=$limit');
      if (resp == null || resp.statusCode != 200) {
        return OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
      }
      final data = json.decode(resp.body);
      final bids = (data['bids'] as List).map((e) => OrderBookLevel(
        price: double.parse(e[0].toString()),
        quantity: double.parse(e[1].toString()),
      )).toList();
      final asks = (data['asks'] as List).map((e) => OrderBookLevel(
        price: double.parse(e[0].toString()),
        quantity: double.parse(e[1].toString()),
      )).toList();
      return OrderBookDepth(
        bids: bids,
        asks: asks,
        time: data['lastUpdateId'] is int ? data['lastUpdateId'] : DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
    }
  }
}

/// OKX API
class OkxApi implements ExchangeApi {
  @override
  String get name => 'okx';
  @override
  String get baseUrl => 'https://www.okx.com';

  String _toOkxSymbol(String symbol) => '${symbol.substring(0, 3)}-${symbol.substring(3)}-SWAP';

  @override
  Future<MarketSnapshot?> fetchTicker(String symbol) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/market/ticker?instId=$instId');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['code'] != '0' || (data['data'] as List).isEmpty) return null;
      final ticker = data['data'][0];
      return MarketSnapshot(
        exchange: name,
        symbol: symbol,
        price: double.parse(ticker['last'].toString()),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Kline>> fetchKlines(String symbol, String interval, int limit) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final bar = _toOkxInterval(interval);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/market/candles?instId=$instId&bar=$bar&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final data = json.decode(resp.body);
      if (data['code'] != '0') return [];
      final List<dynamic> candles = data['data'];
      // OKX返回最新在前，需要反转
      final reversed = candles.reversed.toList();
      return reversed.map((e) => Kline(
        openTime: int.parse(e[0].toString()),
        open: double.parse(e[1].toString()),
        high: double.parse(e[2].toString()),
        low: double.parse(e[3].toString()),
        close: double.parse(e[4].toString()),
        volume: double.parse(e[5].toString()),
        closeTime: int.parse(e[0].toString()) + _intervalMs(bar),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  String _toOkxInterval(String interval) {
    switch (interval) {
      case '1m': return '1m';
      case '5m': return '5m';
      case '15m': return '15m';
      case '1h': return '1H';
      case '4h': return '4H';
      case '1d': return '1Dutc';
      default: return interval;
    }
  }

  int _intervalMs(String bar) {
    switch (bar) {
      case '1m': return 60000;
      case '5m': return 300000;
      case '15m': return 900000;
      case '1H': return 3600000;
      case '4H': return 14400000;
      case '1Dutc': return 86400000;
      default: return 60000;
    }
  }

  @override
  Future<double?> fetchFundingRate(String symbol) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/public/funding-rate?instId=$instId');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['code'] != '0' || (data['data'] as List).isEmpty) return null;
      return double.parse(data['data'][0]['fundingRate'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> fetchOpenInterest(String symbol) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/public/open-interest?instId=$instId');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['code'] != '0' || (data['data'] as List).isEmpty) return null;
      return double.parse(data['data'][0]['oi'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Trade>> fetchRecentTrades(String symbol, int limit) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/market/trades?instId=$instId&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final data = json.decode(resp.body);
      if (data['code'] != '0') return [];
      final List<dynamic> trades = data['data'];
      return trades.map((e) => Trade(
        id: int.parse(e['tradeId'].toString()),
        time: int.parse(e['ts'].toString()),
        price: double.parse(e['px'].toString()),
        quantity: double.parse(e['sz'].toString()),
        isBuyerMaker: e['side'] == 'sell', // OKX: side=taker方向, sell=主动卖
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<LiquidationOrder>> fetchLiquidations(String symbol, int limit) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/public/liquidation-orders?instId=$instId&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final data = json.decode(resp.body);
      if (data['code'] != '0' || (data['data'] as List).isEmpty) return [];
      return (data['data'] as List).map((e) => LiquidationOrder(
        symbol: symbol,
        price: double.parse(e['bkPx']?.toString() ?? '0'),
        quantity: double.parse(e['sz']?.toString() ?? '0'),
        side: e['side']?.toString().toLowerCase() ?? 'sell',
        time: int.parse(e['ts']?.toString() ?? '0'),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<OrderBookDepth> fetchOrderBookDepth(String symbol, int limit) async {
    try {
      final instId = _toOkxSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v5/market/books?instId=$instId&sz=$limit');
      if (resp == null || resp.statusCode != 200) {
        return OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
      }
      final data = json.decode(resp.body);
      if (data['code'] != '0' || (data['data'] as List).isEmpty) {
        return OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
      }
      final book = data['data'][0];
      final bids = (book['bids'] as List).map((e) => OrderBookLevel(
        price: double.parse(e[0].toString()),
        quantity: double.parse(e[1].toString()),
      )).toList();
      final asks = (book['asks'] as List).map((e) => OrderBookLevel(
        price: double.parse(e[0].toString()),
        quantity: double.parse(e[1].toString()),
      )).toList();
      return OrderBookDepth(
        bids: bids,
        asks: asks,
        time: int.parse(book['ts']?.toString() ?? '0'),
      );
    } catch (_) {
      return OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
    }
  }
}

/// Bybit API
class BybitApi implements ExchangeApi {
  @override
  String get name => 'bybit';
  @override
  String get baseUrl => 'https://api.bybit.com';

  @override
  Future<MarketSnapshot?> fetchTicker(String symbol) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/v5/market/tickers?category=linear&symbol=$symbol');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['retCode'] != 0 || (data['result']['list'] as List).isEmpty) return null;
      final ticker = data['result']['list'][0];
      return MarketSnapshot(
        exchange: name,
        symbol: symbol,
        price: double.parse(ticker['lastPrice'].toString()),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Kline>> fetchKlines(String symbol, String interval, int limit) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/v5/market/kline?category=linear&symbol=$symbol&interval=$interval&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final data = json.decode(resp.body);
      if (data['retCode'] != 0) return [];
      final List<dynamic> candles = data['result']['list'];
      final reversed = candles.reversed.toList();
      return reversed.map((e) => Kline(
        openTime: int.parse(e[0].toString()),
        open: double.parse(e[1].toString()),
        high: double.parse(e[2].toString()),
        low: double.parse(e[3].toString()),
        close: double.parse(e[4].toString()),
        volume: double.parse(e[5].toString()),
        closeTime: int.parse(e[0].toString()) + 60000,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<double?> fetchFundingRate(String symbol) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/v5/market/funding/history?category=linear&symbol=$symbol&limit=1');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['retCode'] != 0 || (data['result']['list'] as List).isEmpty) return null;
      return double.parse(data['result']['list'][0]['fundingRate'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> fetchOpenInterest(String symbol) async {
    try {
      final resp = await RobustHttpClient.get('$baseUrl/v5/market/open-interest?category=linear&symbol=$symbol&intervalTime=5min');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['retCode'] != 0 || (data['result']['list'] as List).isEmpty) return null;
      return double.parse(data['result']['list'][0]['openInterest'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Trade>> fetchRecentTrades(String symbol, int limit) async {
    // Bybit逐笔数据质量一般，返回空，订单流只用Binance+OKX
    return [];
  }
}

/// Bitget API
class BitgetApi implements ExchangeApi {
  @override
  String get name => 'bitget';
  @override
  String get baseUrl => 'https://api.bitget.com';

  @override
  Future<MarketSnapshot?> fetchTicker(String symbol) async {
    try {
      final instId = '${symbol.substring(0, 3)}${symbol.substring(3)}_UMCBL';
      final resp = await RobustHttpClient.get('$baseUrl/api/v2/mix/market/ticker?symbol=$instId&productType=umcbl');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['code'] != '00000' || data['data'] == null) return null;
      return MarketSnapshot(
        exchange: name,
        symbol: symbol,
        price: double.parse(data['data']['lastPr'].toString()),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Kline>> fetchKlines(String symbol, String interval, int limit) async {
    try {
      final instId = '${symbol.substring(0, 3)}${symbol.substring(3)}_UMCBL';
      final granularity = _toBitgetInterval(interval);
      final resp = await RobustHttpClient.get('$baseUrl/api/v2/mix/market/candles?symbol=$instId&granularity=$granularity&limit=$limit&productType=umcbl');
      if (resp == null || resp.statusCode != 200) return [];
      final data = json.decode(resp.body);
      if (data['code'] != '00000' || data['data'] == null) return [];
      final List<dynamic> candles = data['data'];
      return candles.map((e) => Kline(
        openTime: int.parse(e[0].toString()),
        open: double.parse(e[1].toString()),
        high: double.parse(e[2].toString()),
        low: double.parse(e[3].toString()),
        close: double.parse(e[4].toString()),
        volume: double.parse(e[5].toString()),
        closeTime: int.parse(e[0].toString()) + 60000,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  String _toBitgetInterval(String interval) {
    switch (interval) {
      case '1m': return '1min';
      case '5m': return '5min';
      case '15m': return '15min';
      case '1h': return '1h';
      case '4h': return '4h';
      case '1d': return '1day';
      default: return interval;
    }
  }

  @override
  Future<double?> fetchFundingRate(String symbol) async {
    try {
      final instId = '${symbol.substring(0, 3)}${symbol.substring(3)}_UMCBL';
      final resp = await RobustHttpClient.get('$baseUrl/api/v2/mix/market/current-fund-rate?symbol=$instId&productType=umcbl');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['code'] != '00000' || data['data'] == null) return null;
      return double.parse(data['data']['fundingRate'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> fetchOpenInterest(String symbol) async {
    try {
      final instId = '${symbol.substring(0, 3)}${symbol.substring(3)}_UMCBL';
      final resp = await RobustHttpClient.get('$baseUrl/api/v2/mix/market/open-interest?symbol=$instId&productType=umcbl');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data['code'] != '00000' || data['data'] == null) return null;
      return double.parse(data['data']['totalOpenInterest'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Trade>> fetchRecentTrades(String symbol, int limit) async => [];
  @override
  Future<List<LiquidationOrder>> fetchLiquidations(String symbol, int limit) async => [];
  @override
  Future<OrderBookDepth> fetchOrderBookDepth(String symbol, int limit) async =>
      OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
}

/// Gate API
class GateApi implements ExchangeApi {
  @override
  String get name => 'gate';
  @override
  String get baseUrl => 'https://api.gateio.ws';

  String _toGateSymbol(String symbol) => '${symbol.substring(0, 3)}_${symbol.substring(3)}';

  @override
  Future<MarketSnapshot?> fetchTicker(String symbol) async {
    try {
      final contract = _toGateSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v4/futures/usdt/tickers?contract=$contract');
      if (resp == null || resp.statusCode != 200) return null;
      final List<dynamic> data = json.decode(resp.body);
      if (data.isEmpty) return null;
      return MarketSnapshot(
        exchange: name,
        symbol: symbol,
        price: double.parse(data[0]['last'].toString()),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Kline>> fetchKlines(String symbol, String interval, int limit) async {
    try {
      final contract = _toGateSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v4/futures/usdt/candlesticks?contract=$contract&interval=$interval&limit=$limit');
      if (resp == null || resp.statusCode != 200) return [];
      final List<dynamic> data = json.decode(resp.body);
      return data.map((e) => Kline(
        openTime: int.parse(e[0].toString()) * 1000,
        open: double.parse(e[5].toString()),
        high: double.parse(e[3].toString()),
        low: double.parse(e[4].toString()),
        close: double.parse(e[2].toString()),
        volume: double.parse(e[1].toString()),
        closeTime: int.parse(e[0].toString()) * 1000 + 60000,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<double?> fetchFundingRate(String symbol) async {
    try {
      final contract = _toGateSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v4/futures/usdt/contracts/$contract');
      if (resp == null || resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      return double.parse(data['funding_rate'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> fetchOpenInterest(String symbol) async {
    try {
      final contract = _toGateSymbol(symbol);
      final resp = await RobustHttpClient.get('$baseUrl/api/v4/futures/usdt/tickers?contract=$contract');
      if (resp == null || resp.statusCode != 200) return null;
      final List<dynamic> data = json.decode(resp.body);
      if (data.isEmpty) return null;
      return double.parse(data[0]['open_interest'].toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Trade>> fetchRecentTrades(String symbol, int limit) async => [];
  @override
  Future<List<LiquidationOrder>> fetchLiquidations(String symbol, int limit) async => [];
  @override
  Future<OrderBookDepth> fetchOrderBookDepth(String symbol, int limit) async =>
      OrderBookDepth(bids: [], asks: [], time: DateTime.now().millisecondsSinceEpoch);
}

/// 交易所工厂
class ExchangeFactory {
  static final Map<String, ExchangeApi> _instances = {};

  static ExchangeApi get(String name) {
    if (!_instances.containsKey(name)) {
      switch (name) {
        case 'binance': _instances[name] = BinanceApi();
        case 'okx': _instances[name] = OkxApi();
        case 'bybit': _instances[name] = BybitApi();
        case 'bitget': _instances[name] = BitgetApi();
        case 'gate': _instances[name] = GateApi();
        default: throw ArgumentError('Unknown exchange: $name');
      }
    }
    return _instances[name]!;
  }

  static List<ExchangeApi> getAll() => AppConstants.exchanges.map((e) => get(e)).toList();
}
