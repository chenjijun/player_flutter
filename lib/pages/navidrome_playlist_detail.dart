import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/navidrome_service.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import 'package:audio_service/audio_service.dart';

class NavidromePlaylistDetailPage extends StatefulWidget {
  final String playlistId;
  final String playlistName;
  final NavidromeService navidromeService;

  const NavidromePlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.navidromeService,
  });

  @override
  State<NavidromePlaylistDetailPage> createState() => _NavidromePlaylistDetailPageState();
}

class _NavidromePlaylistDetailPageState extends State<NavidromePlaylistDetailPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;
  int _songCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPlaylistSongs();
  }

  Future<void> _loadPlaylistSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final songs = await widget.navidromeService.getPlaylistSongs(widget.playlistId);
      setState(() {
        _songs = songs;
        _songCount = songs.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    
    if (hours > 0) {
      return "$hours:$minutes:$secs";
    } else {
      return "$minutes:$secs";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlaylistSongs,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 歌单头部信息
        _buildPlaylistHeader(),
        const SizedBox(height: 16),
        // 歌曲列表
        Expanded(
          child: _buildSongList(),
        ),
      ],
    );
  }

  Widget _buildPlaylistHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withOpacity(0.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歌单封面
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.queue_music,
              size: 50,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 16),
          // 歌单信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playlistName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_songCount 首歌曲',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                // 操作按钮
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        // 播放整个歌单
                        final audioHandler = Provider.of<AudioHandlerService>(context, listen: false);
                        final songs = await widget.navidromeService.getPlaylistSongs(widget.playlistId);
                      
                        if (songs.isNotEmpty) {
                          for (int i = 0; i < songs.length; i++) {
                            final song = songs[i];
                            if (i == 0) {
                              await audioHandler.playSong(song);
                            } else {
                              final mediaItem = MediaItem(
                                id: song.url,
                                album: song.album ?? '',
                                title: song.title,
                                artist: song.artist,
                                duration: Duration(seconds: song.duration),
                                artUri: (song.coverUrl != null && song.coverUrl!.isNotEmpty) 
                                    ? Uri.parse(song.coverUrl!) 
                                    : null,
                              );
                              await audioHandler.addQueueItem(mediaItem);

                            }
                          }
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已添加到播放列表并开始播放'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('播放全部'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        final song = _songs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: song.coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: song.coverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(
                      Icons.music_note,
                      size: 20,
                      color: AppTheme.primaryRed,
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.music_note,
                      size: 20,
                      color: AppTheme.primaryRed,
                    ),
                  )
                : const Icon(
                    Icons.music_note,
                    size: 20,
                    color: AppTheme.primaryRed,
                  ),
          ),
          title: Text(
            song.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${song.artist} - ${song.album}',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _formatDuration(song.duration),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          onTap: () async {
            final audioHandler = Provider.of<AudioHandlerService>(context, listen: false);
            await audioHandler.playSong(song);
            
            if (context.mounted) {
              // 添加剩余歌曲到播放队列
              for (int i = index + 1; i < _songs.length; i++) {
                final nextSong = _songs[i];
                final mediaItem = MediaItem(
                  id: nextSong.url,
                  album: nextSong.album ?? '',
                  title: nextSong.title,
                  artist: nextSong.artist,
                  duration: Duration(seconds: nextSong.duration),
                  artUri: (nextSong.coverUrl != null && nextSong.coverUrl!.isNotEmpty) 
                      ? Uri.parse(nextSong.coverUrl!) 
                      : null,
                );
                await audioHandler.addQueueItem(mediaItem);

              }
              
              Navigator.pushNamed(context, '/player');
            }
          },
        );
      },
    );
  }
}