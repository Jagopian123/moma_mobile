import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../hive/hive_service.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

// ── Top-level functions untuk compute() ──────────────────────────────────────

/// Encode Map → JSON → gzip → base64 (berjalan di background isolate)
String _encodeAndCompress(Map<String, dynamic> data) {
  final jsonStr = jsonEncode(data);
  final bytes   = utf8.encode(jsonStr);
  final gzipped = GZipCodec().encode(bytes);
  return base64Encode(gzipped);
}

/// Decode base64 → gunzip → JSON → Map (berjalan di background isolate)
Map<String, dynamic> _decompressAndDecode(String base64Str) {
  final gzipped = base64Decode(base64Str);
  final bytes   = GZipCodec().decode(gzipped);
  final jsonStr = utf8.decode(bytes);
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}

// ── Helper: terjemahkan error teknis jadi pesan yang mudah dimengerti ────────

String _friendlyError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return 'Tidak ada koneksi internet. Periksa jaringan kamu lalu coba lagi.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi terlalu lambat atau terputus. Coba lagi nanti.';
      default:
        final code = e.response?.statusCode;
        if (code == 401) return 'Sesi kamu habis. Silakan login ulang.';
        if (code == 413) return 'Data terlalu besar untuk dikirim. Hubungi tim Moma.';
        if (code == 429) return 'Backup gratis hanya tersedia sekali seminggu. Coba lagi minggu depan.';
        if (code != null && code >= 500) {
          return 'Server Moma sedang bermasalah. Coba beberapa menit lagi.';
        }
        return 'Terjadi kesalahan jaringan. Coba lagi nanti.';
    }
  }
  if (e is SocketException) {
    return 'Tidak ada koneksi internet. Periksa jaringan kamu lalu coba lagi.';
  }
  if (e is TimeoutException) {
    return 'Koneksi terlalu lambat atau terputus. Coba lagi nanti.';
  }
  // Buang prefix "Exception: " yang tidak perlu ditampilkan ke user
  final msg = e.toString().replaceFirst('Exception: ', '');
  return msg.isNotEmpty ? msg : 'Terjadi kesalahan. Coba lagi nanti.';
}

// ─────────────────────────────────────────────────────────────────────────────

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final _api = ApiService();

  // ── Upload ke server ──────────────────────────────────────────
  Future<void> upload() async {
    try {
      // 1. Ambil data dari Hive (wajib di main thread)
      final map = ExportService.buildBackupMap();

      // 2. Encode + kompres di background agar UI tidak freeze
      final compressed = await compute(_encodeAndCompress, map);

      // 3. Upload
      final response = await _api.post('/backup', data: {
        'data'        : compressed,
        'compressed'  : true,
        'backed_up_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(
          response.data['message'] ?? 'Server tidak merespons dengan benar.',
        );
      }

      await HiveService.user.put(
        AppConstants.keyLastBackup,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Lempar ulang dengan pesan yang mudah dimengerti
      throw Exception(_friendlyError(e));
    }
  }

  // ── Download & restore dari server ───────────────────────────
  Future<bool> downloadAndRestore() async {
    try {
      final response = await _api
          .get('/backup')
          .timeout(const Duration(seconds: 30));

      // 404 = belum pernah backup, bukan error
      if (response.statusCode == 404) return false;

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(
          response.data['message'] ?? 'Server tidak merespons dengan benar.',
        );
      }

      final payload      = response.data['data'] as Map<String, dynamic>;
      final rawData      = payload['data'] as String;
      final isCompressed = payload['is_compressed'] as bool? ?? false;
      final backedUpAt   = payload['backed_up_at'] as String?;

      // Decode di background isolate jika terkompresi
      final Map<String, dynamic> map;
      if (isCompressed) {
        map = await compute(_decompressAndDecode, rawData);
      } else {
        map = jsonDecode(rawData) as Map<String, dynamic>;
      }

      final result = await ImportService().restoreFromMap(map);
      if (!result.success) {
        throw Exception(result.message);
      }

      if (backedUpAt != null) {
        await HiveService.user.put(AppConstants.keyLastBackup, backedUpAt);
      }

      return true;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // ── Baca timestamp backup terakhir dari Hive ─────────────────
  DateTime? get lastBackupTime {
    final ts = HiveService.user.get(AppConstants.keyLastBackup) as String?;
    return ts != null ? DateTime.tryParse(ts) : null;
  }

  // ── Cek apakah sudah waktunya auto backup ────────────────────
  // Premium: tiap 22 jam (daily dengan sedikit slack)
  // Free: tiap 6.5 hari (weekly dengan sedikit slack)
  bool canAutoBackup(bool isPremium) {
    final last = lastBackupTime;
    if (last == null) return true;
    final threshold = isPremium
        ? const Duration(hours: 22)
        : const Duration(days: 6, hours: 12);
    return DateTime.now().difference(last) >= threshold;
  }
}
