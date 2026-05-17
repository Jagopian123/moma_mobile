import 'package:hive/hive.dart';

class InAppNotificationModel extends HiveObject {
  String id;
  String type; // 'budget', 'subscription', 'debt'
  String title;
  String body;
  bool isRead;
  DateTime createdAt;

  InAppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });
}

class InAppNotificationModelAdapter
    extends TypeAdapter<InAppNotificationModel> {
  @override
  final int typeId = 10;

  @override
  InAppNotificationModel read(BinaryReader reader) {
    return InAppNotificationModel(
      id: reader.readString(),
      type: reader.readString(),
      title: reader.readString(),
      body: reader.readString(),
      isRead: reader.readBool(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, InAppNotificationModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.type);
    writer.writeString(obj.title);
    writer.writeString(obj.body);
    writer.writeBool(obj.isRead);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
