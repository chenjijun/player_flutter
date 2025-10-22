import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import '../models/song.dart';
import '../widgets/mini_player.dart';
import '../services/theme_service.dart';
import 'navidrome_library.dart';
import 'local_music.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const DiscoverPage(),
    const NavidromeLibraryPage(), // Navidrome页面 - 索引 1
    const LocalMusicPage(),       // 本地音乐页面 - 索引 2
    const MyPage(),               // "我的"页面 - 索引 3
  ];

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AudioHandlerService>(context);
    final samples = [
        Song(
          id: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          title: 'SoundHelix 1',
          artist: 'SoundHelix',
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          coverUrl: 'https://picsum.photos/300/300',
          duration: 180,
        ),
        Song(
          id: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          title: 'SoundHelix 2',
          artist: 'SoundHelix',
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          coverUrl: 'https://picsum.photos/300/301',
          duration: 240,
        ),
        Song(
          id: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
          title: 'SoundHelix 3',
          artist: 'SoundHelix',
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
          coverUrl: 'https://picsum.photos/300/302',
          duration: 200,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('缝合音乐工具'),
        actions: [
          StreamBuilder<bool>(
            stream: svc.playingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => Navigator.pushNamed(context, '/player'),
                tooltip: '正在播放',
              );
            }
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _pages[_currentIndex],
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        width: double.infinity, // 填充横向空间
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home, '首页'),
            _buildNavItem(1, Icons.library_music, 'Navidrome'),
            _buildNavItem(2, Icons.music_note, '本地音乐'),
            _buildNavItem(3, Icons.person, '我的'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFD33A31) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFFD33A31) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _onNavItemTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final List<Song> samples;

  @override
  void initState() {
    super.initState();
    samples = [
      Song(
        id: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        title: 'SoundHelix 1',
        artist: 'SoundHelix',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        coverUrl: 'https://picsum.photos/300/300',
        duration: 180,
      ),
      Song(
        id: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        title: 'SoundHelix 2',
        artist: 'SoundHelix',
        url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        coverUrl: 'https://picsum.photos/300/301',
        duration: 240,
      ),
      
    ];
  }

  Future<void> _playSample(Song song) async {
    final audioService = Provider.of<AudioHandlerService>(context, listen: false);
    
    try {
      // 先设置当前歌曲以立即更新UI
      audioService.current = song;
      
      // 异步播放歌曲，不阻塞UI
      unawaited(audioService.playSong(song));
    } catch (e) {
      debugPrint('播放示例歌曲失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('播放失败'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AudioHandlerService>(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final s = samples[index % samples.length];
                return GestureDetector(
                  onTap: () => _playSample(s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              s.coverUrl != null
                                  ? Image.network(
                                      s.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.broken_image, color: Colors.white70),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.music_note, color: Colors.white70),
                                      ),
                                    ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${index * 1000 + 123}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: samples.length * 3,
            ),
          ),
        ),
      ],
    );
  }
}

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息区域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(themeService.primaryColor.withOpacity(0.8), Colors.black),
                    Color.alphaBlend(themeService.primaryColor.withOpacity(0.6), Colors.black),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '用户名',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '个人信息',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 设置按钮集成到个人卡片中
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      icon: const Icon(Icons.settings, color: Colors.white),
                      label: const Text('设置', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        elevation: 0,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 功能列表
            const SizedBox(height: 16),
            
            // 使用卡片样式展示功能项
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildCardItem(
                    context,
                    icon: Icons.music_note,
                    title: '我的音乐',
                    onTap: () {
                      // TODO: 跳转到我的音乐页面
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildCardItem(
                    context,
                    icon: Icons.access_time,
                    title: '最近播放',
                    onTap: () {
                      // TODO: 跳转到最近播放页面
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildCardItem(
                    context,
                    icon: Icons.download,
                    title: '下载管理',
                    onTap: () {
                      // TODO: 跳转到下载管理页面
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildCardItem(
                    context,
                    icon: Icons.radio,
                    title: '我的电台',
                    onTap: () {
                      // TODO: 跳转到我的电台页面
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildCardItem(
                    context,
                    icon: Icons.favorite,
                    title: '我的收藏',
                    onTap: () {
                      // TODO: 跳转到我的收藏页面
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  _buildCardItem(
                    context,
                    icon: Icons.notifications,
                    title: '消息通知',
                    onTap: () {
                      // TODO: 跳转到消息通知页面
                    },
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  static Widget _buildCardItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final themeService = Provider.of<ThemeService>(context);
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: themeService.primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NavItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? themeService.primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? themeService.primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
