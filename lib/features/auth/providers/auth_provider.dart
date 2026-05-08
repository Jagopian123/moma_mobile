import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/import_service.dart';
import '../models/user_model.dart';
import 'auth_state.dart';

final _googleSignIn = GoogleSignIn(
  serverClientId: AppConstants.googleWebClientId,
  scopes: ['email', 'profile'],
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unknown()) {
    _init();
  }

  final _api = ApiService();

  Future<void> _init() async {
    final token = HiveService.user.get(AppConstants.keyAuthToken);

    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final response =
          await _api.get('/auth/me').timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        _saveUserToHive(user);
        state = AuthState.authenticated(user);
      } else {
        _clearHive();
        state = const AuthState.unauthenticated();
      }
    } catch (_) {
      final localUser = _getUserFromHive();
      if (localUser != null) {
        state = AuthState.authenticated(localUser);
      } else {
        state = const AuthState.unauthenticated();
      }
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        state = const AuthState.error('Gagal mendapatkan token Google');
        return;
      }

      final response = await _api.post('/auth/google/callback', data: {
        'id_token': idToken,
        'device_name': 'flutter_app',
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final user = UserModel.fromJson(response.data['data']['user']);

        // Simpan token ke Hive — interceptor Dio akan otomatis pakai token ini
        await HiveService.user.put(AppConstants.keyAuthToken, token);
        _saveUserToHive(user);

        state = AuthState.authenticated(user);

        // Auto-restore: jika Hive kosong, coba ambil backup dari server
        _tryRestoreIfEmpty();
      } else {
        state = AuthState.error(
          response.data['message'] ?? 'Login gagal, coba lagi',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        state = const AuthState.error(
          'Tidak dapat terhubung ke server.\nPastikan HP dan laptop terhubung ke WiFi yang sama.',
        );
      } else {
        final message =
            e.response?.data?['message'] ?? 'Koneksi ke server gagal';
        state = AuthState.error(message);
      }
    } catch (e) {
      state = AuthState.error('Terjadi kesalahan: $e');
    }
  }

  // Backup dulu sebelum logout (Opsi A: throws jika backup gagal).
  // SettingsPage menangkap exception dan membatalkan logout.
  Future<void> signOut() async {
    await BackupService().upload(); // throws jika gagal — logout dibatalkan

    await _googleSignIn.signOut();
    try {
      await _api.post('/auth/logout').timeout(const Duration(seconds: 5));
    } catch (_) {}

    await HiveService.clearAllUserData();
    _clearHive();
    state = const AuthState.unauthenticated();
  }

  // Dipanggil setelah login berhasil — tidak blocking, error diabaikan
  Future<void> _tryRestoreIfEmpty() async {
    final isEmpty = HiveService.transactions.isEmpty && HiveService.wallets.isEmpty;
    if (!isEmpty) return;
    try {
      await BackupService().downloadAndRestore();
    } catch (_) {
      // Gagal restore tidak masalah — user mulai dengan data kosong
    }
  }

  void updateUser(UserModel user) {
    _saveUserToHive(user);
    state = AuthState.authenticated(user);
  }

  void _saveUserToHive(UserModel user) {
    HiveService.user.putAll({
      AppConstants.keyUserId: user.id,
      AppConstants.keyUserName: user.name,
      AppConstants.keyUserEmail: user.email,
      AppConstants.keyUserAvatar: user.avatar ?? '',
      AppConstants.keyIsPremium: user.isPremium,
    });
  }

  UserModel? _getUserFromHive() {
    final id = HiveService.user.get(AppConstants.keyUserId);
    if (id == null) return null;
    return UserModel(
      id: id,
      name: HiveService.user.get(AppConstants.keyUserName) ?? '',
      email: HiveService.user.get(AppConstants.keyUserEmail) ?? '',
      avatar: HiveService.user.get(AppConstants.keyUserAvatar),
      isPremium: HiveService.user.get(AppConstants.keyIsPremium) ?? false,
      currency: 'IDR',
      locale: 'id',
    );
  }

  void _clearHive() {
    HiveService.user.deleteAll([
      AppConstants.keyAuthToken,
      AppConstants.keyUserId,
      AppConstants.keyUserName,
      AppConstants.keyUserEmail,
      AppConstants.keyUserAvatar,
      AppConstants.keyIsPremium,
    ]);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
