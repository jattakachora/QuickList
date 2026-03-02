import 'package:flutter/material.dart';
import 'package:todo_tasker/features/lists/models/quick_list.dart';

class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.list,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final QuickList list;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      list.items.isEmpty
                          ? 'No items yet'
                          : '${list.activeCount} active, ${list.completedCount} done',
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${list.items.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
