import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/backup_service.dart';
import '../models/user_model.dart';
import 'auth_state.dart';
import '../../asset/providers/investment_provider.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../debt/providers/debt_provider.dart';
import '../../financial_plan/providers/financial_plan_provider.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../transaction/providers/transaction_provider.dart';
import '../../../features/settings/providers/backup_provider.dart';

final _googleSignIn = GoogleSignIn(
  serverClientId: AppConstants.googleWebClientId,
  scopes: ['email', 'profile'],
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState.unknown()) {
    _init();
  }

  final Ref _ref;
  final _api = ApiService();

  Future<void> _init() async {
    final token = HiveService.user.get(AppConstants.keyAuthToken);

    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    // Local-first: jika data user sudah ada di Hive, langsung authenticated
    // tanpa tunggu network. Server diverifikasi di background.
    final localUser = _getUserFromHive();
    if (localUser != null) {
      state = AuthState.authenticated(localUser);
      _verifyWithServer();
      return;
    }

    // Tidak ada data lokal (token orphan) — harus tunggu server
    try {
      final response =
          await _api.get('/auth/me').timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        _saveUserToHive(user);
        state = AuthState.authenticated(user);
      } else {
        await _clearHive();
        state = const AuthState.unauthenticated();
      }
    } catch (_) {
      await _clearHive();
      state = const AuthState.unauthenticated();
    }
  }

  // Verifikasi token ke server di background setelah local-first auth.
  // Jika token sudah tidak valid → paksa logout.
  // Jika data user berubah (misal premium) → update state.
  Future<void> _verifyWithServer() async {
    try {
      final response =
          await _api.get('/auth/me').timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        _saveUserToHive(user);
        if (mounted) state = AuthState.authenticated(user);
      } else {
        // Token ditolak server — paksa logout
        await _clearHive();
        if (mounted) state = const AuthState.unauthenticated();
      }
    } catch (_) {
      // Offline atau timeout — data lokal tetap valid, tidak perlu logout
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
        state = const AuthState.error('Login dengan Google gagal. Coba lagi.');
        return;
      }

      final response = await _api.post('/auth/google/callback', data: {
        'id_token': idToken,
        'device_name': 'flutter_app',
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['token'] as String;
        final user = UserModel.fromJson(response.data['data']['user']);

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
          'Tidak bisa terhubung ke internet. Periksa koneksi kamu lalu coba lagi.',
        );
      } else {
        final message = e.response?.data?['message'] ?? 'Terjadi kesalahan. Coba lagi.';
        state = AuthState.error(message);
      }
    } catch (_) {
      state = const AuthState.error('Terjadi kesalahan. Coba lagi.');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    try {
      await _api.post('/auth/logout').timeout(const Duration(seconds: 5));
    } catch (_) {}

    await HiveService.clearAllUserData();
    await _clearHive();
    _invalidateDataProviders();
    state = const AuthState.unauthenticated();
  }

  Future<void> deleteAccount() async {
    await _api.delete('/user');
    await _googleSignIn.signOut();
    await HiveService.clearAllUserData();
    await _clearHive();
    _invalidateDataProviders();
    state = const AuthState.unauthenticated();
  }

  // Dipanggil setelah login berhasil — tidak blocking, error diabaikan
  Future<void> _tryRestoreIfEmpty() async {
    final isEmpty =
        HiveService.transactions.isEmpty && HiveService.wallets.isEmpty;
    if (!isEmpty) return;
    try {
      final restored = await BackupService().downloadAndRestore();
      if (restored) _invalidateDataProviders();
    } catch (_) {
      // Gagal restore tidak masalah — user mulai dengan data kosong
    }

    if (HiveService.wallets.isEmpty) {
      await _seedDefaultWallet();
      _ref.invalidate(walletProvider);
    }
  }

  Future<void> _seedDefaultWallet() async {
    final now = DateTime.now();
    final wallet = WalletModel(
      id: const Uuid().v4(),
      name: 'Cash',
      type: 'cash',
      balance: 1000000,
      icon: '💵',
      color: '#3B82F6',
      createdAt: now,
      updatedAt: now,
    );
    await HiveService.wallets.put(wallet.id, wallet);
  }

  // Flush semua data provider agar mereka re-load dari Hive yang sudah bersih.
  // Wajib dipanggil setelah logout / ganti akun.
  void _invalidateDataProviders() {
    _ref.invalidate(transactionProvider);
    _ref.invalidate(walletProvider);
    _ref.invalidate(budgetProvider);
    _ref.invalidate(debtProvider);
    _ref.invalidate(financialPlanProvider);
    _ref.invalidate(investmentProvider);
    _ref.invalidate(subscriptionProvider);
    _ref.invalidate(backupProvider);
  }

  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Nama tidak boleh kosong');

    final response = await _api.put('/user', data: {'name': trimmed});

    if (response.statusCode == 200 && response.data['success'] == true) {
      final current = state.user!;
      updateUser(UserModel(
        id: current.id,
        name: trimmed,
        email: current.email,
        avatar: current.avatar,
        isPremium: current.isPremium,
        currency: current.currency,
        locale: current.locale,
      ));
    } else {
      throw Exception(
        response.data['message'] ?? 'Gagal memperbarui nama',
      );
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

  Future<void> _clearHive() async {
    // Hapus data user dan sesi — tapi JANGAN hapus preferensi perangkat
    // (keyIsOnboardingDone, keyIsBalanceVisible) karena bukan milik akun.
    await HiveService.user.deleteAll([
      AppConstants.keyAuthToken,
      AppConstants.keyUserId,
      AppConstants.keyUserName,
      AppConstants.keyUserEmail,
      AppConstants.keyUserAvatar,
      AppConstants.keyIsPremium,
      AppConstants.keyLastBackup,
      AppConstants.keySecurityEnabled,
      AppConstants.keyBiometricEnabled,
      AppConstants.keyPinHash,
      AppConstants.keyAiCreditsRemaining,
    ]);
    await _clearAiChatFile();
  }

  Future<void> _clearAiChatFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ai_chat_state.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
