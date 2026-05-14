import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/hive/hive_service.dart';
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
  final bool isCreditLimit;
  final DateTime timestamp;
  final String? imagePath;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.transactionResults,
    this.isError = false,
    this.isCreditLimit = false,
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
      isCreditLimit: isCreditLimit,
      timestamp: timestamp,
      imagePath: imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'isError': isError,
        'isCreditLimit': isCreditLimit,
        'timestamp': timestamp.toIso8601String(),
        'imagePath': imagePath,
        'transactionResults':
            transactionResults?.map((r) => r.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        text: j['text'] as String,
        isUser: j['isUser'] as bool,
        isError: j['isError'] as bool? ?? false,
        isCreditLimit: j['isCreditLimit'] as bool? ?? false,
        timestamp: DateTime.parse(j['timestamp'] as String),
        imagePath: j['imagePath'] as String?,
        transactionResults: (j['transactionResults'] as List<dynamic>?)
            ?.map((e) => AiTransactionResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── State ─────────────────────────────────────────────────────────────────────

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  /// -1 = unlimited (premium), 0..5 = free tier remaining
  final int creditsRemaining;
  final Map<String, double> savedAmounts;
  final Set<String> dismissedCards;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.creditsRemaining = AppConstants.aiFreeDailyLimit,
    this.savedAmounts = const {},
    this.dismissedCards = const {},
  });

  bool get isLimitReached => creditsRemaining == 0;
  bool get isPremium => creditsRemaining == -1;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    int? creditsRemaining,
    Map<String, double>? savedAmounts,
    Set<String>? dismissedCards,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      creditsRemaining: creditsRemaining ?? this.creditsRemaining,
      savedAmounts: savedAmounts ?? this.savedAmounts,
      dismissedCards: dismissedCards ?? this.dismissedCards,
    );
  }

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        'creditsRemaining': creditsRemaining,
        'savedAmounts': savedAmounts,
        'dismissedCards': dismissedCards.toList(),
      };

  factory AiChatState.fromJson(Map<String, dynamic> j) => AiChatState(
        messages: (j['messages'] as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        creditsRemaining:
            j['creditsRemaining'] as int? ?? AppConstants.aiFreeDailyLimit,
        savedAmounts: (j['savedAmounts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        dismissedCards:
            (j['dismissedCards'] as List<dynamic>? ?? []).cast<String>().toSet(),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super(const AiChatState()) {
    _load();
    _loadCachedCredits();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<File> _stateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ai_chat_state.json');
  }

  Future<void> _load() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (mounted) state = AiChatState.fromJson(json);
    } catch (e) {
      debugPrint('[AiChat] Failed to load persisted state: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = await _stateFile();
      const maxMessages = 30;
      final trimmed = state.messages.length > maxMessages
          ? state.copyWith(
              messages: state.messages
                  .sublist(state.messages.length - maxMessages),
            )
          : state;
      await file.writeAsString(jsonEncode(trimmed.toJson()));
    } catch (e) {
      debugPrint('[AiChat] Failed to save state: $e');
    }
  }

  // Credits are also cached in Hive so the counter shows immediately on open
  void _loadCachedCredits() {
    final cached = HiveService.user.get(AppConstants.keyAiCreditsRemaining);
    if (cached != null && mounted) {
      state = state.copyWith(creditsRemaining: cached as int);
    }
  }

  void _updateCredits(int remaining) {
    HiveService.user.put(AppConstants.keyAiCreditsRemaining, remaining);
    if (mounted) state = state.copyWith(creditsRemaining: remaining);
  }

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

      final remaining = response.data['credits_remaining'];
      if (remaining != null) _updateCredits(remaining as int);

      _handleResults(response.data['data']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        _addCreditLimitMessage();
      } else {
        _handleDioError(e);
      }
    } catch (e) {
      debugPrint('[AiChat] Exception: $e');
      _addError('Terjadi kesalahan: $e');
    }
  }

  // ── Receipt scan ────────────────────────────────────────────────────────────

  Future<void> scanReceipt(File imageFile) async {
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

      final remaining = response.data['credits_remaining'];
      if (remaining != null) _updateCredits(remaining as int);

      _handleResults(
        response.data['data'],
        labelOverride: (count) => count == 1
            ? 'Saya membaca 1 transaksi dari struk. Cek detail:'
            : 'Saya membaca $count transaksi dari struk. Cek detail:',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        _addCreditLimitMessage();
      } else {
        _handleDioError(e);
      }
    } catch (e) {
      debugPrint('[AiChat] scanReceipt Exception: $e');
      _addError('Gagal memproses struk: $e');
    } finally {
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
    required DateTime date,
  }) async {
    try {
      final txNotifier = _ref.read(transactionProvider.notifier);

      if (result.type == 'income') {
        await txNotifier.addIncome(
          title: result.title,
          amount: result.amount,
          categoryId: category?.id ?? 'other',
          categoryName: category?.name ?? result.categoryName,
          categoryIcon: category?.icon ?? result.categoryIcon,
          walletId: wallet?.id ?? '',
          walletName: wallet?.name ?? result.walletHint ?? 'Dompet',
          date: date,
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
          date: date,
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
          date: date,
          description: result.description,
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  void markSaved(String cardKey, double amount) {
    state = state.copyWith(
      savedAmounts: {...state.savedAmounts, cardKey: amount},
    );
    _save();
  }

  void markDismissed(String cardKey) {
    state = state.copyWith(
      dismissedCards: {...state.dismissedCards, cardKey},
    );
    _save();
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
    _save();
  }

  void _addCreditLimitMessage() {
    _updateCredits(0);
    final msg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_limit',
      text: 'Kredit AI harian kamu sudah habis (${AppConstants.aiFreeDailyLimit}x/hari). '
          'Upgrade ke Premium untuk catat AI tanpa batas!',
      isUser: false,
      isError: false,
      isCreditLimit: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, msg],
      isLoading: false,
    );
    _save();
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
    _save();
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
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
