import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/navidrome_config.dart';
import '../services/mode_service.dart';
import '../theme/app_theme.dart';

class NavidromeSettingsPage extends StatefulWidget {
  const NavidromeSettingsPage({super.key});

  @override
  State<NavidromeSettingsPage> createState() => _NavidromeSettingsPageState();
}

class _NavidromeSettingsPageState extends State<NavidromeSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _savePassword = false; // 添加保存密码选项

  @override
  void initState() {
    super.initState();
    final modeService = context.read<ModeService>();
    final config = modeService.navidromeConfig;
    if (config != null) {
      _serverController.text = config.serverUrl;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      // 如果配置中已有密码，则默认选中保存密码选项
      _savePassword = config.password.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final config = NavidromeConfig(
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final error = await context.read<ModeService>().setupNavidrome(
        config, 
        savePassword: _savePassword
      );
      if (context.mounted) {
        if (error == null) {
          // 登录成功后切换到Navidrome模式
          await context.read<ModeService>().switchMode(PlayerMode.navidrome);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navidrome 服务器配置成功')),
            );
            Navigator.pop(context);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('连接失败：$error')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发生错误，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navidrome 设置'),
        actions: [
          if (context.watch<ModeService>().navidromeConfig != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清除配置'),
                    content: const Text('确定要清除 Navidrome 配置吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<ModeService>().clearNavidromeConfig();
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://your-server:4533',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入服务器地址';
                if (!v.startsWith('http://') && !v.startsWith('https://')) {
                  return '请输入有效的 URL（以 http:// 或 https:// 开头）';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入用户名';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
              ),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入密码';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // 添加保存密码选项
            CheckboxListTile(
              title: const Text('保存密码'),
              subtitle: const Text('选择是否在设备上保存密码以支持自动登录'),
              value: _savePassword,
              onChanged: (value) {
                setState(() {
                  _savePassword = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}