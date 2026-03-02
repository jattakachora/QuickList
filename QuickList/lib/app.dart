import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_tasker/core/sync/sync_clock.dart';
import 'package:todo_tasker/features/lists/providers/lists_provider.dart';
import 'package:todo_tasker/features/lists/screens/home_screen.dart';
import 'package:todo_tasker/features/notifications/minimized_overlay_notification_service.dart';
import 'package:todo_tasker/features/overlay/overlay_service.dart';

class QuickListApp extends ConsumerStatefulWidget {
  const QuickListApp({super.key});

  @override
  ConsumerState<QuickListApp> createState() => _QuickListAppState();
}

class _QuickListAppState extends ConsumerState<QuickListApp>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.quicklist/tasker');

  StreamSubscription<String>? _notificationTapSub;
  Timer? _syncTimer;
  int _lastSyncClock = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationTapSub = MinimizedOverlayNotificationService
        .instance.openListStream
        .listen(_restorePopupFromNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationLaunch();
      _startSyncWatcher();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTapSub?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(listsProvider.notifier).loadFresh();
      _handleNotificationLaunch();
      _startSyncWatcher();
    }
  }

  Future<void> _startSyncWatcher() async {
    _lastSyncClock = await SyncClock.read();
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      final current = await SyncClock.read();
      if (current != _lastSyncClock) {
        _lastSyncClock = current;
        if (mounted) {
          await ref.read(listsProvider.notifier).loadFresh();
        }
      }
    });
  }

  Future<void> _handleNotificationLaunch() async {
    final listId =
        MinimizedOverlayNotificationService.instance.consumeLaunchListId();
    if (listId == null || listId.isEmpty) {
      return;
    }
    await _restorePopupFromNotification(listId);
  }

  Future<void> _restorePopupFromNotification(String listId) async {
    if (listId.isEmpty || !mounted) {
      return;
    }

    await ref.read(listsProvider.notifier).loadFresh();
    if (!mounted) {
      return;
    }

    final lists = ref.read(listsProvider);
    final index = lists.indexWhere((entry) => entry.id == listId);
    if (index < 0) {
      return;
    }
    final list = lists[index];

    await OverlayService().showForTarget(
      listId: list.id,
      listName: list.name,
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

    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      await _channel.invokeMethod<void>('moveTaskToBack');
    } catch (_) {
      // If host channel unavailable, popup is still shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(listsProvider);
    return MaterialApp(
      title: 'QuickList',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}