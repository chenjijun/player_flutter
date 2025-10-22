import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mode_service.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final modeService = context.watch<ModeService>();
    final isNavidrome = modeService.isNavidromeMode;
    final hasConfig = modeService.navidromeConfig != null;

    return PopupMenuButton<String>(
      icon: Icon(
        isNavidrome ? Icons.cloud : Icons.phone_android,
        color: Colors.white,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'local',
          child: Row(
            children: [
              Icon(Icons.phone_android),
              SizedBox(width: 8),
              Text('本地模式'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'navidrome',
          enabled: hasConfig,
          child: Row(
            children: [
              Icon(Icons.cloud),
              SizedBox(width: 8),
              Text('Navidrome'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('服务器设置'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'local':
            await modeService.switchMode(PlayerMode.local);
            break;
          case 'navidrome':
            await modeService.switchMode(PlayerMode.navidrome);
            break;
          case 'settings':
            if (context.mounted) {
              Navigator.pushNamed(context, '/navidrome-settings');
            }
            break;
        }
      },
    );
  }
}