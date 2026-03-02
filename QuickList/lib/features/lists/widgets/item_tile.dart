import 'package:flutter/material.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onTap,
  });

  final QuickListItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final doneStyle = textStyle?.copyWith(
      decoration: TextDecoration.lineThrough,
      color: Theme.of(context).colorScheme.outline,
    );
    return ListTile(
      onTap: onTap,
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Checkbox(
          key: ValueKey<bool>(item.isCompleted),
          value: item.isCompleted,
          onChanged: (_) => onToggle(),
        ),
      ),
      title: Text(item.title, style: item.isCompleted ? doneStyle : textStyle),
      subtitle: Text(
        [
          'Qty: ${item.quantity}',
          if (item.notes != null && item.notes!.isNotEmpty) item.notes!,
        ].join('  •  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.drag_indicator),
    );
  }
}
