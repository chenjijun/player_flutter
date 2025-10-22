import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService extends ChangeNotifier {
  static const _cacheEnabledKey = 'audio_cache_enabled';
  static const _maxCacheSizeKey = 'audio_cache_max_size';
  
  // 默认最大缓存大小为1GB
  static const int defaultMaxCacheSize = 1024 * 1024 * 1024; // 1GB in bytes
  
  bool _cacheEnabled = false;
  int _maxCacheSize = defaultMaxCacheSize;
  
  bool get cacheEnabled => _cacheEnabled;
  int get maxCacheSize => _maxCacheSize;
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cacheEnabled = prefs.getBool(_cacheEnabledKey) ?? false;
    _maxCacheSize = prefs.getInt(_maxCacheSizeKey) ?? defaultMaxCacheSize;
    notifyListeners();
  }
  
  Future<void> setCacheEnabled(bool enabled) async {
    if (_cacheEnabled == enabled) return;
    _cacheEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheEnabledKey, enabled);
    notifyListeners();
  }
  
  Future<void> setMaxCacheSize(int maxSize) async {
    if (_maxCacheSize == maxSize) return;
    _maxCacheSize = maxSize;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxCacheSizeKey, maxSize);
    notifyListeners();
  }
}