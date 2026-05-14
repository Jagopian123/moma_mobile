import 'hive_service.dart';
import 'models/category_model.dart';

class CategorySeeder {
  static Future<void> seed() async {
    final box = HiveService.categories;
    if (box.isNotEmpty) return;

    final categories = _buildCategories();
    for (final category in categories) {
      await box.put(category.id, category);
    }
  }

  static List<CategoryModel> _buildCategories() {
    final List<CategoryModel> result = [];

    final data = [
      {
        'id': 'cat_food',
        'name': 'Makanan & Minuman',
        'icon': '🍽️',
        'color': '#FF6B6B',
        'type': 'expense',
        'subs': [
          {'id': 'sub_daily_food', 'name': 'Makan Harian', 'icon': '🍱'},
          {'id': 'sub_snack', 'name': 'Jajan / Snack', 'icon': '🍿'},
          {'id': 'sub_drink', 'name': 'Minuman', 'icon': '🥤'},
          {'id': 'sub_coffee', 'name': 'Kopi / Café', 'icon': '☕'},
          {'id': 'sub_restaurant', 'name': 'Restoran', 'icon': '🍴'},
          {'id': 'sub_delivery', 'name': 'Delivery Makanan', 'icon': '🛵'},
          {'id': 'sub_groceries', 'name': 'Bahan Masakan', 'icon': '🛒'},
        ],
      },
      {
        'id': 'cat_household',
        'name': 'Kebutuhan Rumah Tangga',
        'icon': '🏠',
        'color': '#4ECDC4',
        'type': 'expense',
        'subs': [
          {'id': 'sub_monthly_shop', 'name': 'Belanja Bulanan', 'icon': '🛍️'},
          {'id': 'sub_soap', 'name': 'Sabun & Kebersihan', 'icon': '🧼'},
          {'id': 'sub_tools', 'name': 'Peralatan Rumah', 'icon': '🔧'},
          {'id': 'sub_furniture', 'name': 'Perabotan', 'icon': '🪑'},
          {'id': 'sub_electricity', 'name': 'Listrik', 'icon': '⚡'},
          {'id': 'sub_water', 'name': 'Air (PDAM)', 'icon': '💧'},
          {'id': 'sub_gas', 'name': 'Gas LPG', 'icon': '🔥'},
          {'id': 'sub_internet', 'name': 'Internet & WiFi', 'icon': '📶'},
        ],
      },
      {
        'id': 'cat_transport',
        'name': 'Transportasi',
        'icon': '🚗',
        'color': '#45B7D1',
        'type': 'expense',
        'subs': [
          {'id': 'sub_fuel', 'name': 'Bensin', 'icon': '⛽'},
          {'id': 'sub_parking', 'name': 'Parkir', 'icon': '🅿️'},
          {'id': 'sub_toll', 'name': 'Tol', 'icon': '🛣️'},
          {'id': 'sub_ojol', 'name': 'Transportasi Online', 'icon': '🛵'},
          {'id': 'sub_public', 'name': 'Angkutan Umum', 'icon': '🚌'},
          {'id': 'sub_service', 'name': 'Servis Kendaraan', 'icon': '🔩'},
          {'id': 'sub_tax_vehicle', 'name': 'Pajak Kendaraan', 'icon': '📋'},
        ],
      },
      {
        'id': 'cat_finance',
        'name': 'Keuangan & Tagihan',
        'icon': '💳',
        'color': '#96CEB4',
        'type': 'expense',
        'subs': [
          {'id': 'sub_installment', 'name': 'Cicilan', 'icon': '📆'},
          {'id': 'sub_credit_card', 'name': 'Kartu Kredit', 'icon': '💳'},
          {'id': 'sub_insurance', 'name': 'Asuransi', 'icon': '🛡️'},
          {'id': 'sub_tax', 'name': 'Pajak', 'icon': '🏛️'},
          {'id': 'sub_bank_admin', 'name': 'Admin Bank', 'icon': '🏦'},
          {'id': 'sub_transfer_fee', 'name': 'Biaya Transfer', 'icon': '💸'},
        ],
      },
      {
        'id': 'cat_education',
        'name': 'Pendidikan',
        'icon': '🎓',
        'color': '#FFEAA7',
        'type': 'expense',
        'subs': [
          {'id': 'sub_tuition', 'name': 'Uang Sekolah / Kuliah', 'icon': '🎓'},
          {'id': 'sub_books', 'name': 'Buku & Alat Tulis', 'icon': '📚'},
          {'id': 'sub_course', 'name': 'Kursus / Pelatihan', 'icon': '💻'},
          {'id': 'sub_seminar', 'name': 'Seminar / Workshop', 'icon': '🎤'},
        ],
      },
      {
        'id': 'cat_health',
        'name': 'Kesehatan',
        'icon': '🏥',
        'color': '#DDA0DD',
        'type': 'expense',
        'subs': [
          {'id': 'sub_medicine', 'name': 'Obat-obatan', 'icon': '💊'},
          {'id': 'sub_doctor', 'name': 'Dokter', 'icon': '👨‍⚕️'},
          {'id': 'sub_hospital', 'name': 'Rumah Sakit', 'icon': '🏥'},
          {'id': 'sub_vitamin', 'name': 'Vitamin & Suplemen', 'icon': '🧴'},
          {'id': 'sub_health_ins', 'name': 'Asuransi Kesehatan', 'icon': '🛡️'},
        ],
      },
      {
        'id': 'cat_personal',
        'name': 'Belanja Pribadi',
        'icon': '🛍️',
        'color': '#F8B500',
        'type': 'expense',
        'subs': [
          {'id': 'sub_clothes', 'name': 'Pakaian', 'icon': '👕'},
          {'id': 'sub_shoes', 'name': 'Sepatu', 'icon': '👟'},
          {'id': 'sub_accessories', 'name': 'Aksesoris', 'icon': '💍'},
          {'id': 'sub_skincare', 'name': 'Skincare & Makeup', 'icon': '💄'},
          {'id': 'sub_gadget', 'name': 'Gadget', 'icon': '📱'},
          {'id': 'sub_hobby', 'name': 'Hobi', 'icon': '🎨'},
        ],
      },
      {
        'id': 'cat_entertainment',
        'name': 'Hiburan',
        'icon': '🎮',
        'color': '#A29BFE',
        'type': 'expense',
        'subs': [
          {'id': 'sub_movie', 'name': 'Nonton', 'icon': '🎬'},
          {'id': 'sub_game', 'name': 'Game', 'icon': '🎮'},
          {
            'id': 'sub_streaming',
            'name': 'Streaming (Netflix, dll)',
            'icon': '📺',
          },
          {'id': 'sub_vacation', 'name': 'Liburan', 'icon': '✈️'},
          {'id': 'sub_event', 'name': 'Event / Konser', 'icon': '🎵'},
        ],
      },
      {
        'id': 'cat_social',
        'name': 'Sosial & Donasi',
        'icon': '🤝',
        'color': '#55EFC4',
        'type': 'expense',
        'subs': [
          {'id': 'sub_charity', 'name': 'Sedekah', 'icon': '🤲'},
          {'id': 'sub_donation', 'name': 'Donasi', 'icon': '❤️'},
          {'id': 'sub_gift', 'name': 'Hadiah', 'icon': '🎁'},
          {
            'id': 'sub_family_event',
            'name': 'Acara Keluarga',
            'icon': '👨‍👩‍👧‍👦',
          },
          {'id': 'sub_dues', 'name': 'Iuran', 'icon': '📋'},
        ],
      },
      {
        'id': 'cat_business',
        'name': 'Pekerjaan & Bisnis',
        'icon': '💼',
        'color': '#636E72',
        'type': 'both',
        'subs': [
          {'id': 'sub_capital', 'name': 'Modal Usaha', 'icon': '💰'},
          {'id': 'sub_operational', 'name': 'Operasional', 'icon': '⚙️'},
          {'id': 'sub_salary_out', 'name': 'Gaji Karyawan', 'icon': '👥'},
          {'id': 'sub_software', 'name': 'Tools / Software', 'icon': '🖥️'},
          {'id': 'sub_marketing', 'name': 'Marketing / Iklan', 'icon': '📣'},
        ],
      },
      {
        'id': 'cat_family',
        'name': 'Keluarga & Anak',
        'icon': '👶',
        'color': '#FDCB6E',
        'type': 'expense',
        'subs': [
          {'id': 'sub_child_needs', 'name': 'Kebutuhan Anak', 'icon': '🧸'},
          {'id': 'sub_allowance', 'name': 'Uang Saku', 'icon': '💵'},
          {'id': 'sub_child_edu', 'name': 'Pendidikan Anak', 'icon': '📓'},
          {'id': 'sub_baby_care', 'name': 'Perawatan Bayi', 'icon': '🍼'},
        ],
      },
      {
        'id': 'cat_savings',
        'name': 'Tabungan & Investasi',
        'icon': '💰',
        'color': '#00B894',
        'type': 'both',
        'subs': [
          {'id': 'sub_saving', 'name': 'Tabungan', 'icon': '🏦'},
          {'id': 'sub_emergency', 'name': 'Dana Darurat', 'icon': '🆘'},
          {'id': 'sub_stock', 'name': 'Investasi Saham', 'icon': '📈'},
          {'id': 'sub_crypto', 'name': 'Investasi Crypto', 'icon': '₿'},
          {'id': 'sub_gold', 'name': 'Emas', 'icon': '🥇'},
          {'id': 'sub_mutual_fund', 'name': 'Reksa Dana', 'icon': '📊'},
        ],
      },
      {
        'id': 'cat_subscription',
        'name': 'Langganan',
        'icon': '🔄',
        'color': '#8B5CF6',
        'type': 'expense',
        'subs': <Map<String, String>>[],
      },
      {
        'id': 'cat_other',
        'name': 'Lainnya',
        'icon': '📦',
        'color': '#B2BEC3',
        'type': 'both',
        'subs': [
          {'id': 'sub_urgent', 'name': 'Keperluan Mendesak', 'icon': '⚠️'},
          {'id': 'sub_unexpected', 'name': 'Biaya Tak Terduga', 'icon': '❓'},
          {'id': 'sub_misc', 'name': 'Lain-lain', 'icon': '📌'},
        ],
      },
      {
        'id': 'cat_income',
        'name': 'Pendapatan',
        'icon': '💵',
        'color': '#00B894',
        'type': 'income',
        'subs': [
          {'id': 'sub_salary_in', 'name': 'Gaji', 'icon': '💼'},
          {'id': 'sub_freelance', 'name': 'Freelance', 'icon': '💻'},
          {'id': 'sub_business_in', 'name': 'Hasil Usaha', 'icon': '🏪'},
          {'id': 'sub_bonus', 'name': 'Bonus', 'icon': '🎉'},
          {'id': 'sub_invest_in', 'name': 'Hasil Investasi', 'icon': '📈'},
          {'id': 'sub_other_in', 'name': 'Lainnya', 'icon': '💰'},
        ],
      },
    ];

    for (final cat in data) {
      final parentId = cat['id'] as String;
      result.add(
        CategoryModel(
          id: parentId,
          name: cat['name'] as String,
          icon: cat['icon'] as String,
          color: cat['color'] as String,
          parentId: null,
          type: cat['type'] as String,
          isDefault: true,
        ),
      );

      final subs = cat['subs'] as List<Map<String, String>>;
      for (final sub in subs) {
        result.add(
          CategoryModel(
            id: sub['id']!,
            name: sub['name']!,
            icon: sub['icon']!,
            color: cat['color'] as String,
            parentId: parentId,
            type: cat['type'] as String,
            isDefault: true,
          ),
        );
      }
    }

    return result;
  }

  // Dipanggil setiap init untuk memastikan kategori subscription ada
  // (untuk user yang sudah punya data sebelum kategori ini ditambahkan)
  static Future<void> ensureSubscriptionCategory() async {
    final box = HiveService.categories;
    if (box.containsKey('cat_subscription')) return;
    await box.put(
      'cat_subscription',
      CategoryModel(
        id: 'cat_subscription',
        name: 'Langganan',
        icon: '🔄',
        color: '#8B5CF6',
        parentId: null,
        type: 'expense',
        isDefault: true,
      ),
    );
  }
}
