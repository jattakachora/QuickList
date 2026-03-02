import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';
import 'package:todo_tasker/features/lists/data/list_repository.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';
import 'package:uuid/uuid.dart';

final listRepositoryProvider = Provider<ListRepository>((ref) {
  return ListRepository();
});

final listsProvider = StateNotifierProvider<QuickListsNotifier, List<QuickList>>(
  (ref) => QuickListsNotifier(ref.read(listRepositoryProvider))..load(),
);

class QuickListsNotifier extends StateNotifier<List<QuickList>> {
  QuickListsNotifier(this._repository) : super(const []);

  final ListRepository _repository;
  final Uuid _uuid = const Uuid();
  static const MethodChannel _channel = MethodChannel('com.quicklist/tasker');

  Future<void> load() async {
    state = await _repository.getAllLists(forceRefresh: true);
    await _syncTaskerCache();
  }

  Future<void> createList(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final list = QuickList(
      id: _uuid.v4(),
      name: trimmed,
      items: const [],
      createdAt: DateTime.now(),
      position: _nextListPosition(),
    );
    await _repository.upsertList(list);
    await load();
  }

  Future<void> renameList({
    required String listId,
    required String name,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null || name.trim().isEmpty) {
      return;
    }
    await _repository.upsertList(list.copyWith(name: name.trim()));
    await load();
  }

  Future<void> removeList(String listId) async {
    await _repository.deleteList(listId);
    await load();
  }

  Future<void> addItem({
    required String listId,
    required String title,
    required int quantity,
    String? notes,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null || title.trim().isEmpty) {
      return;
    }
    final item = QuickListItem(
      id: _uuid.v4(),
      title: title.trim(),
      quantity: quantity,
      notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
    );
    await _repository.upsertList(
      list.copyWith(items: [...list.items, item]),
    );
    await load();
  }

  Future<void> editItem({
    required String listId,
    required String itemId,
    required String title,
    required int quantity,
    String? notes,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null || title.trim().isEmpty) {
      return;
    }
    final items = list.items.map((item) {
      if (item.id != itemId) {
        return item;
      }
      return item.copyWith(
        title: title.trim(),
        quantity: quantity,
        notes: notes?.trim(),
        clearNotes: notes == null || notes.trim().isEmpty,
      );
    }).toList();
    await _repository.upsertList(list.copyWith(items: items));
    await load();
  }

  Future<void> removeItem({
    required String listId,
    required String itemId,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null) {
      return;
    }
    final items = list.items.where((item) => item.id != itemId).toList();
    await _repository.upsertList(list.copyWith(items: items));
    await load();
  }

  Future<void> reorderItems({
    required String listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null) {
      return;
    }
    final items = [...list.items];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    await _repository.upsertList(list.copyWith(items: items));
    await load();
  }

  Future<void> toggleItem({
    required String listId,
    required String itemId,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null) {
      return;
    }
    final items = list.items
        .map((item) => item.id == itemId
            ? item.copyWith(isCompleted: !item.isCompleted)
            : item)
        .toList();
    await _repository.upsertList(list.copyWith(items: items));
    await load();
  }

  Future<void> clearCompleted(String listId) async {
    await _repository.clearCompleted(listId);
    await load();
  }

  Future<void> reorderLists({
    required int oldIndex,
    required int newIndex,
  }) async {
    final reordered = [...state];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    for (int i = 0; i < reordered.length; i++) {
      await _repository.upsertList(reordered[i].copyWith(position: i));
    }
    await load();
  }

  int _nextListPosition() {
    if (state.isEmpty) {
      return 0;
    }
    return state.map((list) => list.position).reduce(max) + 1;
  }

  Future<void> _syncTaskerCache() async {
    final names = state.map((list) => list.name).toList(growable: false);
    try {
      await _channel.invokeMethod<void>('updateAvailableLists', {
        'list_names': names,
        'lists_json': jsonEncode(names),
      });
    } catch (_) {
      // Ignore channel failures when Android host isn't available.
    }
  }
}
