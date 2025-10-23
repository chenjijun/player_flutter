import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:async';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  StreamSubscription<bool>? _playbackSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    // 在初始化时检查当前播放状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = Provider.of<AudioHandlerService>(context, listen: false);
      // 检查页面状态和控制器是否仍然有效
      if (mounted && _controller != null) {
        try {
          if (svc.playing && _controller!.isAnimating) {
            _controller!.repeat();
          }
        } catch (e) {
          // 忽略控制器相关的异常
        }
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _playbackSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听播放状态变化以控制动画
    final svc = Provider.of<AudioHandlerService>(context, listen: false);
    _playbackSubscription?.cancel(); // 取消旧的订阅
    _playbackSubscription = svc.playbackStateStream.listen((isPlaying) {
      // 检查页面状态和控制器是否仍然有效
      if (mounted && _controller != null) {
        try {
          if (isPlaying && !_controller!.isAnimating) {
            _controller!.repeat();
          } else if (!isPlaying && _controller!.isAnimating) {
            _controller!.stop();
          }
        } catch (e) {
          // 忽略控制器相关的异常
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AudioHandlerService>(context);
    final song = svc.current;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    StreamBuilder<MediaItem?>(
                      stream: svc.mediaItemStream,
                      builder: (context, snapshot) {
                        final mediaItem = snapshot.data;
                        return Column(
                          children: [
                            Text(
                              mediaItem?.title ?? '-',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              mediaItem?.artist ?? '-',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 48),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // 计算封面尺寸，确保不会超出可用空间
                        final maxWidth = size.width * 0.8;
                        final maxHeight = constraints.maxHeight > 0 
                            ? constraints.maxHeight * 0.6 
                            : size.width * 0.8;
                        final imageSize = math.min(maxWidth, maxHeight);
                        
                        return SizedBox(
                          width: imageSize,
                          height: imageSize,
                          child: StreamBuilder<MediaItem?>(
                            stream: svc.mediaItemStream,
                            builder: (context, snapshot) {
                              final mediaItem = snapshot.data;
                              return StreamBuilder<bool>(
                                stream: svc.playbackStateStream,
                                builder: (context, playbackSnapshot) {
                                  final isPlaying = playbackSnapshot.data ?? false;
                                  
                                  // 确保动画状态与播放状态同步
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    // 检查页面状态和控制器是否仍然有效
                                    if (mounted && _controller != null) {
                                      try {
                                        if (isPlaying && !_controller!.isAnimating) {
                                          _controller!.repeat();
                                        } else if (!isPlaying && _controller!.isAnimating) {
                                          _controller!.stop();
                                        }
                                      } catch (e) {
                                        // 忽略控制器相关的异常
                                      }
                                    }
                                  });
                                  
                                  if (_controller == null) {
                                    return Container(
                                      width: imageSize,
                                      height: imageSize,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.2),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: mediaItem?.artUri != null
                                            ? Image.network(
                                                mediaItem!.artUri.toString(),
                                                fit: BoxFit.cover,
                                                width: imageSize,
                                                height: imageSize,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.music_note,
                                                    size: 80,
                                                    color: AppTheme.primaryRed,
                                                  );
                                                },
                                                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return const Center(
                                                    child: CircularProgressIndicator(
                                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                                                    ),
                                                  );
                                                },
                                              )
                                            : const Icon(
                                                Icons.music_note,
                                                size: 80,
                                                color: AppTheme.primaryRed,
                                              ),
                                      ),
                                    );
                                  }
                                  return AnimatedBuilder(
                                    animation: _controller!,
                                    builder: (context, child) {
                                      return Transform.rotate(
                                        angle: _controller?.value ?? 0 * 2 * math.pi,
                                        child: Container(
                                          width: imageSize,
                                          height: imageSize,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withOpacity(0.2),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: mediaItem?.artUri != null
                                                ? Image.network(
                                                    mediaItem!.artUri.toString(),
                                                    fit: BoxFit.cover,
                                                    width: imageSize,
                                                    height: imageSize,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.music_note,
                                                size: 80,
                                                color: AppTheme.primaryRed,
                                              );
                                            },
                                                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return const Center(
                                                        child: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                                                        ),
                                                      );
                                                    },
                                          )
                                                : const Icon(
                                                    Icons.music_note,
                                                    size: 80,
                                                    color: AppTheme.primaryRed,
                                                  ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  StreamBuilder<MediaItem?>(
                    stream: svc.mediaItemStream,
                    builder: (context, snapshot) {
                      final mediaItem = snapshot.data;
                      if (mediaItem == null) {
                        return const SizedBox.shrink();
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: StreamBuilder<Duration>(
                          stream: svc.positionStream,
                          builder: (context, posSnapshot) {
                            final pos = posSnapshot.data ?? Duration.zero;
                            return StreamBuilder<Duration?>(
                              stream: svc.durationStream,
                              builder: (context, durSnapshot) {
                                final total = durSnapshot.data ?? Duration.zero;
                                final pct = total.inMilliseconds > 0
                                    ? pos.inMilliseconds / total.inMilliseconds
                                    : 0.0;
                                
                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 12,
                                        ),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                                        thumbColor: Colors.white,
                                        overlayColor: Colors.white.withOpacity(0.1),
                                      ),
                                      child: Slider(
                                        value: pct.clamp(0.0, 1.0).toDouble(), // 确保值为double类型
                                        onChanged: (v) async {
                                          final seekTo = Duration(
                                            milliseconds: (v * total.inMilliseconds).toInt(),
                                          );
                                          await svc.seek(seekTo);
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(pos),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(total),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StreamBuilder<PlayMode>(
                        stream: svc.playModeStream, // 假设我们添加了这个流
                        builder: (context, snapshot) {
                          final playMode = snapshot.data ?? PlayMode.loop;
                          IconData iconData;
                          String tooltipText;
                          
                          switch (playMode) {
                            case PlayMode.sequential:
                              iconData = Icons.repeat;
                              tooltipText = '顺序播放';
                              break;
                            case PlayMode.loop:
                              iconData = Icons.repeat;
                              tooltipText = '列表循环';
                              break;
                            case PlayMode.singleLoop:
                              iconData = Icons.repeat_one;
                              tooltipText = '单曲循环';
                              break;
                            case PlayMode.shuffle:
                              iconData = Icons.shuffle;
                              tooltipText = '随机播放';
                              break;
                          }
                          
                          return IconButton(
                            icon: Icon(iconData),
                            color: Colors.white,
                            tooltip: tooltipText,
                            onPressed: () {
                              svc.togglePlayMode();
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        color: Colors.white,
                        iconSize: 40,
                        onPressed: () async {
                          await svc.skipToPrevious();
                        },
                      ),
                      StreamBuilder<bool>(
                        stream: svc.playbackStateStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          
                          // 确保按钮状态与播放状态同步
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || _controller == null) return;
                            try {
                              if (isPlaying && !_controller!.isAnimating) {
                                _controller!.repeat();
                              } else if (!isPlaying && _controller!.isAnimating) {
                                _controller!.stop();
                              }
                            } catch (e) {
                              // 忽略控制器相关的异常
                            }
                          });
                          
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 40,
                            ),
                            color: Colors.white,
                            iconSize: 40,
                            onPressed: () async {
                              if (isPlaying) {
                                await svc.pause();
                              } else {
                                await svc.play();
                              }
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        color: Colors.white,
                        iconSize: 40,
                        onPressed: () async {
                          await svc.skipToNext();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_play),
                        color: Colors.white,
                        onPressed: () => Navigator.pushNamed(context, '/playlist'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
