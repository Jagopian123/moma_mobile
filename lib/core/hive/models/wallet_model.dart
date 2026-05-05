import 'package:hive/hive.dart';

class WalletModel extends HiveObject {
  String id;
  String name;
  String type; // 'bank', 'ewallet', 'cash'
  double balance;
  String icon;
  String color;
  String? bankName;
  String? accountNumber;
  DateTime createdAt;
  DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
    this.bankName,
    this.accountNumber,
    required this.createdAt,
    required this.updatedAt,
  });
}

class WalletModelAdapter extends TypeAdapter<WalletModel> {
  @override
  final int typeId = 0;

  @override
  WalletModel read(BinaryReader reader) {
    return WalletModel(
      id: reader.readString(),
      name: reader.readString(),
      type: reader.readString(),
      balance: reader.readDouble(),
      icon: reader.readString(),
      color: reader.readString(),
      bankName: reader.read() as String?,
      accountNumber: reader.read() as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, WalletModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.type);
    writer.writeDouble(obj.balance);
    writer.writeString(obj.icon);
    writer.writeString(obj.color);
    writer.write(obj.bankName);
    writer.write(obj.accountNumber);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
