import 'package:hive/hive.dart';

class QuickListItem {
  QuickListItem({
    required this.id,
    required this.title,
    this.quantity = 1,
    this.notes,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final int quantity;
  final String? notes;
  final bool isCompleted;

  QuickListItem copyWith({
    String? id,
    String? title,
    int? quantity,
    String? notes,
    bool? isCompleted,
    bool clearNotes = false,
  }) {
    return QuickListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      quantity: quantity ?? this.quantity,
      notes: clearNotes ? null : (notes ?? this.notes),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class QuickListItemAdapter extends TypeAdapter<QuickListItem> {
  static const int typeIdConst = 1;

  @override
  final int typeId = typeIdConst;

  @override
  QuickListItem read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (int i = 0, count = reader.readByte(); i < count; i++)
        reader.readByte(): reader.read(),
    };
    return QuickListItem(
      id: fields[0] as String,
      title: fields[1] as String,
      quantity: fields[2] as int,
      notes: fields[3] as String?,
      isCompleted: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QuickListItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.isCompleted);
  }
}
