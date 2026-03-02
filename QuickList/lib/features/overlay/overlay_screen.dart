import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_tasker/core/storage/hive_setup.dart';
import 'package:todo_tasker/features/lists/data/list_repository.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';
import 'package:todo_tasker/features/overlay/overlay_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  final ListRepository _repository = ListRepository();
  String? _targetListName;
  bool _isTargetLoaded = false;
  StreamSubscription<dynamic>? _overlaySubscription;
  String? _snapshotListId;
  String? _snapshotListName;
  List<_OverlayItemSnapshot> _snapshotItems = const [];

  @override
  void initState() {
    super.initState();
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen(
      _handleOverlayMessage,
      onError: (_) {},
    );
    _loadTarget();
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTarget() async {
    String? target;
    final prefs = await SharedPreferences.getInstance();
    for (int attempt = 0; attempt < 8; attempt++) {
      target = prefs.getString(OverlayService.targetListNameKey)?.trim();
      if (target != null && target.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (mounted) {
      setState(() {
        _targetListName = (target == null || target.isEmpty) ? null : target;
        _isTargetLoaded = true;
      });
    }
  }

  void _handleOverlayMessage(dynamic message) {
    if (!mounted || message is! Map) {
      return;
    }
    final type = message['type']?.toString();
    if (type != 'target_snapshot') {
      return;
    }
    final incoming = message['list_name']?.toString().trim();
    if (incoming == null || incoming.isEmpty) {
      return;
    }
    final listId = message['list_id']?.toString();
    final rawItems = message['items'] as List?;
    final parsedItems = (rawItems ?? const [])
        .whereType<Map>()
        .map(
          (raw) => _OverlayItemSnapshot(
            id: raw['id']?.toString() ?? '',
            title: raw['title']?.toString() ?? '',
            quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
            notes: raw['notes']?.toString(),
            isCompleted: raw['is_completed'] == true,
          ),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
    setState(() {
      _targetListName = incoming;
      _isTargetLoaded = true;
      _snapshotListId = listId;
      _snapshotListName = incoming;
      _snapshotItems = parsedItems;
    });
  }

  QuickList? _findTargetList(Iterable<QuickList> lists) {
    if (_targetListName == null || _targetListName!.trim().isEmpty) {
      return null;
    }
    final target = _normalize(_targetListName!);
    for (final list in lists) {
      if (_normalize(list.name) == target) {
        return list;
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.viewPadding.top > 0 ? media.viewPadding.top : 56.0;
    final safeBottom =
        media.viewPadding.bottom > 0 ? media.viewPadding.bottom : 12.0;
    final topInset = (safeTop + 74.0).clamp(126.0, 200.0).toDouble();
    final bottomInset = safeBottom + 10.0;
    final availableHeight = media.size.height - topInset - bottomInset;
    final preferredHeight = media.size.height * 0.62;
    final maxHeight = (availableHeight < preferredHeight
            ? availableHeight
            : preferredHeight)
        .toDouble();
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          topInset,
          12,
          bottomInset,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: maxHeight < 360 ? 360 : maxHeight,
            ),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ValueListenableBuilder<Box<QuickList>>(
                valueListenable: HiveSetup.listsBox.listenable(),
                builder: (context, box, _) {
                  if (!_isTargetLoaded) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final hiveList = _findTargetList(box.values);
                  final useSnapshot = _snapshotListId != null &&
                      _snapshotListName != null &&
                      _targetListName != null &&
                      _normalize(_snapshotListName!) ==
                          _normalize(_targetListName!);

                  final displayListId =
                      useSnapshot ? _snapshotListId : hiveList?.id;
                  final displayListName =
                      useSnapshot ? _snapshotListName : hiveList?.name;
                  final displayItems = useSnapshot
                      ? _snapshotItems
                      : (hiveList?.items
                              .map(
                                (item) => _OverlayItemSnapshot(
                                  id: item.id,
                                  title: item.title,
                                  quantity: item.quantity,
                                  notes: item.notes,
                                  isCompleted: item.isCompleted,
                                ),
                              )
                              .toList(growable: false) ??
                          const <_OverlayItemSnapshot>[]);

                  if (displayListId == null || displayItems.isEmpty) {
                    return _OverlayEmpty(onClose: _closeOverlay);
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayListName ?? 'QuickList',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      '${displayItems.length} items',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _closeOverlay();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                          itemCount: displayItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = displayItems[index];
                            final title = item.quantity > 1
                                ? '${item.title} x${item.quantity}'
                                : item.title;
                            return Material(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                value: item.isCompleted,
                                title: Text(
                                  title,
                                  style: item.isCompleted
                                      ? TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        )
                                      : null,
                                ),
                                subtitle: item.notes == null
                                    ? null
                                    : Text(item.notes!),
                                onChanged: (_) async {
                                  await _repository.toggleItemFromOverlay(
                                    listId: displayListId,
                                    itemId: item.id,
                                  );
                                  await _reloadSnapshotFromStore(displayListId);
                                  unawaited(
                                    _notifyMainAppListChanged(displayListId),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _repository.clearCompleted(displayListId);
                                  await _reloadSnapshotFromStore(displayListId);
                                  unawaited(
                                    _notifyMainAppListChanged(displayListId),
                                  );
                                },
                                icon:
                                    const Icon(Icons.cleaning_services_outlined),
                                label: const Text('Clear completed'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  _closeOverlay();
                                },
                                child: const Text('Dismiss'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _reloadSnapshotFromStore(String listId) async {
    final list = await _repository.getById(listId, forceRefresh: true);
    if (list == null || !mounted) {
      return;
    }
    setState(() {
      _snapshotListId = list.id;
      _snapshotListName = list.name;
      _targetListName = list.name;
      _snapshotItems = list.items
          .map(
            (item) => _OverlayItemSnapshot(
              id: item.id,
              title: item.title,
              quantity: item.quantity,
              notes: item.notes,
              isCompleted: item.isCompleted,
            ),
          )
          .toList(growable: false);
      _isTargetLoaded = true;
    });
  }

  Future<void> _notifyMainAppListChanged(String listId) async {
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'overlay_list_changed',
        'list_id': listId,
      });
    } catch (_) {
      // Main app engine may be detached; overlay actions should still work.
    }
  }
}

class _OverlayItemSnapshot {
  const _OverlayItemSnapshot({
    required this.id,
    required this.title,
    required this.quantity,
    required this.notes,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final int quantity;
  final String? notes;
  final bool isCompleted;

  _OverlayItemSnapshot copyWith({
    String? id,
    String? title,
    int? quantity,
    String? notes,
    bool? isCompleted,
  }) {
    return _OverlayItemSnapshot(
      id: id ?? this.id,
      title: title ?? this.title,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class _OverlayEmpty extends StatelessWidget {
  const _OverlayEmpty({required this.onClose});

  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 52),
            const SizedBox(height: 12),
            Text(
              'List Empty Or Missing',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'QuickList cannot show a popup for an empty list.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                onClose();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
