import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import 'audio_background.dart';

class AudioHandlerService with ChangeNotifier {
  BackgroundAudioHandler? _audioHandler;
  Song? _currentSong;
  
  // 初始化音频服务
  Future<void> initialize() async {
    _audioHandler = await initAudioService() as BackgroundAudioHandler;
    _setupListeners();
  }

  void _setupListeners() {
    _audioHandler?.playbackState.listen((state) {
      notifyListeners();
    });
    
    _audioHandler?.mediaItem.listen((mediaItem) {
      // 可以在这里同步_currentSong
      notifyListeners();
    });
  }

  Future<void> playSong(Song song) async {
    if (_audioHandler == null) {
      await initialize();
    }
    
    _currentSong = song;
    
    try {
      // 创建MediaItem（不需要compute，很简单）
      final mediaItem = MediaItem(
        id: song.url,
        album: song.album ?? '',
        title: song.title,
        artist: song.artist,
        artUri: (song.coverUrl != null && song.coverUrl!.isNotEmpty) 
            ? Uri.parse(song.coverUrl!) 
            : null,
        duration: Duration(seconds: song.duration),
      );
      
      // 将新歌曲添加到队列顶部
      await _audioHandler!.addQueueItem(mediaItem);
      
      // 等待队列更新完成
      await Future.delayed(Duration(milliseconds: 100));
      
      // 播放队列中的第一首歌曲
      await _audioHandler!.skipToQueueItem(0);
      
      notifyListeners();
    } catch (e) {
      debugPrint('playSong error: $e');
      rethrow;
    }
  }

  // 添加队列项目
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _audioHandler?.addQueueItem(mediaItem);
  }

  // 更新队列
  Future<void> updateQueue(List<MediaItem> queue) async {
    await _audioHandler?.updateQueue(queue);
  }

  // 简化的播放控制 - 全部委托给audio_handler
  Future<void> play() async => await _audioHandler?.play();
  Future<void> pause() async => await _audioHandler?.pause();
  Future<void> seek(Duration position) async => await _audioHandler?.seek(position);
  Future<void> skipToNext() async => await _audioHandler?.skipToNext();
  Future<void> skipToPrevious() async => await _audioHandler?.skipToPrevious();
  Future<void> stop() async => await _audioHandler?.stop();
  Future<void> skipToQueueItem(int index) async => await _audioHandler?.skipToQueueItem(index);
  Future<void> removeQueueItem(MediaItem mediaItem) async => await _audioHandler?.removeQueueItem(mediaItem);
  Future<void> clearQueue() async => await _audioHandler?.updateQueue([]);

  // 状态获取 - 从audio_handler获取真实状态
  bool get isPlaying => _audioHandler?.playbackState.value.playing ?? false;
  Song? get current => _currentSong;
  set current(Song? song) {
    _currentSong = song;
    notifyListeners();
  }
  
  // 流暴露
  Stream<PlaybackState> get playbackStateStream => 
      _audioHandler?.playbackState ?? const Stream.empty();
  Stream<MediaItem?> get mediaItemStream => 
      _audioHandler?.mediaItem ?? const Stream.empty();
  Stream<Duration> get positionStream => 
      _audioHandler?.playbackState.map((state) => state.position) ?? const Stream.empty();
  Stream<Duration?> get durationStream => 
      _audioHandler?.mediaItem.map((item) => item?.duration) ?? const Stream.empty();
  Stream<List<MediaItem>> get queueStream => 
      _audioHandler?.queueStream ?? const Stream.empty();

  void dispose() {
    _audioHandler?.stop();
    super.dispose();
  }
}

/// Initialize background audio service. Returns the created AudioHandler.
Future<AudioHandler> initBackground() async {
  final handler = await initAudioService();
  return handler;
}