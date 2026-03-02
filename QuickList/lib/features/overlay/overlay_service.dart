import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OverlayService {
  static const String targetListNameKey = 'overlay_target_list_name';

  Future<void> showForListName(
    String listName, {
    String? listId,
    List<Map<String, dynamic>>? items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = listName.trim();
    await prefs.setString(targetListNameKey, normalized);

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
      'list_name': normalized,
      'list_id': listId,
      'items': items ?? const [],
    });
  }

  Future<void> close() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}
