class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final String currency;
  final String locale;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.isPremium,
    this.premiumExpiresAt,
    required this.currency,
    required this.locale,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar'],
      isPremium: json['is_premium'] ?? false,
      premiumExpiresAt: json['premium_expires_at'] != null
          ? DateTime.tryParse(json['premium_expires_at'].toString())
          : null,
      currency: json['currency'] ?? 'IDR',
      locale: json['locale'] ?? 'id',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'is_premium': isPremium,
        'premium_expires_at': premiumExpiresAt?.toIso8601String(),
        'currency': currency,
        'locale': locale,
      };

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? avatar,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    String? currency,
    String? locale,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      currency: currency ?? this.currency,
      locale: locale ?? this.locale,
    );
  }
}
