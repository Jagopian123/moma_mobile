class AiTransactionResult {
  final String type;
  final String title;
  final double amount;
  final String categoryName;
  final String categoryIcon;
  final String? walletHint;
  final String? toWalletHint;
  final String? description;

  const AiTransactionResult({
    required this.type,
    required this.title,
    required this.amount,
    required this.categoryName,
    required this.categoryIcon,
    this.walletHint,
    this.toWalletHint,
    this.description,
  });

  factory AiTransactionResult.fromJson(Map<String, dynamic> json) {
    return AiTransactionResult(
      type: json['type'] as String? ?? 'expense',
      title: json['title'] as String? ?? 'Transaksi',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      categoryName: json['category_name'] as String? ?? 'Lainnya',
      categoryIcon: json['category_icon'] as String? ?? '📝',
      walletHint: json['wallet_hint'] as String?,
      toWalletHint: json['to_wallet_hint'] as String?,
      description: json['description'] as String?,
    );
  }

  static List<AiTransactionResult> fromJsonList(List<dynamic> list) {
    return list
        .map((e) => AiTransactionResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
