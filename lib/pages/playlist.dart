import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AudioHandlerService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '播放列表',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryRed, // 修复主题颜色引用
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: () {
              _showClearPlaylistDialog(context, svc);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<MediaItem>>(
        stream: svc.queueStream,
        builder: (context, snap) {
          final list = snap.data ?? [];
          
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '播放列表为空',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '播放列表(${list.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _showClearPlaylistDialog(context, svc);
                      },
                      child: const Text(
                        '清空',
                        style: TextStyle(
                          color: AppTheme.primaryRed, // 修复主题颜色引用
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, idx) {
                    final item = list[idx];
                    final isCurrent = svc.current?.id == item.id;
                    
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (direction) async {
                        await svc.removeFromQueue(item);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar( // 修复SnackBar为非const
                              content: const Text('已从播放列表移除'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: ListTile(
                        key: ValueKey(item.id),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: item.artUri != null
                              ? CachedNetworkImage(
                                  imageUrl: item.artUri.toString(),
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    width: 45,
                                    height: 45,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 45,
                                  height: 45,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent 
                                ? AppTheme.primaryRed // 修复主题颜色引用
                                : AppTheme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.artist ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.play_arrow,
                                color: AppTheme.primaryRed, // 修复主题颜色引用
                              )
                            : null,
                        onTap: () async {
                          final svc = Provider.of<AudioHandlerService>(context, listen: false);
                          if (svc.backgroundHandler != null) {
                            final index = svc.backgroundHandler!.queue.value.indexOf(item);
                            if (index != -1) {
                              await svc.backgroundHandler!.skipToQueueItem(index);
                            }
                          } else {
                            // 如果后台服务未初始化，直接通过AudioHandlerService播放
                            final song = Song(
                              id: item.id,
                              title: item.title,
                              artist: item.artist ?? '',
                              album: item.album ?? '',
                              duration: item.duration?.inSeconds ?? 0,
                              url: item.id,
                              coverUrl: item.artUri?.toString() ?? '',
                            );
                            await svc.playSong(song);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearPlaylistDialog(BuildContext context, AudioHandlerService svc) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清空播放列表'),
          content: const Text('确定要清空播放列表吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await svc.clearQueue();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar( // 修复SnackBar为非const
                      content: const Text('播放列表已清空'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: const Text(
                '清空',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}