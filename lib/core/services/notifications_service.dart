import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local notifications. Right now there is only one channel
/// ("Rare bloom alerts") for nearby finds.
class NotificationsService {
  NotificationsService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _rareChannelId = 'rare_blooms';
  static const String _rareChannelName = 'Rare bloom alerts';
  static const String _rareChannelDesc =
      'Pings when someone nearby photographs a rare or legendary plant.';

  Future<void> init() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    // Android 13+ needs us to ask first
    try {
      await androidPlugin?.requestNotificationsPermission();
    } on Object catch (e) {
      debugPrint('[Notifications] permission request failed: $e');
    }
    // create the channel up front so it shows up in system settings
    try {
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _rareChannelId,
          _rareChannelName,
          description: _rareChannelDesc,
          importance: Importance.high,
        ),
      );
    } on Object catch (e) {
      debugPrint('[Notifications] channel create failed: $e');
    }

    _ready = true;
  }

  Future<void> showRareBloom({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _rareChannelId,
        _rareChannelName,
        channelDescription: _rareChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.social,
      ),
    );
    try {
      await _plugin.show(id, title, body, details);
    } on Object catch (e) {
      debugPrint('[Notifications] show failed: $e');
    }
  }
}

final notificationsServiceProvider =
    Provider<NotificationsService>((_) => NotificationsService());
