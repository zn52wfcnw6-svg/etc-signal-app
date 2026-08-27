import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 多代理备选+自动重试的HTTP请求工具
/// S级标准：确保网络请求的稳定性和可靠性
class RobustHttpClient {
  /// CORS代理列表（按优先级排序）
  static const List<String> _proxies = [
    'https://corsproxy.io/?url=',
    'https://api.allorigins.win/raw?url=',
    'https://thingproxy.freeboard.io/fetch/',
  ];

  /// 最大重试次数
  static const int _maxRetries = 3;

  /// 单次请求超时（秒）
  static const int _timeoutSeconds = 15;

  /// 重试间隔（毫秒）
  static const int _retryDelayMs = 1000;

  /// 发送GET请求，自动尝试多个代理和重试
  static Future<http.Response?> get(String url, {int timeoutSeconds = _timeoutSeconds}) async {
    if (!kIsWeb) {
      // 非Web环境直接请求
      try {
        return await http.get(Uri.parse(url)).timeout(Duration(seconds: timeoutSeconds));
      } catch (_) {
        return null;
      }
    }

    // Web环境：依次尝试每个代理，每个代理重试多次
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
        // 重试间隔
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
