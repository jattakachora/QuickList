import 'package:hive/hive.dart';
import 'package:todo_tasker/features/items/models/list_item.dart';

class QuickList {
  QuickList({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.position,
  });

  final String id;
  final String name;
  final List<QuickListItem> items;
  final DateTime createdAt;
  final int position;

  int get activeCount => items.where((item) => !item.isCompleted).length;
  int get completedCount => items.where((item) => item.isCompleted).length;

  QuickList copyWith({
    String? id,
    String? name,
    List<QuickListItem>? items,
    DateTime? createdAt,
    int? position,
  }) {
    return QuickList(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? List<QuickListItem>.from(this.items),
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
    );
  }
}

class QuickListAdapter extends TypeAdapter<QuickList> {
  static const int typeIdConst = 2;

  @override
  final int typeId = typeIdConst;

  @override
  QuickList read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (int i = 0, count = reader.readByte(); i < count; i++)
        reader.readByte(): reader.read(),
    };
    return QuickList(
      id: fields[0] as String,
      name: fields[1] as String,
      items: (fields[2] as List).cast<QuickListItem>(),
      createdAt: fields[3] as DateTime,
      position: fields[4] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, QuickList obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.position);
  }
}
