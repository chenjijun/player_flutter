import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home.dart';
import 'pages/player.dart';
import 'pages/playlist.dart';
import 'pages/settings.dart';
import 'pages/navidrome_settings.dart';
import 'pages/navidrome_library.dart';
import 'services/audio_handler.dart';
import 'services/notification_service.dart';
import 'services/mode_service.dart';
import 'services/theme_service.dart';
import 'services/cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化通知服务
  await NotificationService.init();
  
  // 创建单例服务实例（避免热重载重建）
  final modeService = ModeService();
  final themeService = ThemeService();
  final cacheService = CacheService();
  
  // 并行执行初始化
  await Future.wait([
    modeService.init(),
    themeService.init(),
    cacheService.init(),
  ]);
  
  // 初始化音频服务
  final audioService = AudioHandlerService();
  await audioService.initialize();

  runApp(MainApp(
    audioService: audioService,
    modeService: modeService,
    themeService: themeService,
    cacheService: cacheService,
  ));
}

class MainApp extends StatelessWidget {
  final AudioHandlerService audioService;
  final ModeService modeService;
  final ThemeService themeService;
  final CacheService cacheService;
  
  const MainApp({
    super.key, 
    required this.audioService,
    required this.modeService,
    required this.themeService,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioHandlerService>.value(value: audioService),
        ChangeNotifierProvider<ModeService>.value(value: modeService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<CacheService>.value(value: cacheService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Music Player',
            theme: themeService.theme,
            home: const HomePage(),
            routes: {
              '/player': (context) => const PlayerPage(),
              '/playlist': (context) => const PlaylistPage(),
              '/settings': (context) => const SettingsPage(),
              '/navidrome_settings': (context) => const NavidromeSettingsPage(),
              '/navidrome': (context) => const NavidromeLibraryPage(),
            },
          );
        },
      ),
    );
  }
}
