/// Keyword-based subcategory matcher.
/// AI returns main category name → this util finds the best subcategory
/// from the transaction title without adding subcategories to the AI prompt.
class CategoryMatcher {
  static const Map<String, List<String>> _keywords = {
    // ── Makanan & Minuman ──────────────────────────────────────────────────────
    'sub_coffee': [
      'kopi',
      'ngopi',
      'coffee',
      'café',
      'cafe',
      'americano',
      'latte',
      'cappuccino',
      'espresso',
      'boba',
      'matcha',
      'kopitiam'
    ],
    'sub_delivery': [
      'gofood',
      'grabfood',
      'shopeefood',
      'pesan antar',
      'delivery',
      'antar makanan'
    ],
    'sub_restaurant': [
      'restoran',
      'restaurant',
      'rumah makan',
      'rm ',
      'makan malam',
      'dinner',
      'lunch',
      'brunch',
      'makan siang'
    ],
    'sub_groceries': [
      'sayur',
      'beras',
      'telur',
      'bumbu',
      'bahan masak',
      'pasar',
      'supermarket',
      'indomaret',
      'alfamart',
      'belanja bahan'
    ],
    'sub_drink': [
      'minum',
      'es ',
      'jus',
      'susu',
      'teh',
      'air mineral',
      'aqua',
      'minuman'
    ],
    'sub_snack': [
      'jajan',
      'snack',
      'cemilan',
      'keripik',
      'gorengan',
      'bolu',
      'kue',
      'roti',
      'biskuit'
    ],
    'sub_daily_food': [
      'makan',
      'nasi',
      'lauk',
      'warteg',
      'warung',
      'mie',
      'bakso',
      'soto',
      'pecel',
      'bubur',
      'sate',
      'ayam',
      'geprek',
      'penyetan'
    ],

    // ── Kebutuhan Rumah Tangga ─────────────────────────────────────────────────
    'sub_electricity': ['listrik', 'pln', 'token listrik', 'kwh'],
    'sub_internet': [
      'internet',
      'kuota',
      'modem',
      'wifi',
      'wi-fi',
      'indihome',
      'first media',
      'biznet',
      'myrepublic',
      'speedy'
    ],
    'sub_water': ['pdam', 'tagihan air', 'bayar air'],
    'sub_gas': ['gas', 'lpg', 'elpiji', 'tabung gas'],
    'sub_soap': [
      'sabun',
      'sampo',
      'shampoo',
      'detergen',
      'pembersih',
      'pewangi'
    ],
    'sub_furniture': [
      'kursi',
      'meja',
      'lemari',
      'kasur',
      'sofa',
      'furniture',
      'perabot',
      'rak'
    ],
    'sub_tools': [
      'peralatan',
      'alat rumah',
      'bor',
      'paku',
      'cat rumah',
      'kunci',
      'perkakas'
    ],
    'sub_monthly_shop': [
      'belanja bulanan',
      'giant',
      'hypermart',
      'carrefour',
      'transmart'
    ],

    // ── Transportasi ──────────────────────────────────────────────────────────
    'sub_fuel': [
      'bensin',
      'bbm',
      'pertamax',
      'pertalite',
      'solar',
      'spbu',
      'shell',
      'isi bensin'
    ],
    'sub_toll': ['tol', 'jalan tol', 'e-toll', 'bayar tol'],
    'sub_ojol': [
      'gojek',
      'grab',
      'ojek',
      'ojol',
      'taksi',
      'maxim',
      'gocar',
      'grabcar',
      'goride'
    ],
    'sub_public': [
      'busway',
      'transjakarta',
      'mrt',
      'lrt',
      'krl',
      'kereta',
      'angkot',
      'angkutan umum',
      'commuterline'
    ],
    'sub_service': [
      'servis',
      'service motor',
      'service mobil',
      'service kendaraan',
      'bengkel',
      'ganti oli',
      'tune up',
      'sparepart',
      'spare part',
      'ban ',
      'aki '
    ],
    'sub_tax_vehicle': [
      'stnk',
      'pajak motor',
      'pajak mobil',
      'pajak kendaraan',
      'perpanjang stnk'
    ],
    'sub_parking': ['parkir', 'parking'],

    // ── Keuangan & Tagihan ────────────────────────────────────────────────────
    'sub_health_ins': ['bpjs', 'asuransi kesehatan', 'asuransi sakit'],
    'sub_insurance': [
      'asuransi',
      'premi',
      'prudential',
      'allianz',
      'jasindo',
      'sinarmas'
    ],
    'sub_credit_card': ['kartu kredit', 'credit card', 'tagihan kartu', 'cc '],
    'sub_installment': ['cicilan', 'kredit', 'angsuran', 'kpr', 'kta'],
    'sub_tax': ['pajak', 'ppn', 'pph', 'spt'],
    'sub_bank_admin': ['admin bank', 'biaya admin', 'administrasi bank'],
    'sub_transfer_fee': ['biaya transfer', 'fee transfer'],

    // ── Pendidikan ────────────────────────────────────────────────────────────
    'sub_tuition': [
      'spp',
      'ukt',
      'uang kuliah',
      'uang sekolah',
      'biaya kuliah',
      'daftar ulang'
    ],
    'sub_course': [
      'kursus',
      'kelas',
      'les ',
      'pelatihan',
      'training',
      'bootcamp',
      'udemy',
      'coursera',
      'belajar online'
    ],
    'sub_seminar': ['seminar', 'workshop', 'webinar', 'conference'],
    'sub_books': [
      'buku',
      'alat tulis',
      'pulpen',
      'pensil',
      'fotokopi',
      'print',
      'atk'
    ],

    // ── Kesehatan ─────────────────────────────────────────────────────────────
    'sub_hospital': [
      'rumah sakit',
      'rs ',
      'rs.',
      'rawat inap',
      'igd',
      'opname'
    ],
    'sub_doctor': [
      'dokter',
      'dr.',
      'konsultasi',
      'periksa',
      'klinik',
      'puskesmas',
      'checkup'
    ],
    'sub_vitamin': [
      'vitamin',
      'suplemen',
      'multivitamin',
      'omega',
      'probiotik',
      'collagen'
    ],
    'sub_medicine': [
      'obat',
      'apotek',
      'apotik',
      'farmasi',
      'kimia farma',
      'century'
    ],

    // ── Belanja Pribadi ───────────────────────────────────────────────────────
    'sub_skincare': [
      'skincare',
      'makeup',
      'kosmetik',
      'serum',
      'pelembab',
      'sunscreen',
      'foundation',
      'lipstik',
      'moisturizer',
      'toner'
    ],
    'sub_gadget': [
      'hp ',
      'handphone',
      'laptop',
      'tablet',
      'earphone',
      'headphone',
      'charger',
      'powerbank',
      'mouse',
      'keyboard',
      'gadget'
    ],
    'sub_shoes': ['sepatu', 'sandal', 'sendal', 'boot ', 'sneakers'],
    'sub_accessories': [
      'jam tangan',
      'gelang',
      'kalung',
      'cincin',
      'kacamata',
      'dompet',
      'ikat pinggang'
    ],
    'sub_clothes': [
      'baju',
      'pakaian',
      'kemeja',
      'kaos',
      'celana',
      'dress',
      'jaket',
      'sweater',
      'hoodie'
    ],
    'sub_hobby': [
      'gym',
      'fitness',
      'futsal',
      'badminton',
      'renang',
      'lari',
      'olahraga',
      'hobi',
      'koleksi'
    ],

    // ── Hiburan ───────────────────────────────────────────────────────────────
    'sub_game': [
      'topup',
      'top up',
      'diamond',
      'uc ',
      'voucher game',
      'mobile legend',
      'free fire',
      'pubg',
      'steam',
      'gaming'
    ],
    'sub_streaming': [
      'netflix',
      'spotify',
      'disney',
      'hbo',
      'youtube premium',
      'prime video',
      'viu',
      'streaming'
    ],
    'sub_vacation': [
      'hotel',
      'penginapan',
      'tiket pesawat',
      'pesawat',
      'liburan',
      'wisata',
      'tour',
      'airbnb',
      'villa'
    ],
    'sub_event': [
      'konser',
      'festival',
      'tiket konser',
      'pertunjukan',
      'pameran',
      'event'
    ],
    'sub_movie': [
      'nonton',
      'bioskop',
      'cinema',
      'xxi',
      'cgv',
      'film',
      'movie',
      'imax'
    ],

    // ── Sosial & Donasi ───────────────────────────────────────────────────────
    'sub_charity': [
      'sedekah',
      'infaq',
      'zakat',
      'masjid',
      'mushola',
      'shodaqoh'
    ],
    'sub_donation': [
      'donasi',
      'sumbangan',
      'bantuan',
      'galang dana',
      'kitabisa'
    ],
    'sub_family_event': [
      'nikahan',
      'pernikahan',
      'kondangan',
      'lamaran',
      'sunatan',
      'selamatan',
      'lebaran',
      'arisan keluarga'
    ],
    'sub_gift': [
      'hadiah',
      'kado',
      'hamper',
      'parcel',
      'ulang tahun',
      'anniversary',
      'gift'
    ],
    'sub_dues': ['iuran', 'kas rt', 'kas rw', 'arisan'],

    // ── Pekerjaan & Bisnis ────────────────────────────────────────────────────
    'sub_marketing': [
      'iklan',
      'ads',
      'google ads',
      'facebook ads',
      'meta ads',
      'promosi bisnis'
    ],
    'sub_software': [
      'figma',
      'notion',
      'adobe',
      'canva',
      'saas',
      'langganan software',
      'software'
    ],
    'sub_salary_out': [
      'gaji karyawan',
      'upah karyawan',
      'thr karyawan',
      'bayar gaji'
    ],
    'sub_operational': [
      'operasional',
      'sewa kantor',
      'rental kantor',
      'biaya kantor'
    ],
    'sub_capital': ['modal', 'modal usaha', 'buka usaha', 'investasi bisnis'],

    // ── Keluarga & Anak ───────────────────────────────────────────────────────
    'sub_child_edu': ['les anak', 'sekolah anak', 'spp anak', 'kursus anak'],
    'sub_baby_care': ['bayi', 'perawatan bayi', 'imunisasi', 'posyandu'],
    'sub_child_needs': ['pampers', 'popok', 'susu bayi', 'perlengkapan bayi'],
    'sub_allowance': ['uang saku', 'jajan anak', 'uang jajan'],

    // ── Tabungan & Investasi ──────────────────────────────────────────────────
    'sub_crypto': [
      'crypto',
      'bitcoin',
      'btc',
      'ethereum',
      'eth ',
      'binance',
      'kripto'
    ],
    'sub_gold': ['emas', 'antam', 'logam mulia', 'tabungan emas'],
    'sub_mutual_fund': ['reksa dana', 'reksadana', 'bareksa', 'bibit'],
    'sub_stock': ['saham', 'beli saham', 'jual saham', 'idx', 'bursa'],
    'sub_emergency': ['dana darurat', 'emergency fund', 'tabungan darurat'],
    'sub_saving': ['tabungan', 'nabung', 'simpanan', 'deposito'],

    // ── Pendapatan ────────────────────────────────────────────────────────────
    'sub_invest_in': [
      'dividen',
      'return investasi',
      'profit',
      'hasil investasi',
      'bunga deposito'
    ],
    'sub_bonus': ['bonus', 'reward', 'insentif', 'komisi', 'tips'],
    'sub_business_in': [
      'omzet',
      'penjualan',
      'hasil usaha',
      'hasil jualan',
      'laba'
    ],
    'sub_freelance': ['freelance', 'project', 'proyek', 'honor', 'fee project'],
    'sub_salary_in': ['gaji', 'salary', 'upah', 'thr', 'slip gaji'],
  };

  // Subcategory → parent category ID
  static const Map<String, String> _parents = {
    'sub_daily_food': 'cat_food',
    'sub_snack': 'cat_food',
    'sub_drink': 'cat_food',
    'sub_coffee': 'cat_food',
    'sub_restaurant': 'cat_food',
    'sub_delivery': 'cat_food',
    'sub_groceries': 'cat_food',
    'sub_monthly_shop': 'cat_household',
    'sub_soap': 'cat_household',
    'sub_tools': 'cat_household',
    'sub_furniture': 'cat_household',
    'sub_electricity': 'cat_household',
    'sub_water': 'cat_household',
    'sub_gas': 'cat_household',
    'sub_internet': 'cat_household',
    'sub_fuel': 'cat_transport',
    'sub_parking': 'cat_transport',
    'sub_toll': 'cat_transport',
    'sub_ojol': 'cat_transport',
    'sub_public': 'cat_transport',
    'sub_service': 'cat_transport',
    'sub_tax_vehicle': 'cat_transport',
    'sub_installment': 'cat_finance',
    'sub_credit_card': 'cat_finance',
    'sub_insurance': 'cat_finance',
    'sub_tax': 'cat_finance',
    'sub_bank_admin': 'cat_finance',
    'sub_transfer_fee': 'cat_finance',
    'sub_health_ins': 'cat_finance',
    'sub_tuition': 'cat_education',
    'sub_books': 'cat_education',
    'sub_course': 'cat_education',
    'sub_seminar': 'cat_education',
    'sub_medicine': 'cat_health',
    'sub_doctor': 'cat_health',
    'sub_hospital': 'cat_health',
    'sub_vitamin': 'cat_health',
    'sub_clothes': 'cat_personal',
    'sub_shoes': 'cat_personal',
    'sub_accessories': 'cat_personal',
    'sub_skincare': 'cat_personal',
    'sub_gadget': 'cat_personal',
    'sub_hobby': 'cat_personal',
    'sub_movie': 'cat_entertainment',
    'sub_game': 'cat_entertainment',
    'sub_streaming': 'cat_entertainment',
    'sub_vacation': 'cat_entertainment',
    'sub_event': 'cat_entertainment',
    'sub_charity': 'cat_social',
    'sub_donation': 'cat_social',
    'sub_gift': 'cat_social',
    'sub_family_event': 'cat_social',
    'sub_dues': 'cat_social',
    'sub_capital': 'cat_business',
    'sub_operational': 'cat_business',
    'sub_salary_out': 'cat_business',
    'sub_software': 'cat_business',
    'sub_marketing': 'cat_business',
    'sub_child_needs': 'cat_family',
    'sub_allowance': 'cat_family',
    'sub_child_edu': 'cat_family',
    'sub_baby_care': 'cat_family',
    'sub_saving': 'cat_savings',
    'sub_emergency': 'cat_savings',
    'sub_stock': 'cat_savings',
    'sub_crypto': 'cat_savings',
    'sub_gold': 'cat_savings',
    'sub_mutual_fund': 'cat_savings',
    'sub_salary_in': 'cat_income',
    'sub_freelance': 'cat_income',
    'sub_business_in': 'cat_income',
    'sub_bonus': 'cat_income',
    'sub_invest_in': 'cat_income',
  };

  /// Returns the best matching subcategory ID for [title] within [parentCategoryId],
  /// or null if no keyword matches. Longer keywords win (more specific match).
  static String? findSubcategoryId(String title, String parentCategoryId) {
    final t = title.toLowerCase();
    String? bestId;
    int bestScore = 0;

    for (final entry in _keywords.entries) {
      final subId = entry.key;
      if (_parents[subId] != parentCategoryId) continue;

      for (final kw in entry.value) {
        if (t.contains(kw.toLowerCase()) && kw.length > bestScore) {
          bestScore = kw.length;
          bestId = subId;
        }
      }
    }

    return bestId;
  }

  /// Searches ALL subcategories regardless of parent.
  /// Returns (subcategoryId, parentCategoryId) of the best match, or null.
  /// Used as fallback when AI's main category yields no subcategory match.
  static (String, String)? findSubcategoryIdGlobal(String title) {
    final t = title.toLowerCase();
    String? bestSubId;
    String? bestParentId;
    int bestScore = 0;

    for (final entry in _keywords.entries) {
      final subId = entry.key;
      final parentId = _parents[subId];
      if (parentId == null) continue;

      for (final kw in entry.value) {
        if (t.contains(kw.toLowerCase()) && kw.length > bestScore) {
          bestScore = kw.length;
          bestSubId = subId;
          bestParentId = parentId;
        }
      }
    }

    if (bestSubId == null || bestParentId == null) return null;
    return (bestSubId, bestParentId);
  }
}
