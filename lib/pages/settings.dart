import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/mode_service.dart';
import '../services/theme_service.dart';
import '../services/cache_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSection(
            title: '播放设置',
            children: [
              ListTile(
                title: const Text('Navidrome 登录'),
                subtitle: Text(
                  context.watch<ModeService>().isNavidromeMode ? '已登录' : '点击登录到 Navidrome 服务器',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/navidrome_settings'),
              ),
              SwitchListTile(
                title: const Text('缓存音频文件'),
                subtitle: const Text('在本地缓存音频文件以供离线播放'),
                value: context.watch<CacheService>().cacheEnabled,
                onChanged: (value) => context.read<CacheService>().setCacheEnabled(value),
              ),
            ],
          ),
          _buildSection(
            title: '主题设置',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 预设颜色选项
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final colorSize = (constraints.maxWidth - 48) / 5; // 5个颜色，间隔4个12px
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: ThemeService.availableColors.map((color) {
                            final isSelected = context.watch<ThemeService>().primaryColor == color;
                            return GestureDetector(
                              onTap: () => context.read<ThemeService>().setThemeColor(color),
                              child: Container(
                                width: colorSize,
                                height: colorSize,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: isSelected ? 2 : 0,
                                    ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // 自定义颜色按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showColorPicker(context),
                        icon: const Icon(Icons.color_lens),
                        label: const Text('自定义颜色'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildSection(
            title: '关于',
            children: [
              ListTile(
                title: const Text('版本'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                title: const Text('开源协议'),
                subtitle: const Text('MIT License'),
                onTap: () {
                  // TODO: 显示开源协议
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    Color pickedColor = context.read<ThemeService>().primaryColor;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择主题颜色'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickedColor,
              onColorChanged: (color) => pickedColor = color,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                context.read<ThemeService>().setThemeColor(pickedColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}