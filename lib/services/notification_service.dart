import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  // helper: download image to a temporary file and return the path
  static Future<String?> _downloadAndSaveImage(String? url) async {
    if (url == null) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/notification_image.jpg');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  static Future<void> showNotification(MediaItem item) async {

    // download image if available
    final imagePath = await _downloadAndSaveImage(item.artUri?.toString());

    AndroidNotificationDetails androidDetails;
    if (imagePath != null) {
      final bigPicture = FilePathAndroidBitmap(imagePath);
      final largeIcon = FilePathAndroidBitmap(imagePath);
      androidDetails = AndroidNotificationDetails(
        'music_player_notification',
        'Music Player',
        channelDescription: 'Shows what music is currently playing',
        importance: Importance.low,
        priority: Priority.low,
        largeIcon: largeIcon,
        styleInformation: BigPictureStyleInformation(
          bigPicture,
          hideExpandedLargeIcon: true,
          contentTitle: item.title,
          summaryText: item.artist,
        ),
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        'music_player_notification',
        'Music Player',
        channelDescription: 'Shows what music is currently playing',
        importance: Importance.low,
        priority: Priority.low,
        styleInformation: const DefaultStyleInformation(true, true),
      );
    }

    DarwinNotificationDetails? iosDetails;
    if (imagePath != null) {
      iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: false,
        attachments: [DarwinNotificationAttachment(imagePath)],
      );
    } else {
      iosDetails = const DarwinNotificationDetails(presentAlert: true, presentSound: false);
    }

    final platform = NotificationDetails(android: androidDetails, iOS: iosDetails);
    final fallback = NotificationDetails(android: androidDetails);

    // show notification
    await _notifications.show(
      1,
      item.title,
      item.artist,
      platform,
      payload: 'music_player_notification',
    );
  }

  static Future<void> hideNotification() async {
    await _notifications.cancel(1);
  }
}
