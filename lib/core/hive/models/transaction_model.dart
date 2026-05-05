import 'package:hive/hive.dart';

class TransactionModel extends HiveObject {
  String id;
  String title;
  String type; // 'expense', 'income', 'transfer'
  double amount;
  String categoryId;
  String categoryName;
  String categoryIcon;
  String walletId;
  String walletName;
  String? toWalletId;
  String? toWalletName;
  double? adminFee;
  String? description;
  DateTime date;
  DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.walletId,
    required this.walletName,
    this.toWalletId,
    this.toWalletName,
    this.adminFee,
    this.description,
    required this.date,
    required this.createdAt,
  });
}

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 1;

  @override
  TransactionModel read(BinaryReader reader) {
    return TransactionModel(
      id: reader.readString(),
      title: reader.readString(),
      type: reader.readString(),
      amount: reader.readDouble(),
      categoryId: reader.readString(),
      categoryName: reader.readString(),
      categoryIcon: reader.readString(),
      walletId: reader.readString(),
      walletName: reader.readString(),
      toWalletId: reader.read() as String?,
      toWalletName: reader.read() as String?,
      adminFee: reader.read() as double?,
      description: reader.read() as String?,
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.type);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.categoryId);
    writer.writeString(obj.categoryName);
    writer.writeString(obj.categoryIcon);
    writer.writeString(obj.walletId);
    writer.writeString(obj.walletName);
    writer.write(obj.toWalletId);
    writer.write(obj.toWalletName);
    writer.write(obj.adminFee);
    writer.write(obj.description);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
