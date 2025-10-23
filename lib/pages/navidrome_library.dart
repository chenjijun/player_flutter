import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import '../services/mode_service.dart';
import '../services/navidrome_service.dart';
import '../services/audio_handler.dart';
import '../services/theme_service.dart';
import '../models/song.dart';
import 'navidrome_playlist_detail.dart';
import '../utils/background_task.dart';
import '../theme/app_theme.dart';
import 'player.dart';
import 'dart:math';

// 网易云音乐风格主题颜色
class NeteaseMusicTheme {
  static const Color primaryRed = Color(0xFFD33A31); // 网易云主红色
  static const Color darkBackground = Color(0xFF222222); // 深色背景
  static const Color lightBackground = Color(0xFFF5F5F5); // 浅色背景
  static const Color darkCard = Color(0xFF333333); // 深色卡片
  static const Color lightText = Color(0xFF333333); // 浅色文字
  static const Color darkText = Color(0xFFCCCCCC); // 深色文字
  static const Color secondaryText = Color(0xFF999999); // 次要文字颜色
}

class NavidromeLibraryPage extends StatefulWidget {
  const NavidromeLibraryPage({super.key});

  @override
  State<NavidromeLibraryPage> createState() => _NavidromeLibraryPageState();
}

class _NavidromeLibraryPageState extends State<NavidromeLibraryPage> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Navidrome 音乐库'),
        backgroundColor: Provider.of<ThemeService>(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: NeteaseMusicTheme.darkBackground,
          child: Column(
            children: [
              // 用户信息区域
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF333333),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: NeteaseMusicTheme.primaryRed,
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Navidrome',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 侧边栏选项
              Expanded(
                child: ListView(
                  children: [
                    _buildDrawerItem(0, Icons.info, '服务器状态'),
                    _buildDrawerItem(1, Icons.music_note, '所有歌曲'),
                    _buildDrawerItem(2, Icons.favorite, '收藏'),
                    _buildDrawerItem(3, Icons.star, '评分排行'),
                    _buildDrawerItem(4, Icons.play_arrow, '最多播放'),
                    _buildDrawerItem(5, Icons.person, '艺术家'),
                    _buildDrawerItem(6, Icons.queue_music, '歌单'),
                    _buildDrawerItem(7, Icons.search, '搜索'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    final themeService = Provider.of<ThemeService>(context);
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? themeService.primaryColor : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? themeService.primaryColor : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        Navigator.of(context).pop(); // 关闭侧边栏
      },
    );
  }

  Widget _buildContent() {
    switch (_currentIndex) {
      case 0:
        return const ServerStatusPage();
      case 1:
        return const AllSongsPage();
      case 2:
        return const StarredSongsPage();
      case 3:
        return const TopRatedSongsPage();
      case 4:
        return const MostPlayedSongsPage();
      case 5:
        return const ArtistsPage();
      case 6:
        return const PlaylistsPage();
      case 7:
        return const SearchPage();
      default:
        return const Center(child: Text('请选择一个选项'));
    }
  }
}

// 服务器状态页面
class ServerStatusPage extends StatefulWidget {
  const ServerStatusPage({super.key});

  @override
  State<ServerStatusPage> createState() => _ServerStatusPageState();
}

class _ServerStatusPageState extends State<ServerStatusPage> {
  Map<String, dynamic>? _serverInfo;
  int _songCount = 0;
  int _playlistCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServerStatus();
  }

  Future<void> _loadServerStatus() async {
    try {
      final modeService = Provider.of<ModeService>(context, listen: false);
      final navidromeService = modeService.navidromeService;
      
      if (!navidromeService.isConfigured) {
        setState(() {
          _isLoading = false;
          _error = 'Navidrome服务未配置';
        });
        return;
      }

      // 测试连接
      final testResult = await navidromeService.testConnection(navidromeService.config!);
      if (testResult != null) {
        setState(() {
          _isLoading = false;
          _error = '连接失败: $testResult';
        });
        return;
      }

      // 获取歌曲总数
      try {
        _songCount = await navidromeService.getSongCount();
      } catch (e) {
        debugPrint('获取歌曲总数失败: $e');
      }

      // 获取歌单总数
      try {
        final playlists = await navidromeService.getPlaylists();
        _playlistCount = playlists.length;
      } catch (e) {
        debugPrint('获取歌单总数失败: $e');
      }

      setState(() {
        _isLoading = false;
        _serverInfo = {
          'serverUrl': navidromeService.config!.serverUrl,
          'username': navidromeService.config!.username,
          'status': '连接正常',
        };
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '获取服务器状态失败: $e';
      });
    }
  }

  Future<void> _refreshServerStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadServerStatus();
      
      if (mounted) {
        // 显示刷新成功的提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('刷新成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // 显示刷新失败的提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('刷新失败'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final darkenedColor = Color.alphaBlend(Colors.black.withOpacity(0.2), themeService.primaryColor);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器状态'),
        backgroundColor: darkenedColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshServerStatus,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: themeService.primaryColor, size: 48),
                        SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: themeService.primaryColor, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshServerStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeService.primaryColor,
                          ),
                          child: Text('重新加载', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : _serverInfo != null
                    ? ListView(
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '服务器信息',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: themeService.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  _buildInfoRow('服务器地址', _serverInfo!['serverUrl']),
                                  _buildInfoRow('用户名', _serverInfo!['username']),
                                  _buildInfoRow('连接状态', _serverInfo!['status']),
                                  _buildInfoRow('歌曲总数', _songCount.toString()),
                                  _buildInfoRow('歌单总数', _playlistCount.toString()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(child: Text('暂无服务器信息')),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 所有歌曲页面
class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalSongs = 0;
  int _songsPerPage = 20;
  bool _isPlaying = false;
  Song? _currentSong;
  late StreamSubscription _audioStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    
    // 监听音频状态变化
    final audioService = Provider.of<AudioHandlerService>(context, listen: false);
    _audioStateSubscription = audioService.playbackStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state;
          _currentSong = audioService.current;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final modeService = Provider.of<ModeService>(context, listen: false);
      final navidromeService = modeService.navidromeService;
      
      if (!navidromeService.isConfigured) {
        setState(() {
          _isLoading = false;
          _error = 'Navidrome服务未配置';
        });
        return;
      }

      // 获取歌曲总数
      _totalSongs = await navidromeService.getSongCount();
      
      // 计算偏移量
      final offset = (_currentPage - 1) * _songsPerPage;
      
      // 获取当前页的歌曲
      final songs = await navidromeService.getSongs(offset: offset, count: _songsPerPage);
      
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载歌曲失败: $e');
      setState(() {
        _isLoading = false;
        _error = '加载歌曲失败: $e';
      });
    }
  }

  Future<void> _playSong(Song song) async {
    try {
      final modeService = Provider.of<ModeService>(context, listen: false);
      final audioService = Provider.of<AudioHandlerService>(context, listen: false);
      
      // 检查是否是同一首歌曲
      if (audioService.current?.id == song.id) {
        // 如果是同一首歌曲，不再跳转到播放页面
        return;
      }
      
      // 异步播放歌曲，不阻塞UI
      await audioService.playSong(song);
      
      // 等待播放状态更新
      await Future.delayed(const Duration(milliseconds: 100));
      
      setState(() {
        _isPlaying = audioService.playing;
        _currentSong = audioService.current;
      });
      
      // 不再自动跳转到播放页面
      // if (mounted) {
      //   Navigator.pushNamed(context, '/player');
      // }
      
    } catch (e) {
      debugPrint('播放歌曲失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e'), backgroundColor: NeteaseMusicTheme.primaryRed),
        );
      }
    }
  }

  Future<void> _togglePlayPause(Song song) async {
    try {
      final audioService = Provider.of<AudioHandlerService>(context, listen: false);
      
      // 获取当前播放状态
      final isPlaying = audioService.playing;
      final currentSongId = audioService.current?.id;
      
      if (currentSongId == song.id && isPlaying) {
        // 如果是当前正在播放的歌曲，则暂停
        await audioService.pause();
      } else {
        // 否则播放该歌曲，但不再跳转到播放页面
        await _playSong(song);
      }
    } catch (e) {
      debugPrint('切换播放/暂停失败: $e');
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadSongs();
  }

  void _goToPage() {
    final totalPages = (_totalSongs / _songsPerPage).ceil();
    if (totalPages <= 1) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController(text: _currentPage.toString());
        return AlertDialog(
          title: const Text('跳转到页面'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '请输入页码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('共 $totalPages 页'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final input = controller.text;
                if (input.isNotEmpty) {
                  final page = int.tryParse(input);
                  if (page != null && page >= 1 && page <= totalPages) {
                    Navigator.of(context).pop();
                    _onPageChanged(page);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('请输入有效的页码'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
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
    final themeService = Provider.of<ThemeService>(context);
    final totalPages = (_totalSongs / _songsPerPage).ceil();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('所有歌曲'),
        backgroundColor: themeService.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSongs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 分页控件移到顶部
          if (_totalSongs > 0)
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧：分页信息和跳转按钮
                  Row(
                    children: [
                      Text(
                        '第 $_currentPage / $totalPages 页',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _goToPage,
                        child: const Text(
                          '跳转',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 右侧：分页数量选择和翻页按钮
                  Row(
                    children: [
                      // 分页数量选择
                      DropdownButton<int>(
                        value: _songsPerPage,
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 20, child: Text('20')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _songsPerPage = value;
                              _currentPage = 1; // 重置到第一页
                            });
                            _loadSongs();
                          }
                        },
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                        underline: Container(),
                      ),
                      const SizedBox(width: 8),
                      // 上一页按钮
                      ElevatedButton(
                        onPressed: _currentPage > 1
                            ? () => _onPageChanged(_currentPage - 1)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage > 1
                              ? themeService.primaryColor
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text('上一页', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      // 下一页按钮
                      ElevatedButton(
                        onPressed: _currentPage < totalPages
                            ? () => _onPageChanged(_currentPage + 1)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage < totalPages
                              ? themeService.primaryColor
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text('下一页', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: themeService.primaryColor, size: 48),
                    SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: themeService.primaryColor, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadSongs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeService.primaryColor,
                      ),
                      child: Text('重新加载', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  // 歌曲列表
                  Expanded(
                    child: ListView.builder(
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        final isCurrentSong = _currentSong?.id == song.id;
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrentSong 
                                ? themeService.primaryColor.withOpacity(0.1) 
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: song.coverUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Icon(
                                          Icons.music_note,
                                          color: themeService.primaryColor,
                                        ),
                                        errorWidget: (context, url, error) => Icon(
                                          Icons.music_note,
                                          color: themeService.primaryColor,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey[100],
                                      ),
                                      child: Icon(
                                        Icons.music_note,
                                        color: themeService.primaryColor,
                                      ),
                                    ),
                            ),
                            title: Text(
                              song.title,
                              style: TextStyle(
                                color: isCurrentSong 
                                    ? themeService.primaryColor 
                                    : Colors.black,
                                fontWeight: isCurrentSong 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${song.artist} - ${song.album}',
                              style: TextStyle(
                                color: isCurrentSong 
                                    ? themeService.primaryColor 
                                    : NeteaseMusicTheme.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                _currentSong?.id == song.id && _isPlaying 
                                    ? Icons.pause 
                                    : Icons.play_arrow,
                                color: themeService.primaryColor,
                              ),
                              onPressed: () => _togglePlayPause(song),
                            ),
                            onTap: () async {
                              await _playSong(song);
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// 收藏页面
class StarredSongsPage extends StatelessWidget {
  const StarredSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('收藏页面'),
    );
  }
}

// 评分排行页面
class TopRatedSongsPage extends StatelessWidget {
  const TopRatedSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('评分排行页面'),
    );
  }
}

// 最多播放页面
class MostPlayedSongsPage extends StatelessWidget {
  const MostPlayedSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('最多播放页面'),
    );
  }
}

// 艺术家页面
class ArtistsPage extends StatelessWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('艺术家页面'),
    );
  }
}

// 歌单页面
class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('歌单页面'),
    );
  }
}

// 搜索页面
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('搜索页面'),
    );
  }
}