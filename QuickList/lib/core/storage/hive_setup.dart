import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';

class HiveSetup {
  static const String listsBoxName = 'quick_lists_box';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(QuickListItemAdapter.typeIdConst)) {
      Hive.registerAdapter(QuickListItemAdapter());
    }
    if (!Hive.isAdapterRegistered(QuickListAdapter.typeIdConst)) {
      Hive.registerAdapter(QuickListAdapter());
    }
    await Hive.openBox<QuickList>(listsBoxName);
    _initialized = true;
  }

  static Box<QuickList> get listsBox => Hive.box<QuickList>(listsBoxName);

  static Future<void> reopenListsBox() async {
    if (Hive.isBoxOpen(listsBoxName)) {
      await Hive.box<QuickList>(listsBoxName).close();
    }
    await Hive.openBox<QuickList>(listsBoxName);
  }
}
