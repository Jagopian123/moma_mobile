import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/services/api_service.dart';
import '../../../core/utils/image_compress_util.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/hive/models/category_model.dart';
import '../models/ai_transaction_result.dart';
import '../providers/transaction_provider.dart';

// ── Chat Message Model ────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final List<AiTransactionResult>? transactionResults;
  final bool isError;
  final DateTime timestamp;
  /// Local path to a receipt image thumbnail (user-side scan message only).
  final String? imagePath;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.transactionResults,
    this.isError = false,
    required this.timestamp,
    this.imagePath,
  });

  ChatMessage copyWith({
    String? text,
    List<AiTransactionResult>? transactionResults,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      transactionResults: transactionResults ?? this.transactionResults,
      isError: isError,
      timestamp: timestamp,
      imagePath: imagePath,
    );
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  AiChatState copyWith({List<ChatMessage>? messages, bool? isLoading}) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super(const AiChatState());

  // ── Text / Voice ────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      final response = await ApiService().dio.post(
        '/ai/parse-transaction',
        data: {'message': text},
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );

      _handleResults(response.data['data']);
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      debugPrint('[AiChat] Exception: $e');
      _addError('Terjadi kesalahan: $e');
    }
  }

  // ── Receipt scan ────────────────────────────────────────────────────────────

  Future<void> scanReceipt(File imageFile) async {
    // User message shows a thumbnail of the selected image
    final userMsg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      text: 'Scan struk',
      isUser: true,
      imagePath: imageFile.path,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    File? compressed;
    try {
      // Compress + resize before uploading
      compressed = await ImageCompressUtil.compressAndResize(imageFile);

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          compressed.path,
          filename: 'receipt.jpg',
        ),
      });

      final response = await ApiService().dio.post(
        '/ai/scan-receipt',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout:    const Duration(seconds: 30),
        ),
      );

      _handleResults(
        response.data['data'],
        labelOverride: (count) => count == 1
            ? 'Saya membaca 1 transaksi dari struk. Cek detail:'
            : 'Saya membaca $count transaksi dari struk. Cek detail:',
      );
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      debugPrint('[AiChat] scanReceipt Exception: $e');
      _addError('Gagal memproses struk: $e');
    } finally {
      // Clean up the compressed temp file
      if (compressed != null && compressed.existsSync()) {
        compressed.deleteSync();
      }
    }
  }

  // ── Confirm / Save ──────────────────────────────────────────────────────────

  Future<bool> confirmTransaction({
    required AiTransactionResult result,
    required String messageId,
    required WalletModel? wallet,
    required WalletModel? toWallet,
    required CategoryModel? category,
  }) async {
    try {
      final txNotifier = _ref.read(transactionProvider.notifier);
      final now = DateTime.now();

      if (result.type == 'income') {
        await txNotifier.addIncome(
          title: result.title,
          amount: result.amount,
          categoryId: category?.id ?? 'other',
          categoryName: category?.name ?? result.categoryName,
          categoryIcon: category?.icon ?? result.categoryIcon,
          walletId: wallet?.id ?? '',
          walletName: wallet?.name ?? result.walletHint ?? 'Dompet',
          date: now,
          description: result.description,
        );
      } else if (result.type == 'transfer') {
        await txNotifier.addTransfer(
          title: result.title,
          amount: result.amount,
          fromWalletId: wallet?.id ?? '',
          fromWalletName: wallet?.name ?? '',
          toWalletId: toWallet?.id ?? '',
          toWalletName: toWallet?.name ?? '',
          adminFee: 0,
          date: now,
          description: result.description,
        );
      } else {
        await txNotifier.addExpense(
          title: result.title,
          amount: result.amount,
          categoryId: category?.id ?? 'other',
          categoryName: category?.name ?? result.categoryName,
          categoryIcon: category?.icon ?? result.categoryIcon,
          walletId: wallet?.id ?? '',
          walletName: wallet?.name ?? result.walletHint ?? 'Dompet',
          date: now,
          description: result.description,
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  WalletModel? matchWallet(String? hint, List<WalletModel> wallets) {
    if (wallets.isEmpty) return null;
    if (hint == null || hint.isEmpty) return wallets.first;

    final h = hint.toLowerCase().trim();

    for (final w in wallets) {
      if (w.name.toLowerCase() == h) return w;
    }
    for (final w in wallets) {
      if (w.name.toLowerCase().contains(h) || h.contains(w.name.toLowerCase())) {
        return w;
      }
    }
    if (h == 'cash' || h == 'tunai' || h == 'uang tunai') {
      for (final w in wallets) {
        if (w.type == 'cash') return w;
      }
    }
    return wallets.first;
  }

  CategoryModel? matchCategory(
    String? name,
    String type,
    List<CategoryModel> categories,
  ) {
    if (name == null) return null;

    final n = name.toLowerCase().trim();
    final filtered = categories
        .where((c) => c.parentId == null && (c.type == type || c.type == 'both'))
        .toList();

    if (filtered.isEmpty) return null;

    for (final c in filtered) {
      if (c.name.toLowerCase() == n) return c;
    }
    for (final c in filtered) {
      if (c.name.toLowerCase().contains(n) || n.contains(c.name.toLowerCase())) {
        return c;
      }
    }
    return filtered.first;
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  void _handleResults(
    dynamic rawData, {
    String Function(int count)? labelOverride,
  }) {
    final List<AiTransactionResult> results;
    if (rawData is List) {
      results = AiTransactionResult.fromJsonList(rawData);
    } else {
      results = [AiTransactionResult.fromJson(rawData as Map<String, dynamic>)];
    }

    final text = labelOverride != null
        ? labelOverride(results.length)
        : (results.length == 1
            ? _typeLabel(results.first.type)
            : 'Saya mendeteksi ${results.length} transaksi. Cek detail di bawah:');

    final aiMsg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      text: text,
      isUser: false,
      transactionResults: results,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      isLoading: false,
    );
  }

  void _handleDioError(DioException e) {
    debugPrint('[AiChat] DioException: ${e.type} | status=${e.response?.statusCode}');
    final String msg;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        msg = 'Koneksi timeout. Pastikan backend berjalan dan coba lagi.';
      case DioExceptionType.connectionError:
        msg = 'Tidak dapat terhubung ke server. Pastikan backend berjalan.';
      default:
        final serverMsg = e.response?.data is Map
            ? e.response?.data['message'] as String?
            : null;
        msg = serverMsg ?? 'Server error (${e.response?.statusCode ?? 'unknown'}).';
    }
    _addError(msg);
  }

  void _addError(String text) {
    final msg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_err',
      text: text,
      isUser: false,
      isError: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, msg],
      isLoading: false,
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'income'   => 'Saya mendeteksi Pemasukan. Cek detail di bawah:',
      'transfer' => 'Saya mendeteksi Transfer. Cek detail di bawah:',
      _          => 'Saya mendeteksi Pengeluaran. Cek detail di bawah:',
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
