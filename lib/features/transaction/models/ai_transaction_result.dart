class AiTransactionResult {
  final String type;
  final String title;
  final double amount;
  final String categoryName;
  final String categoryIcon;
  final String? walletHint;
  final String? toWalletHint;
  final String? description;
  /// Tanggal yang diekstrak AI dari input user (null = pakai DateTime.now())
  final DateTime? date;

  const AiTransactionResult({
    required this.type,
    required this.title,
    required this.amount,
    required this.categoryName,
    required this.categoryIcon,
    this.walletHint,
    this.toWalletHint,
    this.description,
    this.date,
  });

  factory AiTransactionResult.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['date'] as String?;
    if (rawDate != null && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    return AiTransactionResult(
      type: json['type'] as String? ?? 'expense',
      title: json['title'] as String? ?? 'Transaksi',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      categoryName: json['category_name'] as String? ?? 'Lainnya',
      categoryIcon: json['category_icon'] as String? ?? '📝',
      walletHint: json['wallet_hint'] as String?,
      toWalletHint: json['to_wallet_hint'] as String?,
      description: json['description'] as String?,
      date: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'amount': amount,
        'category_name': categoryName,
        'category_icon': categoryIcon,
        'wallet_hint': walletHint,
        'to_wallet_hint': toWalletHint,
        'description': description,
        'date': date?.toIso8601String(),
      };

  AiTransactionResult copyWith({double? amount}) {
    return AiTransactionResult(
      type: type,
      title: title,
      amount: amount ?? this.amount,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      walletHint: walletHint,
      toWalletHint: toWalletHint,
      description: description,
      date: date,
    );
  }

  static List<AiTransactionResult> fromJsonList(List<dynamic> list) {
    return list
        .map((e) => AiTransactionResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
