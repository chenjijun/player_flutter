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
        backgroundColor: AppTheme.primaryRed,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // 移除了使用对话框的IconButton
      ),
      body: StreamBuilder<List<MediaItem>>(
        stream: svc.queueStream,
        builder: (context, snap) {
          final list = snap.data ?? <MediaItem>[];
          
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 80,
                    color: Colors.white30,
                  ),
                  SizedBox(height: 20),
                  Text(
                    '播放列表为空',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView(
            padding: const EdgeInsets.only(top: 20),
            onReorder: (oldIndex, newIndex) async {
              // TODO: 实现队列重排序功能，需要在AudioHandlerService中添加相应逻辑
            },
            children: [
              for (var i = 0; i < list.length; i++)
                Dismissible(
                  key: ValueKey(list[i].id),
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
                    await svc.removeQueueItem(list[i]);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar( // 修复SnackBar为非const
                          content: Text('已从播放列表移除'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: ListTile(
                    key: ValueKey(list[i]),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      list[i].title,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 30, 30, 30),
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${list[i].artist ?? ''} - ${list[i].album ?? ''}',
                      style: const TextStyle(
                        color: Color.fromARGB(179, 38, 38, 38),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      await svc.skipToQueueItem(i);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await svc.clearQueue();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('播放列表已清空'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.delete_sweep, color: Colors.white),
      ),
    );
  }
}