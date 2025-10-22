import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'package:audio_service/audio_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'player_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playlist_songs (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT,
            album TEXT,
            duration INTEGER,
            url TEXT NOT NULL,
            cover_url TEXT,
            added_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // 添加歌曲到播放列表
  Future<void> addSongToPlaylist(MediaItem song) async {
    final db = await database;
    await db.insert(
      'playlist_songs',
      {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'duration': song.duration?.inSeconds,
        'url': song.id, // 使用id作为url
        'cover_url': song.artUri?.toString(),
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 从播放列表中移除歌曲
  Future<void> removeSongFromPlaylist(String songId) async {
    final db = await database;
    await db.delete(
      'playlist_songs',
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  // 获取播放列表中的所有歌曲
  Future<List<MediaItem>> getPlaylistSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'playlist_songs',
      orderBy: 'added_at ASC',
    );

    return maps.map((map) {
      return MediaItem(
        id: map['id'],
        title: map['title'],
        artist: map['artist'],
        album: map['album'],
        duration: map['duration'] != null ? Duration(seconds: map['duration']) : null,
        artUri: map['cover_url'] != null ? Uri.parse(map['cover_url']) : null,
      );
    }).toList();
  }

  // 清空播放列表
  Future<void> clearPlaylist() async {
    final db = await database;
    await db.delete('playlist_songs');
  }

  // 检查歌曲是否在播放列表中
  Future<bool> isSongInPlaylist(String songId) async {
    final db = await database;
    final result = await db.query(
      'playlist_songs',
      where: 'id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}