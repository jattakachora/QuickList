import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_tasker/core/storage/hive_setup.dart';
import 'package:todo_tasker/core/sync/sync_clock.dart';
import 'package:todo_tasker/features/lists/data/list_repository.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';
import 'package:todo_tasker/features/notifications/minimized_overlay_notification_service.dart';
import 'package:todo_tasker/features/overlay/overlay_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    with WidgetsBindingObserver {
  final ListRepository _repository = ListRepository();

  String? _targetListId;
  String? _targetListName;
  bool _isTargetLoaded = false;
  bool _loadingTarget = false;
  bool _isMinimizing = false;

  StreamSubscription<dynamic>? _overlaySubscription;
  Timer? _syncTimer;
  int _lastSyncClock = 0;
  int _lastTargetTriggerClock = 0;

  String? _snapshotListId;
  String? _snapshotListName;
  List<_OverlayItemSnapshot> _snapshotItems = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen(
      _handleOverlayMessage,
      onError: (_) {},
    );
    unawaited(_startup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadTarget());
    }
  }

  Future<void> _startup() async {
    await HiveSetup.ensureListsBoxOpen();
    _lastSyncClock = await SyncClock.read();
    _lastTargetTriggerClock = await _readTargetTriggerClock();

    _syncTimer = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      final currentSync = await SyncClock.read();
      final currentTrigger = await _readTargetTriggerClock();

      final syncChanged = currentSync != _lastSyncClock;
      final targetChanged = currentTrigger != _lastTargetTriggerClock;

      if (!syncChanged && !targetChanged) {
        return;
      }

      _lastSyncClock = currentSync;
      _lastTargetTriggerClock = currentTrigger;

      if (targetChanged) {
        await _loadTarget();
      } else {
        await _reloadActiveTarget();
      }
    });

    await _loadTarget();
  }

  Future<void> _loadTarget() async {
    if (_loadingTarget) {
      return;
    }
    _loadingTarget = true;

    try {
      await HiveSetup.ensureListsBoxOpen();

      String? targetId;
      String? targetName;
      final prefs = await SharedPreferences.getInstance();
      for (int attempt = 0; attempt < 20; attempt++) {
        await prefs.reload();
        targetId = prefs.getString(OverlayService.targetListIdKey)?.trim();
        targetName = prefs.getString(OverlayService.targetListNameKey)?.trim();
        if ((targetId != null && targetId.isNotEmpty) ||
            (targetName != null && targetName.isNotEmpty)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) {
        return;
      }

      _lastTargetTriggerClock = await _readTargetTriggerClock();

      setState(() {
        _targetListId =
            (targetId == null || targetId.isEmpty) ? null : targetId;
        _targetListName =
            (targetName == null || targetName.isEmpty) ? null : targetName;
        _snapshotListId = null;
        _snapshotListName = null;
        _snapshotItems = const [];
        _isTargetLoaded = true;
      });

      if (_targetListId == null && _targetListName == null) {
        await _closeOverlay();
        return;
      }

      await _reloadActiveTarget();
    } finally {
      _loadingTarget = false;
    }
  }

  Future<int> _readTargetTriggerClock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(OverlayService.targetTriggerClockKey) ?? 0;
  }

  Future<void> _reloadActiveTarget() async {
    await HiveSetup.ensureListsBoxOpen();

    QuickList? list;
    if (_targetListId != null && _targetListId!.isNotEmpty) {
      list = await _repository.getById(_targetListId!, forceRefresh: true);
    }
    list ??= (_targetListName == null || _targetListName!.isEmpty)
        ? null
        : await _repository.getByName(_targetListName!, forceRefresh: true);

    if (list == null || list.items.isEmpty) {
      if (mounted) {
        setState(() {
          _snapshotListId = null;
          _snapshotListName = null;
          _snapshotItems = const [];
          _isTargetLoaded = true;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _targetListId = list!.id;
      _targetListName = list.name;
      _snapshotListId = list.id;
      _snapshotListName = list.name;
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

  void _handleOverlayMessage(dynamic message) {
    if (!mounted || message is! Map) {
      return;
    }

    final type = message['type']?.toString();
    if (type == 'target_snapshot') {
      unawaited(_applyTargetFromMessage(message));
      return;
    }

    if (type == 'all_lists_snapshot') {
      final lists = (message['lists'] as List?)?.whereType<Map>().toList();
      if (lists == null || lists.isEmpty) {
        return;
      }

      Map? selected;
      if (_targetListId != null && _targetListId!.isNotEmpty) {
        selected = lists.firstWhere(
          (raw) => raw['id']?.toString() == _targetListId,
          orElse: () => const {},
        );
      }
      if ((selected == null || selected.isEmpty) &&
          _targetListName != null &&
          _targetListName!.isNotEmpty) {
        final normalized = _normalize(_targetListName!);
        selected = lists.firstWhere(
          (raw) => _normalize(raw['name']?.toString() ?? '') == normalized,
          orElse: () => const {},
        );
      }
      if (selected == null || selected.isEmpty) {
        return;
      }

      final parsed = _parseListSnapshot(selected);
      if (parsed == null) {
        return;
      }

      setState(() {
        _targetListId = parsed.id;
        _targetListName = parsed.name;
        _snapshotListId = parsed.id;
        _snapshotListName = parsed.name;
        _snapshotItems = parsed.items;
        _isTargetLoaded = true;
      });
      return;
    }

    if (type == 'refresh_target') {
      unawaited(_loadTarget());
    }
  }

  Future<void> _applyTargetFromMessage(Map message) async {
    final id = message['list_id']?.toString().trim();
    final name = message['list_name']?.toString().trim();
    if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
      return;
    }

    _lastTargetTriggerClock = await _readTargetTriggerClock();
    if (!mounted) {
      return;
    }

    setState(() {
      _targetListId = (id == null || id.isEmpty) ? _targetListId : id;
      _targetListName =
          (name == null || name.isEmpty) ? _targetListName : name;
    });
    await _reloadActiveTarget();
  }

  _OverlayListSnapshot? _parseListSnapshot(Map raw) {
    final id = raw['id']?.toString();
    final name = raw['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.trim().isEmpty) {
      return null;
    }

    final rawItems = raw['items'] as List?;
    final items = (rawItems ?? const [])
        .whereType<Map>()
        .map(
          (item) => _OverlayItemSnapshot(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            notes: item['notes']?.toString(),
            isCompleted: item['is_completed'] == true,
          ),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);

    return _OverlayListSnapshot(id: id, name: name.trim(), items: items);
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
    final maxHeight =
        (availableHeight < preferredHeight ? availableHeight : preferredHeight)
            .toDouble();

    final displayListId = _snapshotListId;
    final displayListName = _snapshotListName;
    final displayItems = _snapshotItems;
    final footerButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_minimizeOverlay());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: EdgeInsets.fromLTRB(12, topInset, 12, bottomInset),
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
                child: !_isTargetLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : (displayListId == null || displayItems.isEmpty)
                        ? _OverlayEmpty(
                            onClose: _closeOverlay,
                            onMinimize: _minimizeOverlay,
                          )
                        : Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 14, 10, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(30),
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
                                      tooltip: 'Minimize',
                                      onPressed: _minimizeOverlay,
                                      icon: const Icon(Icons.minimize_rounded),
                                    ),
                                    IconButton(
                                      tooltip: 'Dismiss',
                                      onPressed: _closeOverlay,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 10, 10, 12),
                                  itemCount: displayItems.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 2,
                                        ),
                                        value: item.isCompleted,
                                        title: Text(
                                          title,
                                          style: item.isCompleted
                                              ? TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
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
                                          await _reloadActiveTarget();
                                          unawaited(
                                            _notifyMainAppListChanged(
                                              displayListId,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: footerButtonStyle,
                                    onPressed: _minimizeOverlay,
                                    icon: const Icon(Icons.minimize_rounded),
                                    label: const Text('Minimize'),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _minimizeOverlay() async {
    if (_isMinimizing) {
      return;
    }
    _isMinimizing = true;

    try {
      QuickList? list;
      if (_snapshotListId != null && _snapshotListId!.isNotEmpty) {
        list = await _repository.getById(_snapshotListId!, forceRefresh: true);
      }
      if ((list == null || list.items.isEmpty) &&
          _targetListId != null &&
          _targetListId!.isNotEmpty) {
        list = await _repository.getById(_targetListId!, forceRefresh: true);
      }
      if ((list == null || list.items.isEmpty) &&
          _targetListName != null &&
          _targetListName!.trim().isNotEmpty) {
        list = await _repository.getByName(
          _targetListName!,
          forceRefresh: true,
        );
      }

      if (list != null) {
        await MinimizedOverlayNotificationService.instance
            .showMinimizedNotification(
          listId: list.id,
          listName: list.name,
          itemCount: list.items.length,
        );
      }

      await _closeOverlay();
    } finally {
      _isMinimizing = false;
    }
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

class _OverlayListSnapshot {
  const _OverlayListSnapshot({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<_OverlayItemSnapshot> items;
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
}

class _OverlayEmpty extends StatelessWidget {
  const _OverlayEmpty({
    required this.onClose,
    required this.onMinimize,
  });

  final Future<void> Function() onClose;
  final Future<void> Function() onMinimize;

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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onMinimize,
                    child: const Text('Minimize'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onClose,
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
