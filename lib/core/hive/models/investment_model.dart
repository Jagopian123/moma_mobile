import 'package:hive/hive.dart';

class InvestmentModel extends HiveObject {
  String id;
  String name;
  String type; // 'gold', 'stock', 'mutual_fund', 'sbn', 'deposit', 'crypto'
  double currentValue;
  DateTime createdAt;
  DateTime updatedAt;

  InvestmentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.currentValue,
    required this.createdAt,
    required this.updatedAt,
  });
}

class InvestmentModelAdapter extends TypeAdapter<InvestmentModel> {
  @override
  final int typeId = 8;

  @override
  InvestmentModel read(BinaryReader reader) {
    return InvestmentModel(
      id: reader.readString(),
      name: reader.readString(),
      type: reader.readString(),
      currentValue: reader.readDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, InvestmentModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.type);
    writer.writeDouble(obj.currentValue);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
