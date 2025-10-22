import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'cache_service.dart';

/// Background audio handler that bridges just_audio with audio_service.
class BackgroundAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  final cacheService = CacheService();
  StreamSubscription<PlaybackEvent>? _eventSub;

  BackgroundAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // 初始化缓存服务
    await cacheService.init();
    
    // Load empty playlist initially
    await _player.setAudioSource(_playlist, preload: false);

    // Listen to player events and broadcast playbackState
    _eventSub = _player.playbackEventStream.listen((event) {
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
        // 播放完成时自动播放下一首
        _playNextAutomatically();
      }

      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: audioState,
        playing: isPlaying,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
      ));
    });

    // Listen to sequence updates
    _player.sequenceStream.listen((sequence) {
      final items = sequence?.map((s) => s.tag as MediaItem).toList() ?? <MediaItem>[];
      queue.value = items;
    });

    // Listen to current item updates
    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      } else {
        mediaItem.add(null);
      }
    });
    
    // 初始化播放状态
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
    ));
  }

  /// 播放完成时自动播放下一首歌曲
  Future<void> _playNextAutomatically() async {
    try {
      // 获取当前播放索引
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && currentIndex < queue.value.length - 1) {
        // 还有下一首歌曲，自动播放
        await skipToNext();
      } else if (currentIndex != null && currentIndex == queue.value.length - 1) {
        // 已经是最后一首歌曲，停止播放
        await stop();
      }
    } catch (e) {
      debugPrint('自动播放下一首歌曲失败: $e');
    }
  }

  @override
  Future<void> play() async {
    if (_player.playing) {
      // 如果已经在播放，则先暂停再播放，确保状态正确
      await _player.pause();
    }
    
    // 确保音频源已加载
    if (_playlist.length > 0 && _player.audioSource == null) {
      await _player.setAudioSource(_playlist, initialIndex: 0, preload: true);
    }
    
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _playlist.clear();
    queue.add([]);
    mediaItem.add(null);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _player.seekToPrevious();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // 检查队列中是否已存在相同的歌曲
    final existingIndex = queue.value.indexWhere((item) => item.id == mediaItem.id);
    
    if (existingIndex != -1) {
      // 如果歌曲已存在，移除它
      final list = List<MediaItem>.from(queue.value);
      list.removeAt(existingIndex);
      
      // 将歌曲添加到队列顶部
      list.insert(0, mediaItem);
      queue.add(list);
      
      // 更新播放列表
      List<AudioSource> sources = [];
      for (var item in list) {
        if (cacheService.cacheEnabled) {
          // 如果启用了缓存，使用缓存管理器
          final file = await DefaultCacheManager().getSingleFile(item.id);
          sources.add(AudioSource.file(file.path, tag: item));
        } else {
          // 否则直接使用URL
          sources.add(AudioSource.uri(Uri.parse(item.id), tag: item));
        }
      }
      
      await _playlist.clear();
      await _playlist.addAll(sources);
      await _player.setAudioSource(_playlist);
      return;
    }
    
    // 歌曲不存在于队列中，添加到队列顶部
    final list = List<MediaItem>.from(queue.value);
    list.insert(0, mediaItem);
    queue.add(list);
    
    AudioSource source;
    if (cacheService.cacheEnabled) {
      // 如果启用了缓存，使用缓存管理器
      final file = await DefaultCacheManager().getSingleFile(mediaItem.id);
      source = AudioSource.file(file.path, tag: mediaItem);
    } else {
      // 否则直接使用URL
      source = AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem);
    }
    
    // 添加到播放列表的开头
    await _playlist.insert(0, source);
    await _player.setAudioSource(_playlist);
    
    // 如果当前没有播放，开始播放第一首歌曲
    if (!_player.playing && queue.value.length == 1) {
      this.mediaItem.add(mediaItem);
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final updated = List<MediaItem>.from(queue.value)..addAll(mediaItems);
    queue.add(updated);
    
    List<AudioSource> sources = [];
    for (var mediaItem in mediaItems) {
      if (cacheService.cacheEnabled) {
        // 如果启用了缓存，使用缓存管理器
        final file = await DefaultCacheManager().getSingleFile(mediaItem.id);
        sources.add(AudioSource.file(file.path, tag: mediaItem));
      } else {
        // 否则直接使用URL
        sources.add(AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem));
      }
    }
    
    await _playlist.addAll(sources);
    
    // 更新播放器的音频源
    await _player.setAudioSource(_playlist);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final list = List<MediaItem>.from(queue.value);
    final index = list.indexWhere((m) => m.id == mediaItem.id);
    if (index != -1) {
      list.removeAt(index);
      queue.add(list);
      
      // 更新播放列表
      await _playlist.removeAt(index);
      
      // 如果删除的是当前播放的歌曲，停止播放
      if (_player.currentIndex == index) {
        await stop();
        // 如果还有其他歌曲，播放下一首
        if (list.isNotEmpty) {
          if (index < list.length) {
            await skipToQueueItem(index);
          } else {
            await skipToQueueItem(0);
          }
        }
      }
    }
  }

  @override
  Future<void> moveQueueItem(MediaItem mediaItem, int newIndex) async {
    final list = List<MediaItem>.from(queue.value);
    final from = list.indexWhere((m) => m.id == mediaItem.id);
    if (from != -1) {
      list.removeAt(from);
      list.insert(newIndex, mediaItem);
      queue.add(list);
      
      List<AudioSource> sources = [];
      for (var item in list) {
        if (cacheService.cacheEnabled) {
          // 如果启用了缓存，使用缓存管理器
          final file = await DefaultCacheManager().getSingleFile(item.id);
          sources.add(AudioSource.file(file.path, tag: item));
        } else {
          // 否则直接使用URL
          sources.add(AudioSource.uri(Uri.parse(item.id), tag: item));
        }
      }
      
      // 获取当前播放索引
      final currentIndex = _player.currentIndex;
      final newPlaylist = ConcatenatingAudioSource(children: sources);
      await _player.setAudioSource(newPlaylist);
      
      // 如果当前正在播放的项目被移动了，需要更新播放索引
      if (currentIndex != null && from == currentIndex) {
        // 如果项目移动到了新的位置，跳转到新位置
        await _player.seek(Duration.zero, index: newIndex);
      } else if (currentIndex != null) {
        // 如果播放列表发生变化，确保索引仍然有效
        if (newIndex < currentIndex && from >= currentIndex) {
          // 项目从后面移到了前面，且原索引大于等于当前索引
          await _player.seek(Duration.zero, index: currentIndex - 1);
        } else if (newIndex >= currentIndex && from < currentIndex) {
          // 项目从前面移到了后面，且原索引小于当前索引
          await _player.seek(Duration.zero, index: currentIndex + 1);
        }
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    
    // 检查播放器当前状态，如果正在播放则先暂停
    if (_player.playing) {
      await _player.pause();
    }
    
    // 跳转到指定索引
    await _player.seek(Duration.zero, index: index);
    await play();
    
    // 更新当前媒体项
    if (index < queue.value.length) {
      mediaItem.add(queue.value[index]);
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
  }
  
  Future<void> clearQueue() async {
    // 停止播放
    await _player.stop();
    
    // 清空播放列表
    await _playlist.clear();
    
    // 清空队列
    queue.add(<MediaItem>[]);
    
    // 清空当前媒体项
    mediaItem.add(null);
    
    // 显式重置播放状态
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
    ));
  }

  // 添加获取队列流的方法
  Stream<List<MediaItem>> get queueStream => queue.stream;
}

/// Initialize audio service and return an [AudioHandler].
Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => BackgroundAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.player.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}