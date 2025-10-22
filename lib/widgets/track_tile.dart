import 'package:flutter/material.dart';

class TrackTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final VoidCallback? onTap;

  const TrackTile({super.key, required this.title, required this.subtitle, this.coverUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final leading = (coverUrl != null && coverUrl!.isNotEmpty)
        ? Image.network(coverUrl!, width: 48, height: 48, fit: BoxFit.cover)
        : Container(width: 48, height: 48, color: Colors.grey[300], child: Icon(Icons.music_note, size: 28, color: Colors.grey[700]));

    return ListTile(
      leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: leading),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white, // 设置标题为白色
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white70, // 设置副标题为白色70%透明度
        ),
      ),
      onTap: onTap,
    );
  }
}