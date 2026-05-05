import 'package:hive/hive.dart';

class CategoryModel extends HiveObject {
  String id;
  String name;
  String icon;
  String color;
  String? parentId;
  String type; // 'expense', 'income', 'both'
  bool isDefault;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.parentId,
    required this.type,
    required this.isDefault,
  });
}

class CategoryModelAdapter extends TypeAdapter<CategoryModel> {
  @override
  final int typeId = 2;

  @override
  CategoryModel read(BinaryReader reader) {
    return CategoryModel(
      id: reader.readString(),
      name: reader.readString(),
      icon: reader.readString(),
      color: reader.readString(),
      parentId: reader.read() as String?,
      type: reader.readString(),
      isDefault: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, CategoryModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.icon);
    writer.writeString(obj.color);
    writer.write(obj.parentId);
    writer.writeString(obj.type);
    writer.writeBool(obj.isDefault);
  }
}
