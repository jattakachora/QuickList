import 'dart:async';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/services.dart';
import 'package:todo_tasker/core/state/app_container.dart';
import 'package:todo_tasker/features/lists/data/list_repository.dart';
import 'package:todo_tasker/features/lists/providers/lists_provider.dart';
import 'package:todo_tasker/features/overlay/overlay_service.dart';

class TaskerBridge {
  TaskerBridge._();

  static final TaskerBridge instance = TaskerBridge._();
  static const MethodChannel _channel = MethodChannel('com.quicklist/tasker');

  final ListRepository _repository = ListRepository();
  final OverlayService _overlayService = OverlayService();
  bool _bound = false;
  StreamSubscription<dynamic>? _overlayEventsSub;

  void bind() {
    if (_bound) {
      return;
    }
    _bound = true;
    _overlayEventsSub = FlutterOverlayWindow.overlayListener.listen((message) {
      if (message is! Map) {
        return;
      }
      final type = message['type']?.toString();
      if (type == 'overlay_list_changed') {
        appContainer.read(listsProvider.notifier).load();
      }
    });
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'taskerShowPopup') {
        final listName =
            (call.arguments as Map?)?['list_name']?.toString().trim() ?? '';
        if (listName.isEmpty) {
          return;
        }
        await _handleListPopupRequest(listName);
      }
    });
    unawaited(_channel.invokeMethod<void>('taskerBridgeReady'));
  }

  Future<void> _handleListPopupRequest(String listName) async {
    final list = await _repository.getByName(
      listName,
      forceRefresh: true,
    );
    if (list == null || list.items.isEmpty) {
      await _channel.invokeMethod<void>('sendTaskerReply', {
        'action': 'com.quicklist.LIST_EMPTY',
        'list_name': listName,
      });
      return;
    }
    await _overlayService.showForListName(
      list.name,
      listId: list.id,
      items: list.items
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'quantity': item.quantity,
              'notes': item.notes,
              'is_completed': item.isCompleted,
            },
          )
          .toList(growable: false),
    );
    await _channel.invokeMethod<void>('sendTaskerReply', {
      'action': 'com.quicklist.LIST_SHOWN',
      'list_name': list.name,
    });
  }
}
