import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/song.dart';
import 'audio_background.dart';

import 'dart:async';
import 'notification_service.dart';

class AudioHandlerService with ChangeNotifier {
  final _player = AudioPlayer();
  Song? _current;
  BackgroundAudioHandler? backgroundHandler;
  StreamSubscription<PlaybackEvent>? _eventSub;

  Song? get current => _current;
  
  set current(Song? song) {
    _current = song;
    notifyListeners();
  }

  Future<void> playSong(Song s) async {
    _current = s;
    try {
      // 检查是否启用了缓存
      final cacheEnabled = backgroundHandler?.cacheService.cacheEnabled ?? false;
      
      // 检查当前播放的是否是同一首歌曲
      bool isSameSong = backgroundHandler?.mediaItem.value?.id == s.url;
      
      if (!isSameSong) {
        if (cacheEnabled) {
          // 如果启用了缓存，先尝试从缓存加载
          final file = await DefaultCacheManager().getSingleFile(s.url);
          await _player.setFilePath(file.path);
        } else {
          // 否则直接从网络播放
          await _player.setUrl(s.url);
        }
        
        // 在后台isolate中创建MediaItem以避免阻塞UI线程
        final media = await compute(_createMediaItem, s);
        
        // add to handler queue (and update mediaItem stream)
        if (backgroundHandler != null) {
          // 检查队列中是否已存在该歌曲
          final queue = backgroundHandler!.queue.value;
          final existingIndex = queue.indexWhere((item) => item.id == s.url);
          
          if (existingIndex != -1) {
            // 如果歌曲已在队列中，跳转到该歌曲
            await backgroundHandler!.skipToQueueItem(existingIndex);
          } else {
            // 否则添加到队列
            await backgroundHandler!.addQueueItem(media);
          }
        }
      } else {
        // 如果是同一首歌曲，直接播放
        await _player.play();
      }
      
      // start playing
      await _player.play();
      // 所有操作完成后通知监听器
      notifyListeners();
    } catch (e) {
      debugPrint('playSong error: $e');
      rethrow;
    }
  }

  Future<void> playSongFromMediaItem(MediaItem mediaItem) async {
    try {
      // 检查当前播放的是否是同一首歌曲
      bool isSameSong = backgroundHandler?.mediaItem.value?.id == mediaItem.id;
      
      if (!isSameSong) {
        // 检查是否启用了缓存
        final cacheEnabled = backgroundHandler?.cacheService.cacheEnabled ?? false;
        
        if (cacheEnabled) {
          // 如果启用了缓存，先尝试从缓存加载
          final file = await DefaultCacheManager().getSingleFile(mediaItem.id);
          await _player.setFilePath(file.path);
        } else {
          // 否则直接从网络播放
          await _player.setUrl(mediaItem.id);
        }
        
        // add to handler queue (and update mediaItem stream)
        if (backgroundHandler != null) {
          // 检查队列中是否已存在该歌曲
          final queue = backgroundHandler!.queue.value;
          final existingIndex = queue.indexWhere((item) => item.id == mediaItem.id);
          
          if (existingIndex != -1) {
            // 如果歌曲已在队列中，跳转到该歌曲
            await backgroundHandler!.skipToQueueItem(existingIndex);
          } else {
            // 否则添加到队列
            await backgroundHandler!.addQueueItem(mediaItem);
          }
        }
      } else {
        // 如果是同一首歌曲，直接播放
        await _player.play();
      }
      
      // start playing
      await _player.play();
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

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    notifyListeners();
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

  // Streams exposed for UI
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<List<MediaItem>> get queueStream => backgroundHandler?.queue ?? Stream.value(<MediaItem>[]);

  Future<void> addToQueue(MediaItem item) async {
    if (backgroundHandler != null) {
      await backgroundHandler!.addQueueItem(item);
    }
  }

  Future<void> removeFromQueue(MediaItem item) async {
    if (backgroundHandler != null) {
      await backgroundHandler!.removeQueueItem(item);
    }
  }

  Future<void> moveInQueue(MediaItem item, int newIndex) async {
    if (backgroundHandler != null) {
      await backgroundHandler!.moveQueueItem(item, newIndex);
    }
  }

  Future<void> clearQueue() async {
    if (backgroundHandler != null) {
      // 清空播放队列
      await backgroundHandler!.clearQueue();
      
      // 重置当前播放状态
      _current = null;
      
      // 停止播放并重置播放器状态
      await _player.stop();
      await _player.setAudioSource(ConcatenatingAudioSource(children: []));
      
      // 通知UI更新
      notifyListeners();
    }
  }

  // Internal: broadcast just_audio events to background handler
  void _bindBackground() {
    if (backgroundHandler == null) return;
    _eventSub?.cancel();
    _eventSub = _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = event.processingState;
      AudioProcessingState audioState = AudioProcessingState.idle;
      switch (processingState) {
        case ProcessingState.idle:
          audioState = AudioProcessingState.idle;
          break;
        case ProcessingState.loading:
          audioState = AudioProcessingState.loading;
          break;
        case ProcessingState.buffering:
          audioState = AudioProcessingState.buffering;
          break;
        case ProcessingState.ready:
          audioState = AudioProcessingState.ready;
          break;
        case ProcessingState.completed:
          audioState = AudioProcessingState.completed;
          break;
      }

      // 检查是否播放完成
      bool isPlaying = _player.playing;
      if (processingState == ProcessingState.completed) {
        isPlaying = false;
      }

      backgroundHandler?.playbackState.add(PlaybackState(
        controls: [
          MediaControl.pause,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: audioState,
        playing: isPlaying,
        updatePosition: _player.position,
      ));
      // Update system notification
      final currentMedia = backgroundHandler?.mediaItem.valueOrNull;
      if (currentMedia != null) {
        // 只有在播放时才显示通知
        if (isPlaying) {
          NotificationService.showNotification(currentMedia);
        } else if (processingState == ProcessingState.completed) {
          // 播放完成时清除通知
          NotificationService.hideNotification();
        }
      }
    });
  }

  Future<void> initBackgroundServiceBound() async {
    // 直接在主isolate中初始化背景服务，不要使用compute
    backgroundHandler = await initBackground() as BackgroundAudioHandler;
    _bindBackground();
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
      _bindBackground();
    } catch (e) {
      debugPrint('Failed to initialize background audio service: $e');
    }
  }
}