import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:async';
import '../models/song.dart';

class AudioHandlerService with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  Song? _currentSong;
  MediaItem? _currentMediaItem;
  
  // 流控制器
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<MediaItem?> _mediaItemController = StreamController<MediaItem?>.broadcast();
  final StreamController<List<MediaItem>> _queueController = StreamController<List<MediaItem>>.broadcast();
  final StreamController<bool> _playbackStateController = StreamController<bool>.broadcast();
  
  AudioHandlerService() {
    _setupListeners();
  }
  
  void _setupListeners() {
    // 监听播放位置更新
    _player.positionStream.listen((position) {
      _positionController.add(position);
    });
    
    // 监听播放状态变化
    _player.playerStateStream.listen((state) {
      _playbackStateController.add(state.playing);
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
  }

  Future<void> playSong(Song song) async {
    _currentSong = song;
    
    try {
      // 创建MediaItem
      final mediaItem = MediaItem(
        id: song.url,
        album: song.album ?? '',
        title: song.title,
        artist: song.artist,
        artUri: (song.coverUrl != null && song.coverUrl!.isNotEmpty) 
            ? Uri.parse(song.coverUrl!) 
            : null,
        duration: Duration(milliseconds: song.duration * 1000),
      );
      
      // 检查歌曲是否已经在播放列表中
      final existingIndex = queue.indexWhere((item) => item.id == mediaItem.id);
      
      if (existingIndex != -1) {
        // 如果歌曲已存在，直接跳转到该歌曲
        await skipToQueueItem(existingIndex);
      } else {
        // 如果歌曲不存在，添加到播放列表开头
        await _playlist.insert(0, AudioSource.uri(
          Uri.parse(song.url),
          tag: mediaItem,
        ));
        
        // 设置音频源
        await _player.setAudioSource(_playlist);
        
        // 跳转到第一首歌曲（新添加的歌曲）
        await skipToQueueItem(0);
      }
      
      // 开始播放
      play();
      
      // 更新状态
      _currentMediaItem = mediaItem;
      _mediaItemController.add(mediaItem);
      _queueController.add(queue);
      notifyListeners();
    } catch (e) {
      debugPrint('播放歌曲失败: $e');
    }
  }
  
  // 播放控制方法
  Future<void> play() async {
    await _player.play();
    notifyListeners();
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
  }
  
  Future<void> skipToNext() async {
    await _player.seekToNext();
  }
  
  Future<void> skipToPrevious() async {
    await _player.seekToPrevious();
  }
  
  // 队列操作方法
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _playlist.add(AudioSource.uri(
      Uri.parse(mediaItem.id),
      tag: mediaItem,
    ));
    _queueController.add(queue);
    notifyListeners();
  }
  
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final sources = mediaItems.map((item) => AudioSource.uri(
      Uri.parse(item.id),
      tag: item,
    )).toList();
    
    await _playlist.addAll(sources);
    _queueController.add(queue);
    notifyListeners();
  }
  
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = queue.indexWhere((item) => item.id == mediaItem.id);
    if (index != -1) {
      await _playlist.removeAt(index);
      _queueController.add(queue);
      notifyListeners();
    }
  }
  
  Future<void> clearQueue() async {
    await _playlist.clear();
    _queueController.add([]);
    notifyListeners();
  }
  
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.length) {
      await _player.seek(Duration.zero, index: index);
    }
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
  
  // 简单属性
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _player.playing;
  List<MediaItem> get queue => _playlist.sequence.map((source) => source.tag as MediaItem).toList();
  
  // 释放资源
  void dispose() {
    _positionController.close();
    _mediaItemController.close();
    _queueController.close();
    _playbackStateController.close();
    _player.dispose();
    super.dispose();
  }
}