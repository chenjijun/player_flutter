import 'package:flutter_test/flutter_test.dart';
import 'package:player_flutter/services/audio_handler.dart';
import 'package:player_flutter/models/song.dart';

void main() {
  group('AudioHandlerService', () {
    late AudioHandlerService audioHandler;

    setUp(() {
      audioHandler = AudioHandlerService();
    });

    tearDown(() {
      audioHandler.dispose();
    });

    test('playSong adds song to playlist when not already present', () async {
      final song = Song(
        id: 'test-id',
        title: 'Test Song',
        artist: 'Test Artist',
        url: 'https://example.com/test.mp3',
        duration: 180,
      );

      // Initially the queue should be empty
      expect(audioHandler.queue.length, 0);

      // Play the song
      await audioHandler.playSong(song);

      // After playing, the queue should have one item
      expect(audioHandler.queue.length, 1);
      expect(audioHandler.queue[0].id, song.url);
      expect(audioHandler.current?.id, song.id);
    });

    test('playSong reuses existing song in playlist when already present', () async {
      final song1 = Song(
        id: 'test-id-1',
        title: 'Test Song 1',
        artist: 'Test Artist 1',
        url: 'https://example.com/test1.mp3',
        duration: 180,
      );

      final song2 = Song(
        id: 'test-id-2',
        title: 'Test Song 2',
        artist: 'Test Artist 2',
        url: 'https://example.com/test2.mp3',
        duration: 200,
      );

      // Add first song
      await audioHandler.playSong(song1);
      expect(audioHandler.queue.length, 1);

      // Add second song
      await audioHandler.playSong(song2);
      expect(audioHandler.queue.length, 2);

      // Play the first song again - should not duplicate
      await audioHandler.playSong(song1);
      expect(audioHandler.queue.length, 2); // Still 2, not 3
    });

    test('playSong adds new song to the bottom of the playlist', () async {
      final song1 = Song(
        id: 'test-id-1',
        title: 'Test Song 1',
        artist: 'Test Artist 1',
        url: 'https://example.com/test1.mp3',
        duration: 180,
      );

      final song2 = Song(
        id: 'test-id-2',
        title: 'Test Song 2',
        artist: 'Test Artist 2',
        url: 'https://example.com/test2.mp3',
        duration: 200,
      );

      // Add first song
      await audioHandler.playSong(song1);
      
      // Add second song
      await audioHandler.playSong(song2);

      // Check that the queue has both songs in the expected order
      expect(audioHandler.queue.length, 2);
      expect(audioHandler.queue[0].id, song1.url);
      expect(audioHandler.queue[1].id, song2.url);
    });
  });
}