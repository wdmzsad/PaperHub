import 'package:flutter/foundation.dart';

class AppEnv {
  static const String _envApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envWsBaseUrl =
      String.fromEnvironment('WS_BASE_URL', defaultValue: '');

  static const String _localHttpBase = 'http://localhost:8080';
  static const String _cloudHttpBase = 'http://124.70.87.106:8080';

  static String get apiBaseUrl {
    final fallback = kReleaseMode ? _cloudHttpBase : _localHttpBase;
    final selected = _envApiBaseUrl.isNotEmpty ? _envApiBaseUrl : fallback;
    return _ensureNoTrailingSlash(selected);
  }

  static String get wsBaseUrl {
    if (_envWsBaseUrl.isNotEmpty) {
      return _ensureNoTrailingSlash(_envWsBaseUrl);
    }
    final httpBase = apiBaseUrl;
    if (httpBase.startsWith('https://')) {
      return 'wss://${httpBase.substring(8)}';
    }
    if (httpBase.startsWith('http://')) {
      return 'ws://${httpBase.substring(7)}';
    }
    return httpBase;
  }

  static String _ensureNoTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}

