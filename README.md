# player_flutter

A simple multi-platform music player scaffold inspired by NetEase Cloud Music.

Quick start

```bash
cd player_flutter
flutter pub get
flutter run
```

What I implemented

- Basic app scaffold with `Home`, `Player`, and `Playlist` pages
- `AudioHandlerService` using `just_audio` for playback
- Skeleton for background audio handler (audio_service)

Next steps

- Implement background audio notifications and media controls
- Add persistent library and real network-backed music data
- Improve UI to match NetEase Cloud Music

Background playback testing

1. Ensure an Android device or emulator is available.
2. Run the app:

```bash
cd player_flutter
flutter run
```

3. From Home page select a sample track to start playback. Verify the Player screen shows progress and play/pause works.
4. Lock the device or switch apps to verify playback continues. For Android, check the notification area for a media notification (uses app launcher icon by default).

Notes

- If you want a custom notification icon, add drawable/mipmap resources under `android/app/src/main/res` and set `androidNotificationIcon` in `audio_background.dart`.

