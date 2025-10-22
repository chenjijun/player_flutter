import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 后台任务工具类，用于处理耗时计算任务
class BackgroundTask {
  /// 在后台线程解析JSON数据
  static Future<Map<String, dynamic>> parseJsonInBackground(String jsonString) async {
    return await compute(_parseJson, jsonString);
  }

  /// 在后台线程解析JSON数组
  static Future<List<dynamic>> parseJsonArrayInBackground(String jsonString) async {
    return await compute(_parseJsonArray, jsonString);
  }

  /// 在后台线程处理Navidrome歌曲数据
  static Future<List<Map<String, dynamic>>> processSongsInBackground(List<dynamic> songs, Map<String, dynamic> config) async {
    final data = {
      'songs': songs,
      'config': config,
    };
    return await compute(_processSongs, data);
  }

  /// 实际的JSON解析函数（在后台线程运行）
  static Map<String, dynamic> _parseJson(String jsonString) {
    try {
      final result = json.decode(jsonString);
      return result is Map<String, dynamic> ? result : {};
    } catch (e) {
      debugPrint('JSON解析失败: $e');
      return {};
    }
  }

  /// 实际的JSON数组解析函数（在后台线程运行）
  static List<dynamic> _parseJsonArray(String jsonString) {
    try {
      final result = json.decode(jsonString);
      return result is List<dynamic> ? result : [];
    } catch (e) {
      debugPrint('JSON数组解析失败: $e');
      return [];
    }
  }

  /// 实际的歌曲数据处理函数（在后台线程运行）
  static List<Map<String, dynamic>> _processSongs(Map<String, dynamic> data) {
    try {
      final songs = (data['songs'] as List<dynamic>?) ?? [];
      final config = (data['config'] as Map<String, dynamic>?) ?? {};

      if (config.isEmpty || songs.isEmpty) return [];

      final serverUrl = config['serverUrl'] as String? ?? '';
      final username = config['username'] as String? ?? '';
      final token = config['token'] as String? ?? '';
      final salt = config['salt'] as String? ?? '';

      if (serverUrl.isEmpty || username.isEmpty || token.isEmpty || salt.isEmpty) {
        debugPrint('配置信息不完整');
        return [];
      }

      return songs.map((json) {
        final id = json['id'] as String?;
        final coverArt = json['coverArt'] as String?;
        
        if (id == null) return null;

        return <String, dynamic>{
          'id': id,
          'title': json['title'] as String? ?? '',
          'artist': json['artist'] as String? ?? '',
          'album': json['album'] as String? ?? '',
          'duration': json['duration'] as int? ?? 0,
          'url': _buildStreamUrl(serverUrl, username, token, salt, id),
          'coverUrl': coverArt != null
              ? _buildCoverArtUrl(serverUrl, username, token, salt, coverArt)
              : null,
        };
      }).where((song) => song != null).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('处理歌曲数据失败: $e');
      return [];
    }
  }

  /// 构建流媒体播放URL
  static String _buildStreamUrl(
    String serverUrl,
    String username,
    String token,
    String salt,
    String id,
  ) {
    return '$serverUrl/rest/stream.view'
        '?u=${Uri.encodeComponent(username)}'
        '&t=$token'
        '&s=$salt'
        '&v=1.13.0'
        '&c=myapp'
        '&id=$id';
  }

  /// 构建封面图URL
  static String _buildCoverArtUrl(
    String serverUrl,
    String username,
    String token,
    String salt,
    String coverArtId,
  ) {
    return '$serverUrl/rest/getCoverArt.view'
        '?u=${Uri.encodeComponent(username)}'
        '&t=$token'
        '&s=$salt'
        '&v=1.13.0'
        '&c=myapp'
        '&id=$coverArtId';
  }
}