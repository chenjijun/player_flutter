import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:async';
import 'dart:math'; // 添加随机数支持
import 'package:rxdart/rxdart.dart';
import '../models/song.dart';

// 播放模式枚举
enum PlayMode {
  sequential,    // 顺序播放
  loop,          // 列表循环
  shuffle,       // 随机播放
  singleLoop     // 单曲循环
}

class AudioHandlerService with ChangeNotifier {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  MediaItem? _currentMediaItem;
  Song? _currentSong;
  
  final _mediaItemController = BehaviorSubject<MediaItem?>();
  final _queueController = BehaviorSubject<List<MediaItem>>();
  final _positionController = StreamController<Duration>.broadcast();
  final _playbackStateController = StreamController<bool>.broadcast();
  final _playModeController = BehaviorSubject<PlayMode>(); // 添加播放模式控制器
  
  // 播放模式
  PlayMode _playMode = PlayMode.loop; // 默认为列表循环
  PlayMode get playMode => _playMode;
  
  // 用于存储随机播放时的原始播放列表
  List<AudioSource> _originalPlaylist = [];

  AudioHandlerService() {
    debugPrint('AudioHandlerService 初始化开始');
    // 初始化播放列表流控制器
    _queueController.add([]);
    _playModeController.add(_playMode); // 初始化播放模式流
    _setupListeners();
    // 初始化播放状态
    _playbackStateController.add(false);
    debugPrint('AudioHandlerService 初始化完成，初始队列长度: ${queue.length}');
  }
  
  void _setupListeners() {
    debugPrint('设置播放器监听器');
    
    // 监听播放位置更新
    _player.positionStream.listen((position) {
      _positionController.add(position);
    });
    
    // 监听播放状态变化
    _player.playerStateStream.listen((state) {
      debugPrint('播放器状态变化: playing=${state.playing}, processingState=${state.processingState}');
      _playbackStateController.add(state.playing);
      // 当播放状态变化时，也发送当前位置更新
      _positionController.add(_player.position);
    });
    
    // 添加一个定时器来确保播放状态更新
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_playbackStateController.hasListener) {
        _playbackStateController.add(_player.playing);
        // 定时发送当前位置更新
        _positionController.add(_player.position);
      }
    });
    
    // 监听当前播放项目变化
    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.length) {
        _currentMediaItem = queue[index];
        _mediaItemController.add(_currentMediaItem);
      } else {
        _currentMediaItem = null;
        _mediaItemController.add(null);
      }
      notifyListeners();
    });
    
    /*
    // 监听播放完成事件，根据播放模式实现自动播放
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        debugPrint('播放完成，当前播放列表长度: ${queue.length}，播放模式: ${_playMode.toString()}');
        
        switch (_playMode) {
          case PlayMode.sequential:
            // 顺序播放，如果当前是最后一首歌，则停止播放
            final currentIndex = _player.currentIndex ?? 0;
            if (currentIndex >= queue.length - 1) {
              // 已经是最后一首歌，停止播放
              debugPrint('顺序播放模式下已播放完所有歌曲，停止播放');
              // 不执行任何操作，让播放自然停止
            } else {
              // 跳转到下一首歌
              skipToNext();
            }
            break;
            
          case PlayMode.loop:
          case PlayMode.shuffle:
          case PlayMode.singleLoop:
            // 列表循环、随机播放和单曲循环模式下都跳转到下一首歌
            // 单曲循环会在just_audio层面处理重复播放当前歌曲
            skipToNext();
            break;
        }
      }
    });
    */
    
    // 监听队列变化
    _queueController.listen((queue) {
      debugPrint('队列控制器监听到变化，新队列长度: ${queue.length}');
    });
  }

  Future<void> playSong(Song song) async {
    debugPrint('开始播放歌曲: ${song.title}, URL: ${song.url}');
    try {
      // 创建MediaItem
      final mediaItem = MediaItem(
        id: song.url,
        title: song.title,
        artist: song.artist ?? '未知艺术家',
        album: song.album ?? '未知专辑',
        duration: Duration(milliseconds: song.duration ?? 0),
        artUri: song.coverUrl != null ? Uri.tryParse(song.coverUrl!) : null,
      );
      
      // 更新当前歌曲
      _currentSong = song;
      _currentMediaItem = mediaItem;
      _mediaItemController.add(mediaItem);
      notifyListeners();
      
      // 检查歌曲是否已经在播放列表中
      final existingIndex = queue.indexWhere((item) => item.id == mediaItem.id);
      debugPrint('检查歌曲是否已在播放列表中，索引: $existingIndex');
      
      if (existingIndex == -1) {
        debugPrint('歌曲不在播放列表中，添加到播放列表');
        // 歌曲不在播放列表中，添加到播放列表
        final audioSource = AudioSource.uri(
          Uri.parse(song.url),
          tag: mediaItem,
        );
        
        await _playlist.add(audioSource);
        debugPrint('添加歌曲到_playlist完成，当前播放列表长度: ${_playlist.sequence.length}');
        
        // 确保播放器有音频源
        if (_player.audioSource == null) {
          debugPrint('播放器无音频源，设置音频源');
          await _player.setAudioSource(_playlist);
        }
        
        // 发送播放列表更新事件
        final updatedQueue = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
        debugPrint('发送播放列表更新到_queueController，项目ID列表: ${updatedQueue.map((e) => e.id).toList()}');
        _queueController.add(updatedQueue);
        
        // 跳转到新添加的歌曲
        final newIndex = _playlist.sequence.length - 1;
        debugPrint('跳转到新添加的歌曲，索引: $newIndex');
        await _player.seek(Duration.zero, index: newIndex);
        
        // 开始播放
        await _player.play();
      } else {
        debugPrint('歌曲已在播放列表中，跳转到该歌曲');
        // 歌曲已在播放列表中，直接跳转到该歌曲
        await _player.seek(Duration.zero, index: existingIndex);
        
        // 如果当前没有在播放，则开始播放
        if (!_player.playing) {
          debugPrint('播放器未在播放状态，开始播放');
          await _player.play();
        }
        
        // 发送播放列表更新事件
        final updatedQueue = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
        debugPrint('发送播放列表更新到_queueController，项目ID列表: ${updatedQueue.map((e) => e.id).toList()}');
        _queueController.add(updatedQueue);
      }
      
      // 确保播放状态更新
      await Future.delayed(const Duration(milliseconds: 100));
      _playbackStateController.add(_player.playing);
      notifyListeners();
    } catch (e) {
      debugPrint('播放歌曲失败: $e');
      rethrow;
    }
  }
  
  // 播放控制方法
  Future<void> play() async {
    try {
      // 确保播放器有音频源再播放
      if (_player.audioSource == null) {
        if (queue.isNotEmpty) {
          // 设置播放源为当前播放列表
          await _player.setAudioSource(_playlist);
        } else if (_currentMediaItem != null) {
          // 如果队列为空但有当前媒体项，创建单曲播放
          final mediaItem = _currentMediaItem!;
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(mediaItem.id),
              tag: mediaItem,
            ),
          );
        }
      }
      
      // 播放音频
      await _player.play();
      
      // 根据播放模式设置播放器循环模式
      switch (_playMode) {
        case PlayMode.singleLoop:
          await _player.setLoopMode(LoopMode.one);
          break;
        case PlayMode.sequential:
        case PlayMode.loop:
        case PlayMode.shuffle:
          await _player.setLoopMode(LoopMode.all);
          break;
      }
      
      // 确保在播放时发送当前位置更新
      _positionController.add(_player.position);
      
      // 通知监听器状态变化
      notifyListeners();
      // 强制更新所有状态流
      forceUpdateStreams();
    } catch (e) {
      debugPrint('播放失败: $e');
      rethrow;
    }
  }
  
  Future<void> pause() async {
    await _player.pause();
    // 确保在暂停时发送当前位置更新
    _positionController.add(_player.position);
    notifyListeners();
    // 强制更新所有状态流
    forceUpdateStreams();
  }
  
  Future<void> stop() async {
    await _player.stop();
    notifyListeners();
  }
  
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    // 确保在跳转位置后发送当前位置更新
    _positionController.add(position);
  }
  
  // 强制更新所有状态流
  void forceUpdateStreams() {
    // 发送当前位置更新
    _positionController.add(_player.position);
    // 发送播放状态更新
    _playbackStateController.add(_player.playing);
    // 发送媒体项更新
    _mediaItemController.add(_currentMediaItem);
    // 发送队列更新
    final updatedQueue = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
    _queueController.add(updatedQueue);
  }
  
  Future<void> skipToQueueItem(int index) async {
    debugPrint('尝试跳转到播放列表索引: $index, 当前播放列表长度: ${queue.length}');
    if (index >= 0 && index < queue.length) {
      debugPrint('执行跳转到索引: $index');
      await _player.seek(Duration.zero, index: index);
      
      // 根据播放模式设置播放器循环模式
      switch (_playMode) {
        case PlayMode.singleLoop:
          await _player.setLoopMode(LoopMode.one);
          break;
        case PlayMode.sequential:
        case PlayMode.loop:
        case PlayMode.shuffle:
          await _player.setLoopMode(LoopMode.all);
          break;
      }
      
      // 确保在跳转后发送当前位置更新
      _positionController.add(Duration.zero);
      
      // 如果当前没有在播放，则开始播放
      if (!_player.playing) {
        debugPrint('播放器未在播放状态，开始播放');
        await _player.play();
      }
      
      // 发送播放列表更新事件，确保UI知道当前播放的歌曲
      final updatedQueue = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
      debugPrint('发送播放列表更新到_queueController，项目ID列表: ${updatedQueue.map((e) => e.id).toList()}');
      _queueController.add(updatedQueue);
      notifyListeners();
    } else {
      debugPrint('索引超出范围，无法跳转');
    }
  }
  
  Future<void> skipToNext() async {
    if (queue.length > 0) {
      final currentIndex = _player.currentIndex ?? 0;
      
      int nextIndex;
      switch (_playMode) {
        case PlayMode.sequential:
          // 顺序播放
          if (currentIndex >= queue.length - 1) {
            // 已经是最后一首歌，停止播放
            debugPrint('顺序播放模式下已到达列表末尾，停止播放');
            await _player.pause(); // 暂停播放而不是继续
            return;
          }
          nextIndex = currentIndex + 1;
          break;
          
        case PlayMode.loop:
          // 列表循环
          nextIndex = (currentIndex + 1) % queue.length;
          break;
          
        case PlayMode.shuffle:
          // 随机播放
          nextIndex = _getRandomIndex(currentIndex);
          break;
          
        case PlayMode.singleLoop:
          // 单曲循环，继续播放当前歌曲
          nextIndex = currentIndex;
          break;
          
        default:
          nextIndex = (currentIndex + 1) % queue.length;
      }
      
      await skipToQueueItem(nextIndex);
    }
  }
  
  // 获取随机索引的辅助方法
  int _getRandomIndex(int currentIndex) {
    if (queue.length <= 1) return currentIndex;
    
    int randomIndex;
    do {
      randomIndex = Random().nextInt(queue.length);
    } while (randomIndex == currentIndex && queue.length > 1);
    
    return randomIndex;
  }
  
  Future<void> skipToPrevious() async {
    if (queue.length > 0) {
      final currentIndex = _player.currentIndex ?? 0;
      final prevIndex = (currentIndex - 1 + queue.length) % queue.length;
      await skipToQueueItem(prevIndex);
    }
  }
  
  // 队列操作方法
  Future<void> addQueueItem(MediaItem mediaItem) async {
    debugPrint('添加单个歌曲到播放列表: ${mediaItem.title}');
    // 检查歌曲是否已经在播放列表中
    final existingIndex = queue.indexWhere((item) => item.id == mediaItem.id);
    if (existingIndex == -1) {
      final audioSource = AudioSource.uri(
        Uri.parse(mediaItem.id),
        tag: mediaItem,
      );
      
      await _playlist.add(audioSource);
      debugPrint('添加歌曲到播放列表完成，当前播放列表长度: ${_playlist.sequence.length}');
      
      // 确保播放器有音频源
      if (_player.audioSource == null) {
        debugPrint('播放器无音频源，设置音频源');
        await _player.setAudioSource(_playlist);
      }
      
      // 发送播放列表更新事件
      final updatedQueue = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
      debugPrint('发送播放列表更新到_queueController，项目ID列表: ${updatedQueue.map((e) => e.id).toList()}');
      _queueController.add(updatedQueue);
      notifyListeners();
    } else {
      debugPrint('歌曲已在播放列表中，跳过添加');
    }
  }
  
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final newItems = <AudioSource>[];
    
    for (final item in mediaItems) {
      // 检查每首歌曲是否已经在播放列表中
      final existingIndex = queue.indexWhere((queueItem) => queueItem.id == item.id);
      if (existingIndex == -1) {
        newItems.add(AudioSource.uri(
          Uri.parse(item.id),
          tag: item,
        ));
      }
    }
    
    if (newItems.isNotEmpty) {
      await _playlist.addAll(newItems);
      
      // 更新播放源以确保播放列表更新
      if (_player.audioSource != _playlist) {
        await _player.setAudioSource(_playlist);
      }
      
      // 如果当前是随机播放模式，保存原始播放列表
      if (_playMode == PlayMode.shuffle) {
        _originalPlaylist = List.from(_playlist.children);
      }
      
      // 发送播放列表更新事件
      final updatedQueue = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
      debugPrint('发送播放列表更新到_queueController，项目ID列表: ${updatedQueue.map((e) => e.id).toList()}');
      _queueController.add(updatedQueue);
      notifyListeners();
    } else {
      debugPrint('没有新歌曲添加到播放列表');
    }
  }
  
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = queue.indexWhere((item) => item.id == mediaItem.id);
    if (index != -1) {
      await _playlist.removeAt(index);
      _queueController.add(_playlist.sequence.map((source) => source.tag as MediaItem).toList());
      notifyListeners();
    }
  }
  
  Future<void> clearQueue() async {
    await _playlist.clear();
    _queueController.add([]);
    notifyListeners();
  }
  
  // 属性获取方法
  Song? get current => _currentSong;
  
  set current(Song? song) {
    _currentSong = song;
    notifyListeners();
  }
  
  // 流暴露
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<MediaItem?> get mediaItemStream => _mediaItemController.stream;
  Stream<List<MediaItem>> get queueStream => _queueController.stream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playbackStateStream => _playbackStateController.stream;
  Stream<PlayMode> get playModeStream => _playModeController.stream; // 添加播放模式流
  
  // 简单属性
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _player.playing;
  List<MediaItem> get queue {
    final items = _playlist.sequence.map((source) => source.tag as MediaItem).toList();
    debugPrint('获取播放列表，当前长度: ${items.length}，项目ID列表: ${items.map((e) => e.id).toList()}');
    return items;
  }
  
  // 释放资源
  void dispose() {
    debugPrint('释放AudioHandlerService资源');
    _positionController.close();
    _mediaItemController.close();
    _queueController.close();
    _playbackStateController.close();
    _playModeController.close(); // 关闭播放模式控制器
    _player.dispose();
    super.dispose();
  }
  
  // 设置播放模式
  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    
    // 更新播放模式流
    _playModeController.add(mode);
    
    // 不再直接修改播放器的循环模式，让播放逻辑根据_playMode来决定行为
    notifyListeners();
  }
  
  // 切换到下一个播放模式
  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.loop:
        setPlayMode(PlayMode.singleLoop);
        break;
      case PlayMode.singleLoop:
        setPlayMode(PlayMode.shuffle);
        break;
      case PlayMode.shuffle:
        setPlayMode(PlayMode.sequential);
        break;
      case PlayMode.sequential:
        setPlayMode(PlayMode.loop);
        break;
    }
  }
}