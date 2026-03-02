import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MinimizedOverlayNotificationService {
  MinimizedOverlayNotificationService._();

  static final MinimizedOverlayNotificationService instance =
      MinimizedOverlayNotificationService._();

  static const int _notificationId = 9042;
  static const String _channelId = 'quicklist_overlay_minimized';
  static const String _channelName = 'QuickList Minimized Overlay';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _mainInitialized = false;
  bool _overlayInitialized = false;
  String? _launchListId;
  final StreamController<String> _openListController =
      StreamController<String>.broadcast();

  Stream<String> get openListStream => _openListController.stream;

  Future<void> initMain() async {
    if (_mainInitialized) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    _launchListId = _extractListId(launchPayload);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        _launchListId = _extractListId(response.payload);
        if (_launchListId != null && _launchListId!.isNotEmpty) {
          _openListController.add(_launchListId!);
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _mainInitialized = true;
  }

  Future<void> initOverlay() async {
    if (_overlayInitialized) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings);
    _overlayInitialized = true;
  }

  String? consumeLaunchListId() {
    final listId = _launchListId;
    _launchListId = null;
    return listId;
  }

  Future<void> showMinimizedNotification({
    required String listId,
    required String listName,
    required int itemCount,
  }) async {
    await _ensureReadyForOverlay();

    final payload = jsonEncode({
      'type': 'open_list',
      'list_id': listId,
    });

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription:
            'Shown when a QuickList popup is minimized from overlay.',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: true,
      ),
    );

    await _plugin.show(
      _notificationId,
      'QuickList minimized',
      '$listName ($itemCount items). Tap to restore popup.',
      details,
      payload: payload,
    );
  }

  Future<void> cancelMinimizedNotification() async {
    // Keep as no-op to avoid plugin crash: PlatformException("Missing type parameter")
    // on some Android builds with this plugin version.
  }

  Future<void> _ensureReadyForOverlay() async {
    if (_overlayInitialized || _mainInitialized) {
      return;
    }
    await initOverlay();
  }

  String? _extractListId(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final raw = jsonDecode(payload);
      if (raw is! Map) {
        return null;
      }
      final value = raw['list_id']?.toString();
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } catch (_) {
      return null;
    }
  }
}