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
      // 使用CoinGecko免费API获取新闻（通过CORS代理）
      final url = 'https://api.coingecko.com/api/v3/status_updates?per_page=10';
      final data = await _fetchWithProxy(url);
      if (data != null && data['status_updates'] != null) {
        _news = (data['status_updates'] as List).take(10).map((item) {
          return NewsItem(
            title: item['title'] ?? item['description'] ?? '新闻',
            source: item['user'] ?? 'CoinGecko',
            publishedAt: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            impact: 3,
            sentiment: 0,
            url: item['url'] ?? '',
          );
        }).toList();
      }
    } catch (_) {
      // 获取失败时使用默认空列表
      _news = [];
    }
  }

  /// 获取宏观面数据
  Future<void> _fetchMacroData() async {
    try {
      // 标普500（使用Yahoo Finance API，通过CORS代理）
      // 由于API限制，这里使用模拟数据，实际部署时可接入真实API
      _sp500Change = 0.2; // 模拟
      _dxyChange = -0.1; // 模拟
      _treasuryYield = 4.2; // 模拟
      _goldChange = 0.1; // 模拟
    } catch (_) {
      // 使用默认值
    }
  }

  /// 获取情绪面数据
  Future<void> _fetchSentimentData() async {
    try {
      // 贪婪恐惧指数（使用alternative.me免费API，通过CORS代理）
      final url = 'https://api.alternative.me/fng/?limit=1';
      final data = await _fetchWithProxy(url);
      if (data != null && data['data'] != null && data['data'].isNotEmpty) {
        _fearGreedIndex = double.tryParse(data['data'][0]['value'] ?? '50') ?? 50;
      }
      // 多空比和杠杆率使用模拟数据
      _longShortRatio = 1.2;
      _leverageRatio = 1.5;
    } catch (_) {
      _fearGreedIndex = 50;
    }
  }

  /// 获取资金面数据
  Future<void> _fetchCapitalData() async {
    try {
      // 资金面数据使用模拟数据（实际需要接入Glassnode、CryptoQuant等付费API）
      _exchangeFlow = -50; // 模拟：交易所净流出50M
      _whaleAccumulation = 0.3; // 模拟：巨鲸增持
      _stablecoinMarketCapChange = 0.5; // 模拟：稳定币市值增加0.5%
      _openInterestChange = 3.0; // 模拟：持仓量增加3%
    } catch (_) {
      // 使用默认值
    }
  }

  /// 通过CORS代理获取数据
  Future<Map<String, dynamic>?> _fetchWithProxy(String url) async {
    for (final proxy in _corsProxies) {
      try {
        final fullUrl = proxy + Uri.encodeComponent(url);
        final resp = await RobustHttpClient.get(fullUrl).timeout(
          const Duration(seconds: 10),
        );
        if (resp != null) return resp;
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
