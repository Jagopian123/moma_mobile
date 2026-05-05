import 'package:hive/hive.dart';

// ── Contribution ─────────────────────────────────────────────────────────────

class ContributionModel {
  String id;
  double amount;
  DateTime date;

  ContributionModel({
    required this.id,
    required this.amount,
    required this.date,
  });
}

class ContributionModelAdapter extends TypeAdapter<ContributionModel> {
  @override
  final int typeId = 5;

  @override
  ContributionModel read(BinaryReader reader) {
    return ContributionModel(
      id: reader.readString(),
      amount: reader.readDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, ContributionModel obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
  }
}

// ── Financial Plan ────────────────────────────────────────────────────────────

class FinancialPlanModel extends HiveObject {
  String id;
  String name;
  String icon;
  String color;
  double targetAmount;
  double savedAmount;
  DateTime? deadline;
  List<ContributionModel> contributions;
  DateTime createdAt;

  FinancialPlanModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.targetAmount,
    required this.savedAmount,
    this.deadline,
    required this.contributions,
    required this.createdAt,
  });
}

class FinancialPlanModelAdapter extends TypeAdapter<FinancialPlanModel> {
  @override
  final int typeId = 4;

  @override
  FinancialPlanModel read(BinaryReader reader) {
    final contributionCount = reader.readInt();
    final contributions = List.generate(
      contributionCount,
      (_) => ContributionModelAdapter().read(reader),
    );
    final deadlineMs = reader.read() as int?;

    return FinancialPlanModel(
      id: reader.readString(),
      name: reader.readString(),
      icon: reader.readString(),
      color: reader.readString(),
      targetAmount: reader.readDouble(),
      savedAmount: reader.readDouble(),
      deadline: deadlineMs != null
          ? DateTime.fromMillisecondsSinceEpoch(deadlineMs)
          : null,
      contributions: contributions,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, FinancialPlanModel obj) {
    writer.writeInt(obj.contributions.length);
    for (final c in obj.contributions) {
      ContributionModelAdapter().write(writer, c);
    }
    writer.write(obj.deadline?.millisecondsSinceEpoch);
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.icon);
    writer.writeString(obj.color);
    writer.writeDouble(obj.targetAmount);
    writer.writeDouble(obj.savedAmount);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
