import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../services/database_service.dart';
import '../widgets/track_tile.dart';
import '../models/song.dart';

class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({super.key});

  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
  List<MediaItem> _cachedSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCachedSongs();
  }

  Future<void> _loadCachedSongs() async {
    try {
      final songs = await DatabaseService().getPlaylistSongs();
      setState(() {
        _cachedSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载缓存歌曲失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '本地音乐',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_cachedSongs.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  '暂无缓存歌曲',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _cachedSongs.length,
                itemBuilder: (context, index) {
                  final mediaItem = _cachedSongs[index];
                  return TrackTile(
                    title: mediaItem.title,
                    subtitle: mediaItem.artist ?? '未知艺术家',
                    coverUrl: mediaItem.artUri?.toString(),
                    onTap: () {
                      final audioHandler = context.read<AudioHandlerService>();
                      // 将MediaItem转换为Song对象
                      final song = Song(
                        id: mediaItem.id.hashCode.toString(), // 生成一个唯一的ID
                        title: mediaItem.title,
                        artist: mediaItem.artist ?? '',
                        album: mediaItem.album ?? '',
                        url: mediaItem.id, // 使用id作为url
                        coverUrl: mediaItem.artUri?.toString(),
                        duration: mediaItem.duration?.inSeconds ?? 0,
                      );
                      audioHandler.playSong(song);

                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}