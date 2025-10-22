import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService extends ChangeNotifier {
  static const _cacheEnabledKey = 'audio_cache_enabled';
  
  bool _cacheEnabled = false;
  
  bool get cacheEnabled => _cacheEnabled;
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cacheEnabled = prefs.getBool(_cacheEnabledKey) ?? false;
    notifyListeners();
  }
  
  Future<void> setCacheEnabled(bool enabled) async {
    if (_cacheEnabled == enabled) return;
    _cacheEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheEnabledKey, enabled);
    notifyListeners();
  }
}