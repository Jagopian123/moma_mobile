import 'package:hive/hive.dart';

class BudgetModel extends HiveObject {
  String id;
  String categoryId;
  String categoryName;
  String categoryIcon;
  String categoryColor;
  double limitAmount;
  String period; // 'monthly', 'weekly'
  DateTime startDate;
  DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.limitAmount,
    required this.period,
    required this.startDate,
    required this.createdAt,
  });
}

class BudgetModelAdapter extends TypeAdapter<BudgetModel> {
  @override
  final int typeId = 3;

  @override
  BudgetModel read(BinaryReader reader) {
    return BudgetModel(
      id: reader.readString(),
      categoryId: reader.readString(),
      categoryName: reader.readString(),
      categoryIcon: reader.readString(),
      categoryColor: reader.readString(),
      limitAmount: reader.readDouble(),
      period: reader.readString(),
      startDate: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, BudgetModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.categoryId);
    writer.writeString(obj.categoryName);
    writer.writeString(obj.categoryIcon);
    writer.writeString(obj.categoryColor);
    writer.writeDouble(obj.limitAmount);
    writer.writeString(obj.period);
    writer.writeInt(obj.startDate.millisecondsSinceEpoch);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
