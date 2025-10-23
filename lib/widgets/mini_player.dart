import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AudioHandlerService>(
      builder: (context, svc, child) {
        final song = svc.current;
        
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/player'),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: song.coverUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: song.coverUrl!,
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 45,
                            height: 45,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.white),
                          ),
                        )
                      : Container(
                          width: 45,
                          height: 45,
                          color: Colors.grey[300],
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StreamBuilder<bool>(
                  stream: svc.playbackStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        playing ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: AppTheme.primaryRed,
                        size: 32,
                      ),
                      onPressed: () {
                        if (playing) {
                          svc.pause();
                        } else if (song != null) {
                          svc.playSong(song);
                        }
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.queue_music,
                    color: AppTheme.secondaryTextColor,
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/playlist'),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      }
    );
  }
}