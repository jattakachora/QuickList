import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_tasker/app.dart';
import 'package:todo_tasker/core/state/app_container.dart';
import 'package:todo_tasker/core/storage/hive_setup.dart';
import 'package:todo_tasker/features/notifications/minimized_overlay_notification_service.dart';
import 'package:todo_tasker/features/overlay/overlay_entry.dart';
import 'package:todo_tasker/features/tasker_bridge/tasker_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveSetup.init();
  await MinimizedOverlayNotificationService.instance.initMain();
  runApp(
    UncontrolledProviderScope(
      container: appContainer,
      child: const QuickListApp(),
    ),
  );
  TaskerBridge.instance.bind();
}

@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveSetup.init();
  await MinimizedOverlayNotificationService.instance.initOverlay();
  runApp(const ProviderScope(child: QuickListOverlayApp()));
}
