import 'package:hive/hive.dart';

// ── Debt Payment ──────────────────────────────────────────────────────────────

class DebtPaymentModel {
  String id;
  double amount;
  DateTime date;
  String? note;

  DebtPaymentModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });
}

class DebtPaymentModelAdapter extends TypeAdapter<DebtPaymentModel> {
  @override
  final int typeId = 7;

  @override
  DebtPaymentModel read(BinaryReader reader) {
    return DebtPaymentModel(
      id: reader.readString(),
      amount: reader.readDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      note: reader.read() as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DebtPaymentModel obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.write(obj.note);
  }
}

// ── Debt ──────────────────────────────────────────────────────────────────────

class DebtModel extends HiveObject {
  String id;
  String
      type; // 'debt' = saya berhutang | 'receivable' = orang berhutang ke saya
  String personName;
  double totalAmount;
  double remainingAmount;
  String? walletId;
  String? walletName;
  String? categoryId;
  String? categoryName;
  String? note;
  DateTime? deadline;
  String status; // 'active', 'paid'
  List<DebtPaymentModel> payments;
  DateTime createdAt;

  DebtModel({
    required this.id,
    required this.type,
    required this.personName,
    required this.totalAmount,
    required this.remainingAmount,
    this.walletId,
    this.walletName,
    this.categoryId,
    this.categoryName,
    this.note,
    this.deadline,
    required this.status,
    required this.payments,
    required this.createdAt,
  });
}

class DebtModelAdapter extends TypeAdapter<DebtModel> {
  @override
  final int typeId = 6;

  @override
  DebtModel read(BinaryReader reader) {
    final paymentCount = reader.readInt();
    final payments = List.generate(
      paymentCount,
      (_) => DebtPaymentModelAdapter().read(reader),
    );
    final deadlineMs = reader.read() as int?;

    return DebtModel(
      id: reader.readString(),
      type: reader.readString(),
      personName: reader.readString(),
      totalAmount: reader.readDouble(),
      remainingAmount: reader.readDouble(),
      walletId: reader.read() as String?,
      walletName: reader.read() as String?,
      categoryId: reader.read() as String?,
      categoryName: reader.read() as String?,
      note: reader.read() as String?,
      deadline: deadlineMs != null
          ? DateTime.fromMillisecondsSinceEpoch(deadlineMs)
          : null,
      status: reader.readString(),
      payments: payments,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, DebtModel obj) {
    writer.writeInt(obj.payments.length);
    for (final p in obj.payments) {
      DebtPaymentModelAdapter().write(writer, p);
    }
    writer.write(obj.deadline?.millisecondsSinceEpoch);
    writer.writeString(obj.id);
    writer.writeString(obj.type);
    writer.writeString(obj.personName);
    writer.writeDouble(obj.totalAmount);
    writer.writeDouble(obj.remainingAmount);
    writer.write(obj.walletId);
    writer.write(obj.walletName);
    writer.write(obj.categoryId);
    writer.write(obj.categoryName);
    writer.write(obj.note);
    writer.writeString(obj.status);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
