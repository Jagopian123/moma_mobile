import 'dart:convert';
import '../constants/app_constants.dart';
import '../hive/hive_service.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final _api = ApiService();

  // ── Upload ke server ──────────────────────────────────────────
  // Throws jika gagal — caller wajib handle error
  Future<void> upload() async {
    final map = ExportService.buildBackupMap();
    final jsonStr = jsonEncode(map);

    final response = await _api.post('/backup', data: {
      'data': jsonStr,
      'backed_up_at': DateTime.now().toIso8601String(),
    }).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'Backup gagal');
    }

    // Simpan timestamp backup terakhir
    await HiveService.user.put(
      AppConstants.keyLastBackup,
      DateTime.now().toIso8601String(),
    );
  }

  // ── Download & restore dari server ───────────────────────────
  // Return true jika ada backup dan berhasil di-restore
  // Return false jika tidak ada backup (404) — bukan error
  // Throws jika ada koneksi error
  Future<bool> downloadAndRestore() async {
    final response = await _api
        .get('/backup')
        .timeout(const Duration(seconds: 15));

    // 404 = belum pernah backup, bukan error
    if (response.statusCode == 404) return false;

    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'Gagal mengambil backup');
    }

    final jsonStr = response.data['data']['data'] as String;
    final backedUpAt = response.data['data']['backed_up_at'] as String?;

    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final result = await ImportService().restoreFromMap(map);

    if (!result.success) {
      throw Exception(result.message);
    }

    // Simpan timestamp backup terakhir yang diketahui
    if (backedUpAt != null) {
      await HiveService.user.put(AppConstants.keyLastBackup, backedUpAt);
    }

    return true;
  }

  // ── Baca timestamp backup terakhir dari Hive ─────────────────
  DateTime? get lastBackupTime {
    final ts = HiveService.user.get(AppConstants.keyLastBackup) as String?;
    return ts != null ? DateTime.tryParse(ts) : null;
  }
}
