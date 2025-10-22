import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/navidrome_config.dart';
import '../models/song.dart';
import '../utils/background_task.dart';

class NavidromeService {
  NavidromeConfig? _config;
  String? _salt;
  String? _token;
  
  void logout() {
    _config = null;
    _salt = null;
    _token = null;
  }
  
  // 添加获取token和salt的公共方法
  String? get token => _token;
  String? get salt => _salt;
  NavidromeConfig? get config => _config;

  bool get isConfigured => _config != null;

  // 添加设置配置的方法
  void setConfig(NavidromeConfig config) {
    _config = config;
  }
  
  // 添加设置salt和token的方法
  void setAuthInfo(String? salt, String? token) {
    _salt = salt;
    _token = token;
  }

  String _generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return random.substring(random.length - 6); // 使用时间戳后6位作为salt
  }

  Future<bool> login(NavidromeConfig config) async {
    debugPrint('Attempting to login to Navidrome server: ${config.serverUrl}');
    debugPrint('Username: ${config.username}');
    debugPrint('Has saved credentials: ${config.salt != null && config.token != null}');
    
    try {
      // 如果配置中已经包含salt和token，则直接使用
      if (config.salt.isNotEmpty && config.token.isNotEmpty) {
        _salt = config.salt;
        _token = config.token;
        _config = config;
        debugPrint('Using saved credentials for login');
        
        // 验证凭据是否有效
        final testResult = await testConnection(config);
        if (testResult == null) {
          debugPrint('Navidrome login success with saved credentials');
          return true;
        } else {
          debugPrint('Saved credentials invalid: $testResult');
          // 继续使用密码生成新的凭据
        }
      }

      // 生成 salt（客户端生成，而不是从服务器获取）
      _salt = _generateSalt();
      debugPrint('Generated salt: $_salt');
      
      // 生成 token = md5(password + salt)
      final tokenInput = '${config.password}$_salt';
      _token = md5.convert(utf8.encode(tokenInput)).toString();
      debugPrint('Generated token: $_token');

      // 使用 ping 测试连接
      final loginUrl = Uri.parse(
        '${config.serverUrl}/rest/ping.view'
        '?u=${Uri.encodeComponent(config.username)}'
        '&t=$_token'
        '&s=$_salt'
        '&v=1.13.0'  // Subsonic API 1.13.0
        '&c=myapp'
        '&f=json'    // 请求 JSON 格式响应
      );
      
      debugPrint('Login request URL: $loginUrl');
      final loginResponse = await http.get(loginUrl);
      debugPrint('Login response status: ${loginResponse.statusCode}');
      debugPrint('Login response headers: ${loginResponse.headers}');
      
      if (loginResponse.statusCode != 200) {
        debugPrint('Navidrome ping failed: ${loginResponse.statusCode} ${loginResponse.body}');
        return false;
      }

      // 使用utf8.decode解决中文乱码问题
      final responseBody = utf8.decode(loginResponse.bodyBytes);
      debugPrint('Login response body: $responseBody');

      try {
        // 在后台线程解析JSON响应
        final jsonBody = await compute(jsonDecode, responseBody);
        if (jsonBody['subsonic-response']?['status'] != 'ok') {
          final error = jsonBody['subsonic-response']?['error'];
          debugPrint('Navidrome ping error: ${error?['message'] ?? 'Unknown error'}');
          return false;
        }
      } catch (e) {
        debugPrint('Navidrome ping response parse error: $e');
        return false;
      }

      _config = config;
      return true;
    } catch (e) {
      debugPrint('Navidrome login exception: $e');
      return false;
    }
  }

  Future<String?> testConnection(NavidromeConfig config) async {
    try {
      final salt = _generateSalt();
      final token = md5.convert(utf8.encode('${config.password}$salt')).toString();
      
      final pingUrl = Uri.parse(
        '${config.serverUrl}/rest/ping.view'
        '?u=${Uri.encodeComponent(config.username)}'
        '&t=$token'
        '&s=$salt'
        '&v=1.13.0'
        '&c=myapp'
        '&f=json'
      );
      
      debugPrint('Test connection URL: $pingUrl');
      final response = await http.get(pingUrl);
      debugPrint('Test connection response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        return 'Ping failed (HTTP ${response.statusCode}): ${response.body}';
      }

      // 使用utf8.decode解决中文乱码问题
      final responseBody = utf8.decode(response.bodyBytes);
      debugPrint('Test connection response body: $responseBody');

      try {
        // 在后台线程解析JSON响应
        final jsonBody = await compute(jsonDecode, responseBody);
        if (jsonBody['subsonic-response']?['status'] != 'ok') {
          final error = jsonBody['subsonic-response']?['error'];
          return '${error?['message'] ?? 'Unknown error'}';
        }
        return null; // Connection OK
      } catch (e) {
        return 'Failed to parse response: $e';
      }
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  Future<int> getSongCount() async {
    if (_config == null || _salt == null || _token == null) {
      throw Exception('需要先登录');
    }

    try {
      final url = Uri.parse(
        '${_config!.serverUrl}/rest/getScanStatus.view'
        '?u=${Uri.encodeComponent(_config!.username)}'
        '&t=$_token'
        '&s=$_salt'
        '&v=1.13.0'
        '&c=myapp'
        '&f=json'
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('获取歌曲总数失败：HTTP ${response.statusCode}');
      }

      // 使用utf8.decode解决中文乱码问题
      final responseBody = utf8.decode(response.bodyBytes);
      // 在后台线程解析JSON响应
      final jsonBody = await compute(jsonDecode, responseBody);
      final subsonic = jsonBody['subsonic-response'];
      if (subsonic['status'] != 'ok') {
        throw Exception('获取歌曲总数失败：${subsonic['error']?['message'] ?? '未知错误'}');
      }

      // 从scanStatus中获取歌曲总数
      return subsonic['scanStatus']['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('getSongCount error: $e');
      rethrow;
    }
  }

  Future<List<Song>> getSongs({int offset = 0, int count = 20}) async {
    if (_config == null || _salt == null || _token == null) {
      throw Exception('需要先登录');
    }

    try {
      // 使用search3.view来获取所有歌曲，通过空查询获取全部歌曲
      final url = Uri.parse(
        '${_config!.serverUrl}/rest/search3.view'
        '?u=${Uri.encodeComponent(_config!.username)}'
        '&t=$_token'
        '&s=$_salt'
        '&v=1.13.0'
        '&c=myapp'
        '&f=json'
        '&query=' // 空查询获取所有歌曲
        '&songCount=$count'
        '&songOffset=$offset'
      );

      debugPrint('Fetching songs with offset: $offset, count: $count');
      debugPrint('Request URL: $url');
      final response = await http.get(url);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');
      
      if (response.statusCode != 200) {
        throw Exception('获取歌曲失败：HTTP ${response.statusCode}');
      }

      // 使用utf8.decode解决中文乱码问题
      final responseBody = utf8.decode(response.bodyBytes);
      debugPrint('Response body: $responseBody');
      
      // 在后台线程解析JSON
      final jsonBody = await compute(jsonDecode, responseBody);
      final subsonic = jsonBody['subsonic-response'];
      if (subsonic['status'] != 'ok') {
        throw Exception('获取歌曲失败：${subsonic['error']?['message'] ?? '未知错误'}');
      }

      final List<dynamic> songList = subsonic['searchResult3']['song'] as List<dynamic>? ?? [];
      debugPrint('Received ${songList.length} songs');
          
      // 在后台线程处理歌曲数据
      final configData = {
        'serverUrl': _config!.serverUrl,
        'username': _config!.username,
        'token': _token,
        'salt': _salt,
      };
      
      final processedSongs = await compute(_processSongs, {
        'songs': songList,
        'config': configData,
      });
      
      return processedSongs.map((data) => Song(
        id: data['id'],
        title: data['title'],
        artist: data['artist'],
        album: data['album'],
        duration: data['duration'],
        url: data['url'],
        coverUrl: data['coverUrl'],
      )).toList();
    } catch (e) {
      debugPrint('Error in getSongs: $e');
      throw Exception('获取歌曲失败：$e');
    }
  }

  // 获取专辑列表
  Future<List<Map<String, dynamic>>> getAlbumList(String type, int size) async {
    if (_config == null || _salt == null || _token == null) {
      throw Exception('需要先登录');
    }

    try {
      final url = Uri.parse(
        '${_config!.serverUrl}/rest/getAlbumList2.view'
        '?u=${Uri.encodeComponent(_config!.username)}'
        '&t=$_token'
        '&s=$_salt'
        '&v=1.13.0'
        '&c=myapp'
        '&f=json'
        '&type=$type'
        '&size=$size'
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('获取专辑列表失败：HTTP ${response.statusCode}');
      }

      // 使用utf8.decode解决中文乱码问题，并在后台线程解析JSON
      final responseBody = utf8.decode(response.bodyBytes);
      final jsonBody = await compute(jsonDecode, responseBody);
      final subsonic = jsonBody['subsonic-response'];
      if (subsonic['status'] != 'ok') {
        throw Exception('获取专辑列表失败：${subsonic['error']?['message'] ?? '未知错误'}');
      }

      final List<dynamic> albumList = subsonic['albumList2']['album'] as List<dynamic>;
      
      // 在后台线程处理专辑数据
      final config = {
        'serverUrl': _config!.serverUrl,
      };
      
      final processedAlbums = await compute(_processAlbums, {
        'albums': albumList,
        'config': config,
      });
      
      return processedAlbums;
    } catch (e) {
      debugPrint('getAlbumList error: $e');
      rethrow;
    }
  }
  
  // 获取播放列表
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    if (_config == null || _salt == null || _token == null) {
      throw Exception('需要先登录');
    }

    try {
      final url = Uri.parse(
        '${_config!.serverUrl}/rest/getPlaylists.view'
        '?u=${Uri.encodeComponent(_config!.username)}'
        '&t=$_token'
        '&s=$_salt'
        '&v=1.13.0'
        '&c=myapp'
        '&f=json'
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('获取播放列表失败：HTTP ${response.statusCode}');
      }

      // 使用utf8.decode解决中文乱码问题，并在后台线程解析JSON
      final responseBody = utf8.decode(response.bodyBytes);
      final jsonBody = await compute(jsonDecode, responseBody);
      final subsonic = jsonBody['subsonic-response'];
      if (subsonic['status'] != 'ok') {
        throw Exception('获取播放列表失败：${subsonic['error']?['message'] ?? '未知错误'}');
      }

      final List<dynamic> playlists = subsonic['playlists']['playlist'] as List<dynamic>;
      
      return playlists.map((json) {
        return {
          'id': json['id'],
          'name': json['name'],
          'songCount': json['songCount'],
          'duration': json['duration'],
          'public': json['public'],
          'owner': json['owner'],
          'created': json['created'],
          'changed': json['changed'],
        } as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      debugPrint('getPlaylists error: $e');
      rethrow;
    }
  }
  
  // 获取播放列表中的歌曲
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    if (_config == null || _salt == null || _token == null) {
      throw Exception('需要先登录');
    }

    try {
      final url = Uri.parse(
        '${_config!.serverUrl}/rest/getPlaylist.view'
        '?u=${Uri.encodeComponent(_config!.username)}'
        '&t=$_token'
        '&s=$_salt'
        '&v=1.13.0'
        '&c=myapp'
        '&f=json'
        '&id=$playlistId'
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('获取播放列表歌曲失败：HTTP ${response.statusCode}');
      }

      // 使用utf8.decode解决中文乱码问题，并在后台线程解析JSON
      final responseBody = utf8.decode(response.bodyBytes);
      final jsonBody = await compute(jsonDecode, responseBody);
      final subsonic = jsonBody['subsonic-response'];
      if (subsonic['status'] != 'ok') {
        throw Exception('获取播放列表歌曲失败：${subsonic['error']?['message'] ?? '未知错误'}');
      }

      final List<dynamic> songList = subsonic['playlist']['entry'] as List<dynamic>;
      
      // 在后台线程处理歌曲数据
      final configData = {
        'serverUrl': _config!.serverUrl,
        'username': _config!.username,
        'token': _token,
        'salt': _salt,
      };
      
      final processedSongs = await compute(_processSongs, {
        'songs': songList,
        'config': configData,
      });
      
      return processedSongs.map((data) => Song(
        id: data['id'],
        title: data['title'],
        artist: data['artist'],
        album: data['album'],
        duration: data['duration'],
        url: data['url'],
        coverUrl: data['coverUrl'],
      )).toList();
    } catch (e) {
      debugPrint('getPlaylistSongs error: $e');
      rethrow;
    }
  }
  
  // 在后台线程处理歌曲数据的静态方法
  static List<Map<String, dynamic>> _processSongs(Map<String, dynamic> data) {
    final songs = data['songs'] as List<dynamic>;
    final config = data['config'] as Map<String, dynamic>;
    
    return songs.map((json) => {
      'id': json['id'],
      'title': json['title'],
      'artist': json['artist'],
      'album': json['album'],
      'duration': json['duration'] ?? 0,
      'url': '${config['serverUrl']}/rest/stream.view'
           '?u=${Uri.encodeComponent(config['username'])}'
           '&t=${config['token']}'
           '&s=${config['salt']}'
           '&v=1.13.0'
           '&c=myapp'
           '&id=${json['id']}',
      'coverUrl': json['coverArt'] != null ? 
           '${config['serverUrl']}/rest/getCoverArt.view'
           '?u=${Uri.encodeComponent(config['username'])}'
           '&t=${config['token']}'
           '&s=${config['salt']}'
           '&v=1.13.0'
           '&c=myapp'
           '&id=${json['coverArt']}' : null,
    }).toList();
  }
  
  // 在后台线程处理专辑数据的静态方法
  static List<Map<String, dynamic>> _processAlbums(Map<String, dynamic> data) {
    final albums = data['albums'] as List<dynamic>;
    final config = data['config'] as Map<String, dynamic>;
    
    return albums.map((json) => {
      'id': json['id'],
      'name': json['name'],
      'artist': json['artist'],
      'coverArt': json['coverArt'] != null ?
           '${config['serverUrl']}/rest/getCoverArt.view?id=${json['coverArt']}' : null,
      'songCount': json['songCount'],
    }).toList();
  }
}