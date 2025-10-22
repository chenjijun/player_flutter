class Song {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int duration;
  final String? coverUrl;
  final String url;
  final String? lyrics;
  
  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.coverUrl,
    required this.url,
    this.lyrics,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      duration: json['duration'] as int,
      coverUrl: json['coverUrl'] as String?,
      url: json['url'] as String,
      lyrics: json['lyrics'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'coverUrl': coverUrl,
      'url': url,
      'lyrics': lyrics,
    };
  }
}