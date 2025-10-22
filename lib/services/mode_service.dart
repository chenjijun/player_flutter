import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/navidrome_config.dart';
import 'navidrome_service.dart';

enum PlayerMode {
  local,
  navidrome,
}

class ModeService extends ChangeNotifier {
  static const _modeKey = 'player_mode';
  static const _configKey = 'navidrome_config';
  static const _passwordKey = 'navidrome_password'; // 用于存储加密的密码
  
  PlayerMode _currentMode = PlayerMode.local;
  final NavidromeService _navidromeService = NavidromeService();
  NavidromeConfig? _config;

  PlayerMode get currentMode => _currentMode;
  bool get isNavidromeMode => _currentMode == PlayerMode.navidrome;
  NavidromeService get navidromeService => _navidromeService;
  NavidromeConfig? get navidromeConfig => _config;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 恢复模式
    final modeStr = prefs.getString(_modeKey);
    if (modeStr != null) {
      _currentMode = PlayerMode.values.firstWhere(
        (m) => m.toString() == modeStr,
        orElse: () => PlayerMode.local,
      );
    }

    // 恢复 Navidrome 配置
    final configStr = prefs.getString(_configKey);
    if (configStr != null) {
      try {
        final configMap = json.decode(configStr) as Map<String, dynamic>;
        _config = NavidromeConfig.fromJson(configMap);
        
        // 恢复密码
        final savedPassword = prefs.getString(_passwordKey);
        if (savedPassword != null && _config != null) {
          _config = NavidromeConfig(
            serverUrl: _config!.serverUrl,
            username: _config!.username,
            password: savedPassword,
            salt: _config!.salt,
            token: _config!.token,
          );
        }
        
        // 尝试登录
        if (_currentMode == PlayerMode.navidrome && _config != null) {
          // 设置已保存的salt和token到服务中
          if (_config!.salt.isNotEmpty && _config!.token.isNotEmpty) {
            _navidromeService.setConfig(_config!);
            _navidromeService.setAuthInfo(_config!.salt, _config!.token);
          }
          
          // 即使是热重载，也要尝试登录
          final success = await _navidromeService.login(_config!);
          if (!success) {
            // 登录失败回退到本地模式
            _currentMode = PlayerMode.local;
            await prefs.setString(_modeKey, _currentMode.toString());
          } else {
            // 登录成功，保存salt和token
            _config = NavidromeConfig(
              serverUrl: _config!.serverUrl,
              username: _config!.username,
              password: savedPassword ?? _config!.password,
              salt: _navidromeService.salt ?? _config!.salt,
              token: _navidromeService.token ?? _config!.token,
            );
            
            // 更新存储的配置
            await prefs.setString(_configKey, json.encode(_config!.toJson()));
          }
        }
      } catch (e) {
        // 配置解析失败
        _config = null;
        debugPrint('Failed to parse saved Navidrome config: $e');
      }
    }
    
    notifyListeners();
  }

  Future<void> switchMode(PlayerMode mode) async {
    if (mode == PlayerMode.navidrome && _config == null) {
      throw Exception('需要先配置 Navidrome 服务器');
    }

    if (mode == _currentMode) return;

    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.toString());
    
    if (mode == PlayerMode.navidrome && _config != null) {
      await _navidromeService.login(_config!);
    }
    
    notifyListeners();
  }

  /// Try to setup Navidrome. Returns null on success, or an error message on failure.
  Future<String?> setupNavidrome(NavidromeConfig config, {bool savePassword = false}) async {
    final test = await _navidromeService.testConnection(config);
    if (test != null) return test; // error message

    final success = await _navidromeService.login(config);
    if (success) {
      _config = config;
      final prefs = await SharedPreferences.getInstance();
      
      // 根据用户选择决定是否保存密码
      if (savePassword) {
        await prefs.setString(_passwordKey, config.password);
      } else {
        await prefs.remove(_passwordKey);
      }
      
      // 保存salt和token
      if (_navidromeService.salt != null && _navidromeService.token != null) {
        _config = NavidromeConfig(
          serverUrl: config.serverUrl,
          username: config.username,
          password: savePassword ? config.password : '',
          salt: _navidromeService.salt!,
          token: _navidromeService.token!,
        );
        await prefs.setString(_configKey, json.encode(_config!.toJson()));
      }
      
      notifyListeners();
      return null;
    }
    return 'login failed for unknown reason';
  }

  void clearNavidromeConfig() async {
    if (_currentMode == PlayerMode.navidrome) {
      await switchMode(PlayerMode.local);
    }
    _config = null;
    _navidromeService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await prefs.remove(_passwordKey);
    notifyListeners();
  }
  
  // 添加一个方法来更新密码保存设置
  Future<void> updatePasswordSavePreference(NavidromeConfig config, bool savePassword) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (savePassword) {
      await prefs.setString(_passwordKey, config.password);
    } else {
      await prefs.remove(_passwordKey);
    }
    
    // 更新配置
    _config = config;
    await prefs.setString(_configKey, json.encode(config.copyForStorage().toJson()));
    notifyListeners();
  }
}