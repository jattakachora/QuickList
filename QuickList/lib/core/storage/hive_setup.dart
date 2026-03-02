import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';

class HiveSetup {
  static const String listsBoxName = 'quick_lists_box';

  static bool _initialized = false;
  static Future<void>? _initFuture;

  static Future<void> init() {
    if (_initialized) {
      return Future<void>.value();
    }
    final existing = _initFuture;
    if (existing != null) {
      return existing;
    }

    final future = _doInit();
    _initFuture = future;
    return future;
  }

  static Future<void> _doInit() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(QuickListItemAdapter.typeIdConst)) {
      Hive.registerAdapter(QuickListItemAdapter());
    }
    if (!Hive.isAdapterRegistered(QuickListAdapter.typeIdConst)) {
      Hive.registerAdapter(QuickListAdapter());
    }

    if (!Hive.isBoxOpen(listsBoxName)) {
      await Hive.openBox<QuickList>(listsBoxName);
    }

    _initialized = true;
  }

  static Future<void> ensureListsBoxOpen() async {
    await init();
    if (!Hive.isBoxOpen(listsBoxName)) {
      await Hive.openBox<QuickList>(listsBoxName);
    }
  }

  static Box<QuickList> get listsBox => Hive.box<QuickList>(listsBoxName);

  static Future<void> reopenListsBox() async {
    // Force disk refresh for overlay/tasker isolate reads.
    await init();
    if (Hive.isBoxOpen(listsBoxName)) {
      await Hive.box<QuickList>(listsBoxName).close();
    }
    await Hive.openBox<QuickList>(listsBoxName);
  }
}