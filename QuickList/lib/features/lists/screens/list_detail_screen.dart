import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';
import 'package:todo_tasker/features/lists/providers/lists_provider.dart';
import 'package:todo_tasker/features/lists/widgets/empty_state.dart';
import 'package:todo_tasker/features/lists/widgets/item_tile.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({
    super.key,
    required this.listId,
  });

  final String listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  final TextEditingController _quickAddController = TextEditingController();
  int _draftQuantity = 1;
  String _draftNotes = '';

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);
    QuickList? list;
    for (final current in lists) {
      if (current.id == widget.listId) {
        list = current;
        break;
      }
    }
    if (list == null) {
      return const Scaffold(
        body: EmptyState(
          title: 'List Not Found',
          message: 'This list may have been deleted.',
        ),
      );
    }
    final activeList = list;

    return PopScope(
      onPopInvokedWithResult: (_, __) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(activeList.name),
          actions: [
            IconButton(
              tooltip: 'Clear completed',
              onPressed: activeList.completedCount == 0
                  ? null
                  : () => ref
                      .read(listsProvider.notifier)
                      .clearCompleted(activeList.id),
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
          ],
        ),
        body: activeList.items.isEmpty
            ? const EmptyState(
                title: 'No Items Yet',
                message: 'Use the bottom bar to add your first item.',
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: activeList.items.length,
                onReorder: (oldIndex, newIndex) => ref
                    .read(listsProvider.notifier)
                    .reorderItems(
                      listId: activeList.id,
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                    ),
                itemBuilder: (context, index) {
                  final item = activeList.items[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    background: Container(
                      color: Theme.of(context).colorScheme.errorContainer,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onDismissed: (_) {
                      ref.read(listsProvider.notifier).removeItem(
                            listId: activeList.id,
                            itemId: item.id,
                          );
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          content: Text('"${item.title}" deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              ref.read(listsProvider.notifier).addItem(
                                    listId: activeList.id,
                                    title: item.title,
                                    quantity: item.quantity,
                                    notes: item.notes,
                                  );
                            },
                          ),
                        ),
                      );
                    },
                    child: ItemTile(
                      key: ValueKey('tile_${item.id}'),
                      item: item,
                      onToggle: () => ref.read(listsProvider.notifier).toggleItem(
                            listId: activeList.id,
                            itemId: item.id,
                          ),
                      onTap: () => _showItemDialog(
                        context,
                        listId: activeList.id,
                        item: item,
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Quantity & notes',
                    onPressed: _showQuickOptionsSheet,
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _quickAddController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendQuickItem(activeList.id),
                      decoration: InputDecoration(
                        hintText:
                            'Add item (x$_draftQuantity${_draftNotes.isNotEmpty ? ', with note' : ''})',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: () => _sendQuickItem(activeList.id),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendQuickItem(String listId) async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty) {
      return;
    }
    await ref.read(listsProvider.notifier).addItem(
          listId: listId,
          title: text,
          quantity: _draftQuantity,
          notes: _draftNotes,
        );
    _quickAddController.clear();
  }

  Future<void> _showQuickOptionsSheet() async {
    final qtyController = TextEditingController(text: '$_draftQuantity');
    final notesController = TextEditingController(text: _draftNotes);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quick Add Options',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 1;
                        setState(() {
                          _draftQuantity = qty < 1 ? 1 : qty;
                          _draftNotes = notesController.text.trim();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showItemDialog(
    BuildContext context, {
    required String listId,
    required QuickListItem item,
  }) async {
    final titleController = TextEditingController(text: item.title);
    final qtyController = TextEditingController(text: '${item.quantity}');
    final notesController = TextEditingController(text: item.notes ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Item title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? 1;
                        await ref.read(listsProvider.notifier).editItem(
                              listId: listId,
                              itemId: item.id,
                              title: titleController.text,
                              quantity: qty < 1 ? 1 : qty,
                              notes: notesController.text,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}