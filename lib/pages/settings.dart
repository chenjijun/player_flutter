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
              ListTile(
                title: const Text('缓存大小限制'),
                subtitle: Text(_formatCacheSize(context.watch<CacheService>().maxCacheSize)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCacheSizeDialog(context),
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

  String _formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _showCacheSizeDialog(BuildContext context) {
    final cacheService = context.read<CacheService>();
    int currentSize = cacheService.maxCacheSize;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _CacheSizeInputDialog(
          initialSize: currentSize,
          onConfirm: (size) => cacheService.setMaxCacheSize(size),
        );
      },
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

class _CacheSizeInputDialog extends StatefulWidget {
  final int initialSize;
  final Function(int) onConfirm;

  const _CacheSizeInputDialog({
    required this.initialSize,
    required this.onConfirm,
  });

  @override
  State<_CacheSizeInputDialog> createState() => _CacheSizeInputDialogState();
}

class _CacheSizeInputDialogState extends State<_CacheSizeInputDialog> {
  late TextEditingController _textController;
  late int _selectedUnit;
  
  // 单位选项
  static const List<Map<String, dynamic>> units = [
    {'label': 'MB', 'value': 1024 * 1024},
    {'label': 'GB', 'value': 1024 * 1024 * 1024},
  ];

  @override
  void initState() {
    super.initState();
    
    // 计算初始值和单位
    int initialValue = widget.initialSize;
    _selectedUnit = units[1]['value']; // 默认GB
    
    // 如果小于1GB，使用MB
    if (initialValue < 1024 * 1024 * 1024) {
      _selectedUnit = units[0]['value'];
    }
    
    // 计算显示值
    double displayValue = initialValue / _selectedUnit;
    _textController = TextEditingController(text: displayValue.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('缓存大小限制'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('输入缓存大小限制:'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _selectedUnit,
                  items: units.map<DropdownMenuItem<int>>((Map<String, dynamic> unit) {
                    return DropdownMenuItem<int>(
                      value: unit['value'],
                      child: Text(unit['label']),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedUnit = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '注意：输入值将被转换为最接近的整数',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
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
            // 解析输入值
            final String inputText = _textController.text.trim();
            if (inputText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入缓存大小')),
              );
              return;
            }
            
            double? inputValue = double.tryParse(inputText);
            if (inputValue == null || inputValue <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入有效的正数')),
              );
              return;
            }
            
            // 计算实际字节数
            int actualSize = (inputValue * _selectedUnit).toInt();
            
            // 检查最小值（至少10MB）
            if (actualSize < 10 * 1024 * 1024) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存大小不能小于10MB')),
              );
              return;
            }
            
            widget.onConfirm(actualSize);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}