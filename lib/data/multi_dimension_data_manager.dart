import 'dart:async';
import '../engine/sss/sss_analyzer.dart';
import '../utils/robust_http_client.dart';

/// 多维度数据管理器
/// 负责获取：消息面、宏观面、情绪面、资金面数据
class MultiDimensionDataManager {
  static final MultiDimensionDataManager _instance = MultiDimensionDataManager._internal();
  factory MultiDimensionDataManager() => _instance;
  MultiDimensionDataManager._internal();

  // CORS代理列表
  static const List<String> _corsProxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?',
    'https://api.codetabs.com/v1/proxy/?quest=',
  ];

  // 数据缓存
  List<NewsItem> _news = [];
  double _sp500Change = 0;
  double _dxyChange = 0;
  double _treasuryYield = 4.0;
  double _goldChange = 0;
  double _fearGreedIndex = 50;
  double _longShortRatio = 1.0;
  double _leverageRatio = 1.0;
  double _exchangeFlow = 0;
  double _whaleAccumulation = 0;
  double _stablecoinMarketCapChange = 0;
  double _openInterestChange = 0;

  bool _isInitialized = false;
  Timer? _refreshTimer;

  List<NewsItem> get news => List.unmodifiable(_news);
  double get sp500Change => _sp500Change;
  double get dxyChange => _dxyChange;
  double get treasuryYield => _treasuryYield;
  double get goldChange => _goldChange;
  double get fearGreedIndex => _fearGreedIndex;
  double get longShortRatio => _longShortRatio;
  double get leverageRatio => _leverageRatio;
  double get exchangeFlow => _exchangeFlow;
  double get whaleAccumulation => _whaleAccumulation;
  double get stablecoinMarketCapChange => _stablecoinMarketCapChange;
  double get openInterestChange => _openInterestChange;

  /// 初始化
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    // 立即刷新一次
    await refreshAll();
    // 每5分钟刷新一次
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => refreshAll());
  }

  /// 刷新所有数据
  Future<void> refreshAll() async {
    await Future.wait([
      _fetchNews(),
      _fetchMacroData(),
      _fetchSentimentData(),
      _fetchCapitalData(),
    ]);
  }

  /// 获取消息面数据（加密货币新闻）
  Future<void> _fetchNews() async {
    try {
      // 使用CryptoCompare免费新闻API（通过CORS代理）
      final url = 'https://min-api.cryptocompare.com/data/v2/news/?lang=EN';
      final data = await _fetchWithProxy(url);
      if (data != null && data['Data'] != null) {
        _news = (data['Data'] as List).take(10).map((item) {
          // 简单情绪分析：根据标题关键词判断
          final title = item['title'] ?? '';
          double sentiment = 0;
          if (title.contains(RegExp(r'surge|rally|bullish|breakout|soar|jump|gain', caseSensitive: false))) {
            sentiment = 0.5;
          } else if (title.contains(RegExp(r'crash|dump|bearish|plunge|drop|loss|hack|ban', caseSensitive: false))) {
            sentiment = -0.5;
          }
          // 影响度：根据来源和标题长度判断
          int impact = 2;
          if (title.length > 80) impact = 3;
          if (title.contains(RegExp(r'ETF|SEC|Fed|Bitcoin|Ethereum', caseSensitive: false))) impact = 4;
          
          return NewsItem(
            title: title,
            source: item['source_info']?['name'] ?? 'CryptoCompare',
            publishedAt: DateTime.fromMillisecondsSinceEpoch((item['published_on'] ?? 0) * 1000),
            impact: impact.toDouble(),
            sentiment: sentiment,
            url: item['url'] ?? '',
          );
        }).toList();
      }
    } catch (_) {
      // 获取失败时使用默认空列表
      _news = [];
    }
  }

  /// 获取宏观面数据（接入Yahoo Finance真实API：标普500/黄金/美元指数/美债收益率）
  Future<void> _fetchMacroData() async {
    try {
      // 标普500（Yahoo Finance API，通过CORS代理）
      final sp500Url = 'https://query1.finance.yahoo.com/v8/finance/chart/%5EGSPC?interval=1d&range=2d';
      final sp500Data = await _fetchWithProxy(sp500Url);
      if (sp500Data != null && sp500Data['chart']?['result'] != null) {
        final results = sp500Data['chart']['result'] as List;
        if (results.isNotEmpty) {
          final meta = results[0]['meta'];
          final regularMarketPrice = meta?['regularMarketPrice']?.toDouble() ?? 0;
          final previousClose = meta?['chartPreviousClose']?.toDouble() ?? regularMarketPrice;
          if (previousClose > 0) {
            _sp500Change = ((regularMarketPrice - previousClose) / previousClose * 100);
          }
        }
      }
      // 黄金价格（Yahoo Finance API，通过CORS代理）
      final goldUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/GC%3DF?interval=1d&range=2d';
      final goldData = await _fetchWithProxy(goldUrl);
      if (goldData != null && goldData['chart']?['result'] != null) {
        final results = goldData['chart']['result'] as List;
        if (results.isNotEmpty) {
          final meta = results[0]['meta'];
          final regularMarketPrice = meta?['regularMarketPrice']?.toDouble() ?? 0;
          final previousClose = meta?['chartPreviousClose']?.toDouble() ?? regularMarketPrice;
          if (previousClose > 0) {
            _goldChange = ((regularMarketPrice - previousClose) / previousClose * 100);
          }
        }
      }
      // 美元指数DXY（Yahoo Finance API，通过CORS代理）
      final dxyUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/DX-Y.NYB?interval=1d&range=2d';
      final dxyData = await _fetchWithProxy(dxyUrl);
      if (dxyData != null && dxyData['chart']?['result'] != null) {
        final results = dxyData['chart']['result'] as List;
        if (results.isNotEmpty) {
          final meta = results[0]['meta'];
          final regularMarketPrice = meta?['regularMarketPrice']?.toDouble() ?? 0;
          final previousClose = meta?['chartPreviousClose']?.toDouble() ?? regularMarketPrice;
          if (previousClose > 0) {
            _dxyChange = ((regularMarketPrice - previousClose) / previousClose * 100);
          }
        }
      }
      // 10年期美债收益率（Yahoo Finance API，通过CORS代理）
      final treasuryUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/%5ETNX?interval=1d&range=2d';
      final treasuryData = await _fetchWithProxy(treasuryUrl);
      if (treasuryData != null && treasuryData['chart']?['result'] != null) {
        final results = treasuryData['chart']['result'] as List;
        if (results.isNotEmpty) {
          final meta = results[0]['meta'];
          _treasuryYield = meta?['regularMarketPrice']?.toDouble() ?? 0;
        }
      }
    } catch (_) {
      // 获取失败时使用默认值0
      _sp500Change = 0;
      _goldChange = 0;
      _dxyChange = 0;
      _treasuryYield = 0;
    }
  }

  /// 获取情绪面数据（接入贪婪恐惧指数+Binance多空比真实API）
  Future<void> _fetchSentimentData() async {
    try {
      // 贪婪恐惧指数（使用alternative.me免费API，通过CORS代理）
      final url = 'https://api.alternative.me/fng/?limit=1';
      final data = await _fetchWithProxy(url);
      if (data != null && data['data'] != null && data['data'].isNotEmpty) {
        _fearGreedIndex = double.tryParse(data['data'][0]['value'] ?? '50') ?? 50;
      }
      // Binance ETH多空比（真实API，通过CORS代理）
      final lsUrl = 'https://fapi.binance.com/futures/data/globalLongShortAccountRatio?symbol=ETHUSDT&period=1h&limit=1';
      final lsData = await _fetchWithProxy(lsUrl);
      if (lsData != null && lsData is List && lsData.isNotEmpty) {
        _longShortRatio = double.tryParse(lsData[0]['longShortRatio'] ?? '1') ?? 1;
      }
      // 杠杆率用Binance多空比和资金费率估算（简化估算）
      final fundingRate = _exchangeFlow / 10000; // 从资金面获取的资金费率
      if (_longShortRatio > 0 && fundingRate.abs() > 0) {
        // 多空比偏离1越多+资金费率越高，杠杆率越高
        _leverageRatio = (_longShortRatio - 1).abs() * 10 + fundingRate.abs() * 1000;
      } else {
        _leverageRatio = 0;
      }
    } catch (_) {
      _fearGreedIndex = 50;
      _longShortRatio = 0;
      _leverageRatio = 0;
    }
  }

  /// 获取资金面数据（接入OKX资金费率+持仓量+CoinGecko稳定币市值真实API，巨鲸数据需要付费API）
  Future<void> _fetchCapitalData() async {
    try {
      // OKX ETH永续资金费率（真实API，通过CORS代理）
      final fundingUrl = 'https://www.okx.com/api/v5/public/funding-rate?instId=ETH-USDT-SWAP';
      final fundingData = await _fetchWithProxy(fundingUrl);
      if (fundingData != null && fundingData['data'] != null && fundingData['data'].isNotEmpty) {
        final fundingRate = double.tryParse(fundingData['data'][0]['fundingRate'] ?? '0') ?? 0;
        // 资金费率转换为百分比，正为多头付费，负为空头付费
        _exchangeFlow = fundingRate * 10000; // 用exchangeFlow字段临时存储资金费率
      }
      // OKX ETH永续持仓量（真实API，通过CORS代理）
      final oiUrl = 'https://www.okx.com/api/v5/public/open-interest?instId=ETH-USDT-SWAP';
      final oiData = await _fetchWithProxy(oiUrl);
      if (oiData != null && oiData['data'] != null && oiData['data'].isNotEmpty) {
        final oi = double.tryParse(oiData['data'][0]['oi'] ?? '0') ?? 0;
        // 用openInterestChange字段临时存储持仓量
        _openInterestChange = oi;
      }
      // 稳定币市值变化（CoinGecko免费API，通过CORS代理）
      final stablecoinUrl = 'https://api.coingecko.com/api/v3/global';
      final stablecoinData = await _fetchWithProxy(stablecoinUrl);
      if (stablecoinData != null && stablecoinData['data'] != null) {
        final totalMarketCap = stablecoinData['data']['total_market_cap']?['usd']?.toDouble() ?? 0;
        final totalVolume = stablecoinData['data']['total_volume']?['usd']?.toDouble() ?? 0;
        // 用成交量/市值比估算稳定币活跃度，简化为市值变化
        if (totalMarketCap > 0) {
          _stablecoinMarketCapChange = (totalVolume / totalMarketCap) * 100; // 换手率作为活跃度指标
        }
      }
      // 巨鲸增持未接入真实API（需要Glassnode/CryptoQuant付费API），设为0
      _whaleAccumulation = 0;
    } catch (_) {
      // 获取失败时使用默认值0
      _exchangeFlow = 0;
      _openInterestChange = 0;
      _whaleAccumulation = 0;
      _stablecoinMarketCapChange = 0;
    }
  }

  /// 通过CORS代理获取数据
  Future<Map<String, dynamic>?> _fetchWithProxy(String url) async {
    for (final proxy in _corsProxies) {
      try {
        final fullUrl = proxy + Uri.encodeComponent(url);
        final resp = await RobustHttpClient.getJson(fullUrl).timeout(
          const Duration(seconds: 10),
        );
        if (resp != null && resp is Map<String, dynamic>) {
          return resp;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 计算SSS级综合评分
  SSSResult calculateSSSScore(String direction, {
    required double technicalScore,
  }) {
    final newsScore = SSSAnalyzer.calculateNewsScore(news: _news, direction: direction);
    final macroScore = SSSAnalyzer.calculateMacroScore(
      sp500Change: _sp500Change,
      dxyChange: _dxyChange,
      treasuryYield: _treasuryYield,
      goldChange: _goldChange,
      direction: direction,
    );
    final sentimentScore = SSSAnalyzer.calculateSentimentScore(
      fearGreedIndex: _fearGreedIndex,
      longShortRatio: _longShortRatio,
      leverageRatio: _leverageRatio,
      direction: direction,
    );
    final capitalScore = SSSAnalyzer.calculateCapitalScore(
      exchangeFlow: _exchangeFlow,
      whaleAccumulation: _whaleAccumulation,
      stablecoinMarketCapChange: _stablecoinMarketCapChange,
      openInterestChange: _openInterestChange,
      direction: direction,
    );

    return SSSAnalyzer.calculateSSSScore(
      technicalScore: technicalScore,
      newsScore: newsScore,
      macroScore: macroScore,
      sentimentScore: sentimentScore,
      capitalScore: capitalScore,
    );
  }

  /// 销毁
  void dispose() {
    _refreshTimer?.cancel();
    _isInitialized = false;
  }
}
