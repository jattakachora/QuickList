import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OverlayService {
  static const String targetListNameKey = 'overlay_target_list_name';
  static const String targetListIdKey = 'overlay_target_list_id';
  static const String targetTriggerClockKey = 'overlay_target_trigger_clock';

  Future<void> showForTarget({
    String? listId,
    String? listName,
    List<Map<String, dynamic>>? items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedId = listId?.trim();
    final normalizedName = listName?.trim();

    if (normalizedId != null && normalizedId.isNotEmpty) {
      await prefs.setString(targetListIdKey, normalizedId);
    } else {
      await prefs.remove(targetListIdKey);
    }

    if (normalizedName != null && normalizedName.isNotEmpty) {
      await prefs.setString(targetListNameKey, normalizedName);
    } else {
      await prefs.remove(targetListNameKey);
    }

    await prefs.setInt(
      targetTriggerClockKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final requested = await FlutterOverlayWindow.requestPermission();
      if (!(requested ?? false)) {
        return;
      }
    }

    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    await FlutterOverlayWindow.showOverlay(
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      enableDrag: false,
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'QuickList',
      overlayContent: 'Smart list popup',
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await FlutterOverlayWindow.shareData({
      'type': 'target_snapshot',
      'list_name': normalizedName,
      'list_id': normalizedId,
      'items': items ?? const [],
    });
  }

  Future<void> close() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}