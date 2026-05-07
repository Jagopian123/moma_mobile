import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/hive/models/category_model.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../asset/providers/wallet_provider.dart';
import '../models/ai_transaction_result.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/category_provider.dart';
import '../providers/voice_provider.dart';

// ── Formatter ─────────────────────────────────────────────────────────────────

final _currencyFmt = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

// ── Page ──────────────────────────────────────────────────────────────────────

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    FocusScope.of(context).unfocus();
    // Cancel voice if still active before sending
    final voice = ref.read(voiceProvider);
    if (voice.isListening) ref.read(voiceProvider.notifier).cancel();
    await ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  // ── Receipt scan ──────────────────────────────────────────────────────────

  Future<void> _showImagePickerSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const Text('Pilih Sumber Gambar', style: AppTextStyles.h4),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _PickerOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      color: const Color(0xFF2563EB),
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _PickerOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                      color: const Color(0xFF7C3AED),
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      imageQuality: 90, // light pre-quality — ImageCompressUtil does the real work
      maxWidth: 2048,
    );

    if (xfile == null || !mounted) return;

    await ref.read(aiChatProvider.notifier).scanReceipt(File(xfile.path));
    _scrollToBottom();
  }

  void _startVoice() {
    ref.read(voiceProvider.notifier).startListening(
      onFinalResult: (text) {
        // Safety net if engine auto-stops (e.g. very long silence)
        _textController.text = text;
        _textController.selection =
            TextSelection.fromPosition(TextPosition(offset: text.length));
      },
    );
  }

  void _stopVoice() {
    ref.read(voiceProvider.notifier).stopListening(
      onFinalResult: (text) {
        _textController.text = text;
        _textController.selection =
            TextSelection.fromPosition(TextPosition(offset: text.length));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final voiceState = ref.watch(voiceProvider);

    ref.listen(aiChatProvider, (_, __) => _scrollToBottom());

    // Real-time transcript → fill text field
    ref.listen<VoiceState>(voiceProvider, (prev, next) {
      if (next.isListening && next.transcript.isNotEmpty) {
        if (_textController.text != next.transcript) {
          _textController.text = next.transcript;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: next.transcript.length),
          );
        }
      }
      // Error notification
      if (next.status == VoiceStatus.error &&
          prev?.status != VoiceStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage!,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) ref.read(voiceProvider.notifier).clearError();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Catat Transaksi', style: AppTextStyles.h4),
                Text(
                  'Ketik transaksi dengan bahasa natural',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildWelcomeView()
                : _buildChatList(chatState),
          ),
          _buildInputBar(chatState.isLoading, voiceState),
        ],
      ),
    );
  }

  // ── Welcome Screen ────────────────────────────────────────────────

  Widget _buildWelcomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Catat transaksi dengan\ncara natural!',
            textAlign: TextAlign.center,
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Ceritakan transaksimu seperti chat biasa,\nAI akan memahami dan menyimpannya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildExampleChips(),
        ],
      ),
    );
  }

  Widget _buildExampleChips() {
    final examples = [
      'beli makan sate 25k cash',
      'gaji bulan ini 5 juta',
      'bayar listrik 350 ribu',
      'transfer ke bca 100 ribu',
      'jajan boba 35k gopay',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contoh pesan:',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: examples.map((e) => _ExampleChip(text: e, onTap: () {
            _textController.text = e;
          })).toList(),
        ),
      ],
    );
  }

  // ── Chat List ─────────────────────────────────────────────────────

  Widget _buildChatList(AiChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length) {
          return _buildTypingIndicator();
        }
        final msg = chatState.messages[index];
        if (msg.isUser) return _UserBubble(text: msg.text, imagePath: msg.imagePath);
        if (msg.transactionResults != null && msg.transactionResults!.isNotEmpty) {
          return _TransactionGroup(message: msg, results: msg.transactionResults!);
        }
        return _AiBubble(text: msg.text, isError: msg.isError);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          _aiAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotPulse(delay: 0),
                SizedBox(width: 4),
                _DotPulse(delay: 150),
                SizedBox(width: 4),
                _DotPulse(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────

  Widget _buildInputBar(bool isLoading, VoiceState voiceState) {
    final isListening = voiceState.isListening;
    final isRequesting =
        voiceState.status == VoiceStatus.requestingPermission;

    return Container(
      color: AppColors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: AppColors.border),

          // ── Listening banner ──────────────────────────────────────
          if (isListening)
            _buildListeningBanner(voiceState),

          // ── Input row ─────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !isLoading,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: isListening
                            ? 'Mendengarkan...'
                            : 'Ketik atau tahan mic...',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: isListening
                              ? AppColors.expense.withValues(alpha: 0.6)
                              : AppColors.textHint,
                          fontStyle: isListening
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        filled: true,
                        fillColor: isListening
                            ? const Color(0xFFFEF2F2)
                            : AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.xs + 2),

                  // Camera / receipt scan button
                  GestureDetector(
                    onTap: isLoading ? null : _showImagePickerSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: isLoading
                            ? AppColors.border
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.xs + 2),

                  // Mic button — tahan untuk rekam, lepas untuk selesai
                  GestureDetector(
                    onLongPressStart: isLoading ? null : (_) => _startVoice(),
                    onLongPressEnd: (_) => _stopVoice(),
                    onLongPressCancel: () =>
                        ref.read(voiceProvider.notifier).cancel(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isListening
                            ? AppColors.expense
                            : AppColors.background,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: isRequesting
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Icon(
                              Icons.mic_rounded,
                              color: isListening
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.xs + 2),

                  // Send button
                  GestureDetector(
                    onTap: isLoading ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isLoading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFF2563EB)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: isLoading ? AppColors.border : null,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningBanner(VoiceState voiceState) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.expense.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const _PulsingMicIcon(),
          const SizedBox(width: AppSpacing.sm),
          // Sound-level bar
          _SoundLevelBar(level: voiceState.soundLevel),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              voiceState.transcript.isNotEmpty
                  ? voiceState.transcript
                  : 'Mendengarkan...',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: voiceState.transcript.isNotEmpty
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontStyle: voiceState.transcript.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Cancel button
          GestureDetector(
            onTap: () => ref.read(voiceProvider.notifier).cancel(),
            child: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
    );
  }
}

// ── User Bubble ───────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  final String? imagePath;
  const _UserBubble({required this.text, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Receipt image thumbnail
                  if (imagePath != null)
                    Image.file(
                      File(imagePath!),
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  // Label text
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (imagePath != null) ...[
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Bubble ─────────────────────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  final String text;
  final bool isError;
  const _AiBubble({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFFEF2F2)
                    : AppColors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: isError ? AppColors.expense : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
    );
  }
}

// ── Transaction Group (text bubble + N cards) ─────────────────────────────────

class _TransactionGroup extends StatelessWidget {
  final ChatMessage message;
  final List<AiTransactionResult> results;
  const _TransactionGroup({required this.message, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiBubble(text: message.text),
        ...results.map(
          (r) => _TransactionCard(
            key: ValueKey('${message.id}_${r.title}_${r.amount}'),
            message: message,
            result: r,
          ),
        ),
      ],
    );
  }
}

// ── Transaction Preview Card ──────────────────────────────────────────────────

class _TransactionCard extends ConsumerStatefulWidget {
  final ChatMessage message;
  final AiTransactionResult result;
  const _TransactionCard({super.key, required this.message, required this.result});

  @override
  ConsumerState<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<_TransactionCard> {
  // Store IDs, not object references — avoids DropdownButton identity mismatch
  // when the provider rebuilds and creates new object instances.
  String? _walletId;
  String? _toWalletId;
  String? _categoryId;
  bool _saving = false;
  bool _saved = false;
  bool _dismissed = false;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.result.amount.toInt().toString(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelect());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _autoSelect() {
    if (!mounted) return;
    final notifier = ref.read(aiChatProvider.notifier);
    final wallets = ref.read(walletProvider);
    final categories = ref.read(categoryProvider);
    setState(() {
      _walletId = notifier.matchWallet(widget.result.walletHint, wallets)?.id;
      if (widget.result.type == 'transfer') {
        _toWalletId = notifier.matchWallet(widget.result.toWalletHint, wallets)?.id;
      }
      _categoryId = notifier.matchCategory(
        widget.result.categoryName,
        widget.result.type,
        categories,
      )?.id;
    });
  }

  Color get _typeColor => switch (widget.result.type) {
        'income'   => AppColors.income,
        'transfer' => AppColors.transfer,
        _          => AppColors.expense,
      };

  String get _typeLabel => switch (widget.result.type) {
        'income'   => 'Pemasukan',
        'transfer' => 'Transfer',
        _          => 'Pengeluaran',
      };

  WalletModel? _walletById(List<WalletModel> wallets, String? id) {
    if (id == null) return null;
    for (final w in wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  CategoryModel? _categoryById(List<CategoryModel> categories, String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final wallets    = ref.read(walletProvider);
    final categories = ref.read(categoryProvider);
    final editedAmount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? widget.result.amount;
    final success = await ref.read(aiChatProvider.notifier).confirmTransaction(
      result:   widget.result.copyWith(amount: editedAmount),
      messageId: widget.message.id,
      wallet:   _walletById(wallets, _walletId),
      toWallet: _walletById(wallets, _toWalletId),
      category: _categoryById(categories, _categoryId),
    );
    if (mounted) {
      setState(() {
        _saving = false;
        _saved  = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return _buildDismissedCard();
    if (_saved)     return _buildSavedCard();
    return _buildPreviewCard();
  }

  Widget _buildPreviewCard() {
    final wallets    = ref.watch(walletProvider);
    final categories = ref.watch(categoryProvider);
    final isTransfer = widget.result.type == 'transfer';

    final parentCategories = categories
        .where((c) =>
            c.parentId == null &&
            (c.type == widget.result.type || c.type == 'both'))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardAvatar(),
          const SizedBox(width: AppSpacing.sm),
          // Expanded (not Flexible) so the card is properly width-constrained
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                border: Border(
                  left: BorderSide(color: _typeColor, width: 3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            _typeLabel,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _typeColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.result.categoryIcon,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),

                  // Title & Amount
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.result.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Rp ',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _typeColor,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _typeColor,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Divider(height: 1, color: AppColors.border),
                  ),

                  // Wallet (dari)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _buildWalletDropdown(
                      label: isTransfer ? 'Dari' : 'Dompet',
                      icon: Icons.account_balance_wallet_rounded,
                      selectedId: _walletId,
                      wallets: wallets,
                      onChanged: (id) => setState(() => _walletId = id),
                    ),
                  ),

                  if (isTransfer) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _buildWalletDropdown(
                        label: 'Ke',
                        icon: Icons.arrow_forward_rounded,
                        selectedId: _toWalletId,
                        wallets: wallets.where((w) => w.id != _walletId).toList(),
                        onChanged: (id) => setState(() => _toWalletId = id),
                      ),
                    ),
                  ],

                  if (!isTransfer && parentCategories.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: _buildCategoryDropdown(
                        selectedId: _categoryId,
                        categories: parentCategories,
                        onChanged: (id) => setState(() => _categoryId = id),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _dismissed = true),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_saving || _walletId == null)
                                ? null
                                : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _typeColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Simpan',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletDropdown({
    required String label,
    required IconData icon,
    required String? selectedId,
    required List<WalletModel> wallets,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure the selected ID exists in the current list
    final validId = wallets.any((w) => w.id == selectedId) ? selectedId : null;
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButton<String>(
            value: validId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            items: wallets
                .map((w) => DropdownMenuItem<String>(
                      value: w.id,
                      child: Text(
                        '${w.icon}  ${w.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown({
    required String? selectedId,
    required List<CategoryModel> categories,
    required ValueChanged<String?> onChanged,
  }) {
    final validId = categories.any((c) => c.id == selectedId) ? selectedId : null;
    return Row(
      children: [
        const Icon(Icons.label_rounded, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        const Text(
          'Kategori:',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButton<String>(
            value: validId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            items: categories
                .map((c) => DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(
                        '${c.icon}  ${c.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.income, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${widget.result.title} · ${_currencyFmt.format(widget.result.amount)} tersimpan!',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.income,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissedCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: const Text(
              'Dibatalkan.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
    );
  }
}

// ── Example Chip ──────────────────────────────────────────────────────────────

class _ExampleChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _ExampleChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '"$text"',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ── Picker Option (Camera / Gallery button in bottom sheet) ──────────────────

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing Mic Icon (used in listening banner) ───────────────────────────────

class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 15),
      ),
    );
  }
}

// ── Sound Level Bar ───────────────────────────────────────────────────────────

class _SoundLevelBar extends StatelessWidget {
  final double level; // 0.0 – 1.0
  const _SoundLevelBar({required this.level});

  @override
  Widget build(BuildContext context) {
    const barCount = 4;
    const maxHeight = 16.0;
    const minHeight = 3.0;
    // Each bar gets a slightly different multiplier so they look varied
    const multipliers = [0.6, 1.0, 0.8, 0.5];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(barCount, (i) {
        final h = (minHeight + (maxHeight - minHeight) * level * multipliers[i])
            .clamp(minHeight, maxHeight);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ── Dot Pulse Animation ───────────────────────────────────────────────────────

class _DotPulse extends StatefulWidget {
  final int delay;
  const _DotPulse({required this.delay});

  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
