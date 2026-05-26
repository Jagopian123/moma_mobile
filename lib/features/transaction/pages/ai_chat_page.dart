import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/hive/models/category_model.dart';
import '../../../core/services/admob_service.dart';
import '../../../core/services/rating_service.dart';
import '../../../core/utils/category_matcher.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
  bool _limitWarningShown = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    // Scroll to bottom for already-loaded history when page reopens
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onTextChanged() {
    if (_textController.text.length >= 200 && !_limitWarningShown) {
      _limitWarningShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Maksimal 200 karakter',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textSecondary,
        ),
      );
    } else if (_textController.text.length < 200) {
      _limitWarningShown = false;
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
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
      imageQuality:
          90, // light pre-quality — ImageCompressUtil does the real work
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
    final isPremium = ref.watch(authProvider).user?.isPremium == true;

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
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Image.asset(
              isPremium
                  ? 'assets/images/mascot-profile-pro.png'
                  : 'assets/images/mascot-profile.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Moma AI', style: AppTextStyles.h4),
                    const SizedBox(width: 6),
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                size: 11, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Premium',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => context.push('/premium'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: chatState.isLimitReached
                                ? AppColors.expense.withValues(alpha: 0.12)
                                : const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 11,
                                color: chatState.isLimitReached
                                    ? AppColors.expense
                                    : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                chatState.isLimitReached
                                    ? 'Habis'
                                    : '${chatState.creditsRemaining}/${AppConstants.aiFreeMonthlyLimit}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: chatState.isLimitReached
                                      ? AppColors.expense
                                      : const Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const Text(
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
    final isPremium = ref.read(authProvider).user?.isPremium == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Image.asset(
            isPremium
                ? 'assets/images/mascot-profile-pro.png'
                : 'assets/images/mascot-profile.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
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
          children: examples
              .map((e) => _ExampleChip(
                  text: e,
                  onTap: () {
                    _textController.text = e;
                  }))
              .toList(),
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
        if (msg.isUser)
          return _UserBubble(text: msg.text, imagePath: msg.imagePath);
        if (msg.isCreditLimit) {
          return _CreditLimitBubble(onUpgrade: () => context.push('/premium'));
        }
        if (msg.transactionResults != null &&
            msg.transactionResults!.isNotEmpty) {
          return _TransactionGroup(
              message: msg, results: msg.transactionResults!);
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
    final isRequesting = voiceState.status == VoiceStatus.requestingPermission;

    return Container(
      color: AppColors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: AppColors.border),

          // ── Listening banner ──────────────────────────────────────
          if (isListening) _buildListeningBanner(voiceState),

          // ── Input row ─────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
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
                          maxLength: 200,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
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
                        onLongPressStart:
                            isLoading ? null : (_) => _startVoice(),
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
                            borderRadius: BorderRadius.circular(AppRadius.full),
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
                            borderRadius: BorderRadius.circular(AppRadius.full),
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Moma AI can make mistakes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningBanner(VoiceState voiceState) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
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
    final isPremium = ref.read(authProvider).user?.isPremium == true;
    return Image.asset(
      isPremium
          ? 'assets/images/mascot-profile-pro.png'
          : 'assets/images/mascot-profile.png',
      width: 28,
      height: 28,
      fit: BoxFit.contain,
    );
  }
}

void _openFullImage(BuildContext context, String path) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogCtx) => GestureDetector(
      onTap: () => Navigator.pop(dialogCtx),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
                    GestureDetector(
                      onTap: () => _openFullImage(context, imagePath!),
                      child: Image.file(
                        File(imagePath!),
                        width: 220,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
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

class _AiBubble extends ConsumerWidget {
  final String text;
  final bool isError;
  const _AiBubble({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiAvatar(ref),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFFEF2F2) : AppColors.white,
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

  Widget _aiAvatar(WidgetRef ref) {
    final isPremium = ref.read(authProvider).user?.isPremium == true;
    return Image.asset(
      isPremium
          ? 'assets/images/mascot-profile-pro.png'
          : 'assets/images/mascot-profile.png',
      width: 28,
      height: 28,
      fit: BoxFit.contain,
    );
  }
}

// ── Credit Limit Bubble ───────────────────────────────────────────────────────

class _CreditLimitBubble extends ConsumerStatefulWidget {
  final VoidCallback onUpgrade;
  const _CreditLimitBubble({required this.onUpgrade});

  @override
  ConsumerState<_CreditLimitBubble> createState() => _CreditLimitBubbleState();
}

class _CreditLimitBubbleState extends ConsumerState<_CreditLimitBubble> {
  bool _isWatchingAd = false;
  bool _adGranted = false;

  Future<void> _watchAd() async {
    if (_isWatchingAd) return;

    if (!AdmobService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Iklan belum siap, coba lagi sebentar.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isWatchingAd = true);

    final shown = await AdmobService.showRewardedAd(
      onRewarded: () async {
        final result = await ref.read(aiChatProvider.notifier).grantAdBonus();
        if (!mounted) return;
        setState(() {
          _isWatchingAd = false;
          _adGranted = result == AdBonusResult.success;
        });
        if (result == AdBonusResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '+${AppConstants.adBonusCredits} kredit AI berhasil ditambahkan!',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
              backgroundColor: AppColors.income,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (result == AdBonusResult.limitReached) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sudah 3x nonton hari ini. Kembali besok!',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );

    if (!shown && mounted) {
      setState(() => _isWatchingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.read(authProvider).user?.isPremium == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            isPremium
                ? 'assets/images/mascot-profile-pro.png'
                : 'assets/images/mascot-profile.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Kredit AI bulan ini habis 😔',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kamu sudah menggunakan ${AppConstants.aiFreeMonthlyLimit}x kuota AI bulan ini. '
                    'Upgrade ke Premium untuk catat AI tanpa batas!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text(
                        'Upgrade ke Premium',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (!_adGranted) ...[
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isWatchingAd ? null : _watchAd,
                        icon: _isWatchingAd
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.amber,
                                ),
                              )
                            : const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                                color: Colors.amber,
                              ),
                        label: Text(
                          _isWatchingAd
                              ? 'Memuat iklan...'
                              : 'Tonton Iklan (+${AppConstants.adBonusCredits} kredit)',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                              color: Colors.amber.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.xs),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.income, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Kredit bonus berhasil ditambahkan',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
  const _TransactionCard(
      {super.key, required this.message, required this.result});

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
  late TextEditingController _amountController;
  late DateTime _date;

  String get _cardKey =>
      '${widget.message.id}_${widget.result.title}_${widget.result.amount}';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _ThousandsFormatter.format(widget.result.amount.toInt()),
    );
    final aiDate = widget.result.date;
    final now = DateTime.now();
    _date = aiDate != null
        ? DateTime(aiDate.year, aiDate.month, aiDate.day, now.hour, now.minute)
        : now;
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
        _toWalletId =
            notifier.matchWallet(widget.result.toWalletHint, wallets)?.id;
      }

      // 1. Match category dari nama yang dikembalikan AI (parent atau sub user)
      final matchedCat = notifier.matchCategory(
        widget.result.categoryName,
        widget.result.type,
        categories,
      );

      if (matchedCat != null) {
        if (matchedCat.parentId != null) {
          // AI mengembalikan sub-kategori user → pakai langsung
          _categoryId = matchedCat.id;
        } else if (!matchedCat.isDefault) {
          // AI mengembalikan parent kategori user → pakai langsung,
          // CategoryMatcher tidak tahu sub-kategori user jadi skip
          _categoryId = matchedCat.id;
        } else {
          // AI mengembalikan parent sistem → cek user subs dulu, baru CategoryMatcher
          final titleLower = widget.result.title.toLowerCase();
          final userSubMatch = categories
              .where((c) => c.parentId == matchedCat.id && !c.isDefault)
              .cast<CategoryModel?>()
              .firstWhere(
                (c) =>
                    c!.name.toLowerCase() == titleLower ||
                    titleLower.contains(c.name.toLowerCase()) ||
                    c.name.toLowerCase().contains(titleLower),
                orElse: () => null,
              );

          if (userSubMatch != null) {
            // Ada user sub yang cocok → pakai, skip CategoryMatcher
            _categoryId = userSubMatch.id;
          } else {
            final subId = CategoryMatcher.findSubcategoryId(
              widget.result.title,
              matchedCat.id,
            );

            if (subId != null) {
              _categoryId =
                  categories.where((c) => c.id == subId).firstOrNull?.id ??
                      matchedCat.id;
            } else {
              final global = CategoryMatcher.findSubcategoryIdGlobal(
                widget.result.title,
              );
              if (global != null) {
                final (globalSubId, globalParentId) = global;
                final overrideCat =
                    categories.where((c) => c.id == globalParentId).firstOrNull;
                final overrideSub =
                    categories.where((c) => c.id == globalSubId).firstOrNull;
                // Hanya override jika tipe parent cocok dengan tipe transaksi
                final typeMatches = overrideCat != null &&
                    (overrideCat.type == widget.result.type ||
                        overrideCat.type == 'both');
                _categoryId = (typeMatches && overrideSub != null)
                    ? overrideSub.id
                    : matchedCat.id;
              } else {
                _categoryId = matchedCat.id;
              }
            }
          }
        }
      }
    });
  }

  Color get _typeColor => switch (widget.result.type) {
        'income' => AppColors.income,
        'transfer' => AppColors.transfer,
        _ => AppColors.expense,
      };

  String get _typeLabel => switch (widget.result.type) {
        'income' => 'Pemasukan',
        'transfer' => 'Transfer',
        _ => 'Pengeluaran',
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
    final wallets = ref.read(walletProvider);
    final categories = ref.read(categoryProvider);
    final editedAmount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ??
            widget.result.amount;
    final success = await ref.read(aiChatProvider.notifier).confirmTransaction(
          result: widget.result.copyWith(amount: editedAmount),
          messageId: widget.message.id,
          wallet: _walletById(wallets, _walletId),
          toWallet: _walletById(wallets, _toWalletId),
          category: _categoryById(categories, _categoryId),
          date: _date,
        );
    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        ref.read(aiChatProvider.notifier).markSaved(_cardKey, editedAmount);
        RatingService.onTransactionSaved();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    if (chatState.dismissedCards.contains(_cardKey))
      return _buildDismissedCard();
    final savedAmount = chatState.savedAmounts[_cardKey];
    if (savedAmount != null) return _buildSavedCard(savedAmount);
    return _buildPreviewCard();
  }

  Widget _buildPreviewCard() {
    final wallets = ref.watch(walletProvider);
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
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
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
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
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
                                  _ThousandsFormatter(),
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
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: Divider(height: 1, color: AppColors.border),
                  ),

                  // Wallet (dari)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: _buildWalletDropdown(
                      label: isTransfer ? 'Dari' : 'Dompet',
                      icon: Icons.account_balance_wallet_rounded,
                      selectedId: _walletId,
                      wallets: wallets,
                      onChanged: (id) => setState(() => _walletId = id),
                    ),
                  ),

                  if (isTransfer) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      child: _buildWalletDropdown(
                        label: 'Ke',
                        icon: Icons.arrow_forward_rounded,
                        selectedId: _toWalletId,
                        wallets:
                            wallets.where((w) => w.id != _walletId).toList(),
                        onChanged: (id) => setState(() => _toWalletId = id),
                      ),
                    ),
                  ],

                  if (!isTransfer && parentCategories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      child: _buildCategoryRow(
                        selectedId: _categoryId,
                        allCategories: categories,
                        parentCategories: parentCategories,
                      ),
                    ),
                  ],

                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: _buildDateRow(),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => ref
                                    .read(aiChatProvider.notifier)
                                    .markDismissed(_cardKey),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
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
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
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

  Widget _buildCategoryRow({
    required String? selectedId,
    required List<CategoryModel> allCategories,
    required List<CategoryModel> parentCategories,
  }) {
    final selected = selectedId == null
        ? null
        : allCategories.where((c) => c.id == selectedId).firstOrNull;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AiCategorySheet(
          parentCategories: parentCategories,
          onSelect: (cat) => setState(() => _categoryId = cat.id),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.label_rounded,
                size: 14, color: AppColors.textSecondary),
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
              child: Row(
                children: [
                  if (selected != null) ...[
                    Text(selected.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      selected?.name ?? 'Pilih Kategori',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: selected != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow() {
    final label = DateFormat('d MMM yyyy, HH:mm').format(_date);
    return GestureDetector(
      onTap: _pickDate,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            const Text(
              'Tanggal:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_rounded,
                      size: 13, color: AppColors.textHint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Widget _buildSavedCard(double amount) {
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
                border:
                    Border.all(color: AppColors.income.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.income, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${widget.result.title} · ${_currencyFmt.format(amount)} tersimpan!',
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
    final isPremium = ref.read(authProvider).user?.isPremium == true;
    return Image.asset(
      isPremium
          ? 'assets/images/mascot-profile-pro.png'
          : 'assets/images/mascot-profile.png',
      width: 28,
      height: 28,
      fit: BoxFit.contain,
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

// ── Thousands Separator Formatter ─────────────────────────────────────────────

class _ThousandsFormatter extends TextInputFormatter {
  static String format(int value) {
    if (value == 0) return '0';
    final digits = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = format(int.tryParse(digits) ?? 0);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── AI Category Sheet ─────────────────────────────────────────────────────────

class _AiCategorySheet extends ConsumerStatefulWidget {
  final List<CategoryModel> parentCategories;
  final ValueChanged<CategoryModel> onSelect;

  const _AiCategorySheet({
    required this.parentCategories,
    required this.onSelect,
  });

  @override
  ConsumerState<_AiCategorySheet> createState() => _AiCategorySheetState();
}

class _AiCategorySheetState extends ConsumerState<_AiCategorySheet> {
  CategoryModel? _selectedParent;

  @override
  Widget build(BuildContext context) {
    final items = _selectedParent == null
        ? widget.parentCategories
        : ref
            .read(categoryProvider.notifier)
            .subCategories(_selectedParent!.id);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (_selectedParent != null)
                  IconButton(
                    onPressed: () => setState(() => _selectedParent = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                const SizedBox(width: 4),
                Text(
                  _selectedParent?.name ?? 'Pilih Kategori',
                  style: AppTextStyles.h4,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              children: [
                if (_selectedParent != null)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                          _selectedParent!.color.replaceFirst('#', '0xFF'),
                        )).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(_selectedParent!.icon,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    title: Text(
                      'Semua ${_selectedParent!.name}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    subtitle: const Text(
                      'Pilih tanpa subkategori',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.primary, size: 20),
                    onTap: () {
                      widget.onSelect(_selectedParent!);
                      Navigator.pop(context);
                    },
                  ),
                ...items.map((cat) {
                  final hasSubs = _selectedParent == null &&
                      ref
                          .read(categoryProvider.notifier)
                          .subCategories(cat.id)
                          .isNotEmpty;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                          cat.color.replaceFirst('#', '0xFF'),
                        )).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(cat.icon,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    title: Text(
                      cat.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: hasSubs
                        ? const Text(
                            'Ketuk untuk lihat subkategori',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          )
                        : null,
                    trailing: hasSubs
                        ? const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textHint)
                        : null,
                    onTap: () {
                      if (hasSubs) {
                        setState(() => _selectedParent = cat);
                      } else {
                        widget.onSelect(cat);
                        Navigator.pop(context);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
