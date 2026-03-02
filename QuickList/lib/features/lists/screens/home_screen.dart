import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';
import 'package:todo_tasker/features/lists/providers/lists_provider.dart';
import 'package:todo_tasker/features/lists/screens/list_detail_screen.dart';
import 'package:todo_tasker/features/lists/widgets/empty_state.dart';
import 'package:todo_tasker/features/lists/widgets/list_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _overlayPermissionGranted = true;
  bool _permissionCheckDone = false;
  bool _permissionDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions(showDialogIfMissing: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);
    final filtered = _filterLists(lists, _query);

    return Scaffold(
      appBar: AppBar(title: const Text('QuickList')),
      body: Column(
        children: [
          if (_permissionCheckDone && !_overlayPermissionGranted)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Overlay permission is required for Tasker popup to work in background.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _requestOverlayPermission,
                    child: const Text('Grant'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search lists',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  _query = value.trim();
                });
              },
            ),
          ),
          Expanded(
            child: lists.isEmpty
                ? const EmptyState(
                    title: 'No Lists Yet',
                    message: 'Create your first list with the + button.',
                  )
                : filtered.isEmpty
                    ? const EmptyState(
                        title: 'No Matches',
                        message: 'Try a different search term.',
                      )
                    : _query.isEmpty
                        ? ReorderableListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: lists.length,
                            onReorder: (oldIndex, newIndex) => ref
                                .read(listsProvider.notifier)
                                .reorderLists(
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                ),
                            itemBuilder: (context, index) {
                              final list = lists[index];
                              return _ListCardWrapper(
                                key: ValueKey('list_${list.id}'),
                                child: _buildListCard(context, ref, list),
                              );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final list = filtered[index];
                              return _ListCardWrapper(
                                child: _buildListCard(context, ref, list),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showListDialog(
          context,
          title: 'New List',
          onSubmit: (value) => ref.read(listsProvider.notifier).createList(
                value,
              ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add List'),
      ),
    );
  }

  Future<void> _checkPermissions({required bool showDialogIfMissing}) async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!mounted) {
      return;
    }
    setState(() {
      _overlayPermissionGranted = granted;
      _permissionCheckDone = true;
    });

    if (showDialogIfMissing && !granted && !_permissionDialogShown && mounted) {
      _permissionDialogShown = true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'QuickList needs "Draw over other apps" permission so Tasker can show your list popup even when QuickList is in background or closed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _requestOverlayPermission();
              },
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    if (granted == true) {
      await _checkPermissions(showDialogIfMissing: false);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _checkPermissions(showDialogIfMissing: false);
    }
  }

  List<QuickList> _filterLists(List<QuickList> lists, String query) {
    if (query.isEmpty) {
      return lists;
    }
    final q = query.toLowerCase();
    return lists.where((list) => list.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _showListDialog(
    BuildContext context, {
    required String title,
    required Future<void> Function(String value) onSubmit,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'List name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await onSubmit(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListCard(
    BuildContext context,
    WidgetRef ref,
    QuickList list,
  ) {
    return ListCard(
      list: list,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListDetailScreen(listId: list.id),
          ),
        );
      },
      onDelete: () => ref.read(listsProvider.notifier).removeList(list.id),
      onRename: () => _showListDialog(
        context,
        title: 'Rename List',
        initial: list.name,
        onSubmit: (value) =>
            ref.read(listsProvider.notifier).renameList(listId: list.id, name: value),
      ),
    );
  }
}

class _ListCardWrapper extends StatelessWidget {
  const _ListCardWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }
}
