import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/song.dart';
import 'audio_background.dart';

import 'dart:async';

class AudioHandlerService with ChangeNotifier {
  final _player = AudioPlayer();
  Song? _current;
  BackgroundAudioHandler? backgroundHandler;
  StreamSubscription<PlaybackEvent>? _eventSub;

  // 添加一个播放状态变量来跟踪播放状态
  bool _isPlaying = false;
  
  bool get isPlaying => _isPlaying;

  Song? get current => _current;
  
  set current(Song? song) {
    _current = song;
    notifyListeners();
  }

  // 添加播放状态流
  Stream<bool> get playingStream => _player.playingStream;

  // 添加位置和持续时间流
  Stream<Duration> get positionStream => _player.positionStream;
  
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> playSong(Song s) async {
    _current = s;
    try {
      // 检查播放器当前状态，如果正在播放则先停止
      if (_player.playing) {
        await _player.stop();
      }
      
      // 检查是否启用了缓存
      final cacheEnabled = backgroundHandler?.cacheService.cacheEnabled ?? false;
      
      // 在后台isolate中创建MediaItem以避免阻塞UI线程
      final media = await compute(_createMediaItem, s);
      
      // 先添加到播放列表
      if (backgroundHandler != null) {
        // 检查队列中是否已存在该歌曲
        final queue = backgroundHandler!.queue.value;
        final existingIndex = queue.indexWhere((item) => item.id == s.url);
        
        if (existingIndex != -1) {
          // 如果歌曲已在队列中，跳转到该歌曲
          await backgroundHandler!.skipToQueueItem(existingIndex);
          return;
        } else {
          // 否则添加到队列
          await backgroundHandler!.addQueueItem(media);
        }
      }
      
      // 设置播放源并开始播放
      if (cacheEnabled) {
        // 如果启用了缓存，先尝试从缓存加载
        final file = await DefaultCacheManager().getSingleFile(s.url);
        await _player.setFilePath(file.path);
      } else {
        // 否则直接从网络播放
        await _player.setUrl(s.url);
      }
      
      // start playing
      await _player.play();
      _isPlaying = true;
      // 所有操作完成后通知监听器
      notifyListeners();
    } catch (e) {
      debugPrint('playSong error: $e');
      rethrow;
    }
  }

  Future<void> playSongFromMediaItem(MediaItem mediaItem) async {
    try {
      // 检查播放器当前状态，如果正在播放则先停止
      if (_player.playing) {
        await _player.stop();
      }
      
      // 检查是否启用了缓存
      final cacheEnabled = backgroundHandler?.cacheService.cacheEnabled ?? false;
      
      // add to handler queue (and update mediaItem stream)
      if (backgroundHandler != null) {
        // 检查队列中是否已存在该歌曲
        final queue = backgroundHandler!.queue.value;
        final existingIndex = queue.indexWhere((item) => item.id == mediaItem.id);
        
        if (existingIndex != -1) {
          // 如果歌曲已在队列中，跳转到该歌曲
          await backgroundHandler!.skipToQueueItem(existingIndex);
          return;
        } else {
          // 否则添加到队列
          await backgroundHandler!.addQueueItem(mediaItem);
        }
      }
      
      // 设置播放源并开始播放
      if (cacheEnabled) {
        // 如果启用了缓存，先尝试从缓存加载
        final file = await DefaultCacheManager().getSingleFile(mediaItem.id);
        await _player.setFilePath(file.path);
      } else {
        // 否则直接从网络播放
        await _player.setUrl(mediaItem.id);
      }
      
      // start playing
      await _player.play();
      _isPlaying = true;
      // 所有操作完成后通知监听器
      notifyListeners();
    } catch (e) {
      debugPrint('playSongFromMediaItem error: $e');
      rethrow;
    }
  }

  /// 在后台isolate中运行的静态方法，用于创建MediaItem。
  static MediaItem _createMediaItem(Song song) {
    return MediaItem(
      id: song.url,
      album: song.album ?? '',
      title: song.title,
      artist: song.artist,
      artUri: (song.coverUrl != null && song.coverUrl!.isNotEmpty) ? Uri.parse(song.coverUrl!) : null,
    );
  }

  Future<void> playAlbum(String albumId) async {
    // 这里应该调用NavidromeService获取专辑歌曲并播放
    // 但由于AudioHandlerService不应该直接依赖NavidromeService
    // 所以这个方法需要在调用处实现具体逻辑
    debugPrint('playAlbum called with albumId: $albumId');
  }

  Future<void> play() async {
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> skipToNext() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      debugPrint('skipToNext error $e');
    }
  }

  Future<void> skipToPrevious() async {
    try {
      await _player.seekToPrevious();
    } catch (e) {
      debugPrint('skipToPrevious error $e');
    }
  }

  Future<void> refreshState() async {
    // 通知监听器刷新UI状态
    notifyListeners();
    
    // 如果有后台服务，也通知它刷新状态
    if (backgroundHandler != null) {
      backgroundHandler!.playbackState.add(backgroundHandler!.playbackState.value);
      if (backgroundHandler!.mediaItem.value != null) {
        backgroundHandler!.mediaItem.add(backgroundHandler!.mediaItem.value!);
      }
    }
  }

  // Streams exposed for UI
  Stream<Duration> get bufferingStream => _player.bufferedPositionStream;

  void dispose() {
    _player.dispose();
    _eventSub?.cancel();
    super.dispose();
  }
}

/// Initialize background audio service. Returns the created AudioHandler.
Future<AudioHandler> initBackground() async {
  final handler = await initAudioService();
  return handler;
}

/// Start and keep a reference to background AudioHandler on this service.
extension AudioHandlerServiceBackground on AudioHandlerService {
  Future<void> initBackgroundService() async {
    try {
      backgroundHandler = await initBackground() as BackgroundAudioHandler;
    } catch (e) {
      debugPrint('Failed to initialize background audio service: $e');
    }
  }
}