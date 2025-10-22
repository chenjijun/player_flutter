import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 页面每次显示时都刷新播放状态
    final svc = Provider.of<AudioHandlerService>(context, listen: false);
    svc.refreshState();
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
                    Text(
                      song?.title ?? '-',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      song?.artist ?? '-',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: size.width * 0.8,
                      height: size.width * 0.8,
                      child: StreamBuilder<bool>(
                        stream: svc.playingStream,
                        builder: (context, snap) {
                          final playing = snap.data ?? false;
                          return GestureDetector(
                            onTap: () async {
                              if (playing) {
                                await svc.pause();
                              } else {
                                await svc.play();
                              }
                            },
                            child: Container(
                              width: 60,
                              height: 60,
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
                              child: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                size: 40,
                                color: AppTheme.primaryRed,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: StreamBuilder<Duration>(
                      stream: svc.positionStream,
                      builder: (context, snap) {
                        final pos = snap.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: svc.durationStream,
                          builder: (context, dsnap) {
                            final total = dsnap.data ?? Duration.zero;
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
                                    value: song == null ? 0.0 : pct.clamp(0.0, 1.0), // 没有歌曲时显示0
                                    onChanged: song == null ? null : (v) async { // 没有歌曲时禁用
                                      final seekTo = Duration(
                                          milliseconds:
                                              (v * total.inMilliseconds).toInt());
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
                                        song == null ? '00:00' : _formatDuration(pos), // 没有歌曲时显示00:00
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        song == null ? '00:00' : _formatDuration(total), // 没有歌曲时显示00:00
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
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.repeat),
                        color: Colors.white,
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        color: Colors.white,
                        iconSize: 40,
                        onPressed: () async {
                          await svc.skipToPrevious();
                        },
                      ),
                      Consumer<AudioHandlerService>(
                        builder: (context, svc, child) {
                          return GestureDetector(
                            onTap: () async {
                              if (svc.isPlaying) {
                                await svc.pause();
                              } else {
                                await svc.play();
                              }
                            },
                            child: Container(
                              width: 60,
                              height: 60,
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
                              child: Icon(
                                svc.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 40,
                                color: AppTheme.primaryRed,
                              ),
                            ),
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
