import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 多代理备选+自动重试的HTTP请求工具
/// S级标准：优先直连，代理兜底，确保网络请求的稳定性和可靠性
class RobustHttpClient {
  /// CORS代理列表（按优先级排序，仅作为兜底）
  static const List<String> _proxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?url=',
    'https://api.codetabs.com/v1/proxy?quest=',
    'https://thingproxy.freeboard.io/fetch/',
    'https://proxy.cors.sh/',
  ];

  /// 最大重试次数
  static const int _maxRetries = 2;

  /// 单次请求超时（秒）
  static const int _timeoutSeconds = 15;

  /// 重试间隔（毫秒）
  static const int _retryDelayMs = 500;

  /// 发送GET请求
  /// Web环境：优先直连 → 失败后尝试代理
  /// 非Web环境：直接请求
  static Future<http.Response?> get(String url, {int timeoutSeconds = _timeoutSeconds}) async {
    // 非Web环境直接请求
    if (!kIsWeb) {
      try {
        return await http.get(Uri.parse(url)).timeout(Duration(seconds: timeoutSeconds));
      } catch (_) {
        return null;
      }
    }

    // Web环境：第一步，优先直连（OKX等交易所API支持CORS）
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: timeoutSeconds));
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          return response;
        }
      } catch (_) {
        // 直连失败（CORS或网络问题），继续尝试代理
        break;
      }
      if (attempt < _maxRetries - 1) {
        await Future.delayed(const Duration(milliseconds: _retryDelayMs));
      }
    }

    // Web环境：第二步，代理兜底
    for (final proxy in _proxies) {
      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final proxyUrl = proxy + Uri.encodeComponent(url);
          final response = await http.get(Uri.parse(proxyUrl)).timeout(Duration(seconds: timeoutSeconds));
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            return response;
          }
        } catch (_) {
          // 继续重试或下一个代理
        }
        if (attempt < _maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: _retryDelayMs));
        }
      }
    }
    return null;
  }

  /// 发送GET请求并解析JSON
  static Future<dynamic> getJson(String url, {int timeoutSeconds = _timeoutSeconds}) async {
    final response = await get(url, timeoutSeconds: timeoutSeconds);
    if (response == null || response.statusCode != 200) return null;
    try {
      return json.decode(response.body);
    } catch (_) {
      return null;
    }
  }

  /// 发送POST请求
  static Future<http.Response?> post(String url, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    try {
      return await http.post(
        Uri.parse(url),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: _timeoutSeconds));
    } catch (_) {
      return null;
    }
  }
}
