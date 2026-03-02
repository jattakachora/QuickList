import 'package:todo_tasker/core/storage/hive_setup.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';

class ListRepository {
  Future<List<QuickList>> getAllLists({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await HiveSetup.reopenListsBox();
    }
    final values = HiveSetup.listsBox.values.toList();
    values.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      if (byPosition != 0) {
        return byPosition;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return values;
  }

  Future<void> upsertList(QuickList list) async {
    await HiveSetup.listsBox.put(list.id, list);
    await HiveSetup.listsBox.flush();
  }

  Future<void> deleteList(String listId) async {
    await HiveSetup.listsBox.delete(listId);
    await HiveSetup.listsBox.flush();
  }

  Future<QuickList?> getByName(
    String listName, {
    bool forceRefresh = false,
  }) async {
    String normalize(String value) {
      return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final target = normalize(listName);
    final allLists = await getAllLists(forceRefresh: forceRefresh);
    for (final list in allLists) {
      if (normalize(list.name) == target) {
        return list;
      }
    }
    return null;
  }

  Future<QuickList?> getById(
    String listId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await HiveSetup.reopenListsBox();
    }
    return HiveSetup.listsBox.get(listId);
  }

  Future<bool> toggleItemFromOverlay({
    required String listId,
    required String itemId,
  }) async {
    final list = await getById(listId, forceRefresh: true);
    if (list == null) {
      return false;
    }
    final targetIndex = list.items.indexWhere((item) => item.id == itemId);
    if (targetIndex < 0) {
      return false;
    }
    final updatedItems = List<QuickListItem>.from(list.items);
    final current = updatedItems[targetIndex];
    updatedItems[targetIndex] =
        current.copyWith(isCompleted: !current.isCompleted);
    await upsertList(list.copyWith(items: updatedItems));
    return true;
  }

  Future<void> clearCompleted(String listId) async {
    final list = await getById(listId, forceRefresh: true);
    if (list == null) {
      return;
    }
    final activeItems = list.items.where((item) => !item.isCompleted).toList();
    await upsertList(list.copyWith(items: activeItems));
  }
}

class OverlaySnapshot {
  OverlaySnapshot({
    required this.listId,
    required this.listName,
    required this.items,
  });

  final String listId;
  final String listName;
  final List<QuickListItem> items;
}
