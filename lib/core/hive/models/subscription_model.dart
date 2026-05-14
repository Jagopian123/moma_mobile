import 'package:hive/hive.dart';

class SubscriptionModel extends HiveObject {
  String id;
  String name;
  String icon;      // emoji
  String category;
  double amount;
  String cycle;     // monthly, yearly, weekly
  DateTime startDate;
  DateTime nextBillingDate;
  String? walletId;
  String? walletName;
  String status;    // active, paused, cancelled
  String? note;
  DateTime createdAt;
  int color;        // brand/custom color sebagai int (0xFFRRGGBB)

  SubscriptionModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    required this.amount,
    required this.cycle,
    required this.startDate,
    required this.nextBillingDate,
    this.walletId,
    this.walletName,
    this.status = 'active',
    this.note,
    required this.createdAt,
    this.color = 0xFF2563EB,
  });
}

class SubscriptionModelAdapter extends TypeAdapter<SubscriptionModel> {
  @override
  final int typeId = 9;

  @override
  SubscriptionModel read(BinaryReader reader) {
    return SubscriptionModel(
      id: reader.readString(),
      name: reader.readString(),
      icon: reader.readString(),
      category: reader.readString(),
      amount: reader.readDouble(),
      cycle: reader.readString(),
      startDate: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      nextBillingDate: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      walletId: reader.read() as String?,
      walletName: reader.read() as String?,
      status: reader.readString(),
      note: reader.read() as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      color: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, SubscriptionModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.icon);
    writer.writeString(obj.category);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.cycle);
    writer.writeInt(obj.startDate.millisecondsSinceEpoch);
    writer.writeInt(obj.nextBillingDate.millisecondsSinceEpoch);
    writer.write(obj.walletId);
    writer.write(obj.walletName);
    writer.writeString(obj.status);
    writer.write(obj.note);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.color);
  }
}
