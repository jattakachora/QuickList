import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    await _loadInternal(forceRefresh: false);
  }

  Future<void> loadFresh() async {
    await _loadInternal(forceRefresh: true);
  }

  Future<void> _loadInternal({required bool forceRefresh}) async {
    state = await _repository.getAllLists(forceRefresh: forceRefresh);
    await _syncTaskerCache();
    await _pushOverlaySnapshot();
  }

  Future<void> createList(String name, {String? emoji}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final displayName = _composeListName(name: trimmed, emoji: emoji);
    final list = QuickList(
      id: _uuid.v4(),
      name: displayName,
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
    String? emoji,
  }) async {
    final list = await _repository.getById(listId);
    if (list == null || name.trim().isEmpty) {
      return;
    }
    final displayName = _composeListName(name: name.trim(), emoji: emoji);
    await _repository.upsertList(list.copyWith(name: displayName));
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

  Future<void> moveItemToList({
    required String sourceListId,
    required String destinationListId,
    required String itemId,
  }) async {
    if (sourceListId == destinationListId) {
      return;
    }
    final sourceList = await _repository.getById(sourceListId);
    final destinationList = await _repository.getById(destinationListId);
    if (sourceList == null || destinationList == null) {
      return;
    }
    final itemIndex = sourceList.items.indexWhere((item) => item.id == itemId);
    if (itemIndex < 0) {
      return;
    }
    final item = sourceList.items[itemIndex];
    final updatedSourceItems = [...sourceList.items]..removeAt(itemIndex);
    final updatedDestinationItems = [...destinationList.items, item];

    await _repository.upsertList(sourceList.copyWith(items: updatedSourceItems));
    await _repository.upsertList(
      destinationList.copyWith(items: updatedDestinationItems),
    );
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

  String _composeListName({
    required String name,
    String? emoji,
  }) {
    final trimmedEmoji = emoji?.trim() ?? '';
    if (trimmedEmoji.isEmpty) {
      return name;
    }
    return '$trimmedEmoji $name';
  }

  Future<void> _syncTaskerCache() async {
    final entries = state
        .map((list) => {'id': list.id, 'name': list.name})
        .toList(growable: false);
    try {
      await _channel.invokeMethod<void>('updateAvailableLists', {
        'list_entries': entries,
        'lists_json': jsonEncode(entries),
      });
    } catch (_) {
      // Ignore channel failures when Android host isn't available.
    }
  }

  Future<void> _pushOverlaySnapshot() async {
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (!active) {
        return;
      }
      await FlutterOverlayWindow.shareData({
        'type': 'all_lists_snapshot',
        'lists': state.map(_serializeList).toList(growable: false),
      });
    } catch (_) {
      // Overlay or host may be unavailable; skip push updates safely.
    }
  }

  Map<String, dynamic> _serializeList(QuickList list) {
    return {
      'id': list.id,
      'name': list.name,
      'items': list.items
          .map(
            (item) => {
              'id': item.id,
              'title': item.title,
              'quantity': item.quantity,
              'notes': item.notes,
              'is_completed': item.isCompleted,
            },
          )
          .toList(growable: false),
    };
  }
}
