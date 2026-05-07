import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ── Status ────────────────────────────────────────────────────────────────────

enum VoiceStatus { idle, requestingPermission, listening, done, error }

// ── State ─────────────────────────────────────────────────────────────────────

class VoiceState {
  final VoiceStatus status;
  final String transcript;
  final String? errorMessage;
  final double soundLevel; // 0.0 – 1.0 (normalised)

  const VoiceState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.errorMessage,
    this.soundLevel = 0.0,
  });

  bool get isListening => status == VoiceStatus.listening;
  bool get isIdle => status == VoiceStatus.idle || status == VoiceStatus.done;

  VoiceState copyWith({
    VoiceStatus? status,
    String? transcript,
    // Pass null explicitly to clear the error
    Object? errorMessage = _sentinel,
    double? soundLevel,
  }) {
    return VoiceState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      soundLevel: soundLevel ?? this.soundLevel,
    );
  }
}

// Sentinel so copyWith can distinguish "not provided" from explicit null.
const _sentinel = Object();

// ── Notifier ──────────────────────────────────────────────────────────────────

class VoiceNotifier extends StateNotifier<VoiceState> {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  VoiceNotifier() : super(const VoiceState());

  // Called by the UI when the mic button is tapped.
  // [onFinalResult] fires once when recognition produces a confirmed result.
  Future<void> startListening({required ValueChanged<String> onFinalResult}) async {
    // ── 1. Request microphone permission ──────────────────────────────
    state = state.copyWith(status: VoiceStatus.requestingPermission);

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _setError(
        mic.isPermanentlyDenied
            ? 'Izin mikrofon ditolak permanen. Buka Pengaturan → Aplikasi → Izin.'
            : 'Izin mikrofon ditolak.',
      );
      return;
    }

    // ── 2. Init SpeechToText (once per notifier lifetime) ─────────────
    if (!_initialized) {
      _initialized = await _stt.initialize(
        onError: (e) => _onSttError(e.errorMsg),
        onStatus: (s) {
          debugPrint('[Voice] status: $s');
          // "done" or "notListening" fired by the engine after silence
          if ((s == 'done' || s == 'notListening') && state.isListening) {
            _onSilenceDetected();
          }
        },
      );
    }

    if (!_initialized) {
      _setError('Speech-to-text tidak tersedia di perangkat ini.');
      return;
    }

    // ── 3. Pick locale (prefer Indonesian, fall back to device default) ─
    String localeId = 'id_ID';
    try {
      final locales = await _stt.locales();
      final id = locales.firstWhere(
        (l) => l.localeId.startsWith('id'),
        orElse: () => locales.first,
      );
      localeId = id.localeId;
    } catch (_) {
      // keep default
    }

    // ── 4. Start listening ────────────────────────────────────────────
    state = state.copyWith(
      status: VoiceStatus.listening,
      transcript: '',
      errorMessage: null,
      soundLevel: 0,
    );

    await _stt.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 30), // PTT: user controls stop manually
      onResult: (result) {
        state = state.copyWith(transcript: result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          state = state.copyWith(status: VoiceStatus.done);
          onFinalResult(result.recognizedWords);
        }
      },
      onSoundLevelChange: (level) {
        // level range is roughly -2 to 10; normalise to 0–1
        final norm = ((level + 2) / 12).clamp(0.0, 1.0);
        state = state.copyWith(soundLevel: norm);
      },
    );
  }

  // Stop listening and fire the callback with whatever was heard so far.
  void stopListening({ValueChanged<String>? onFinalResult}) {
    _stt.stop();
    final text = state.transcript;
    state = state.copyWith(status: VoiceStatus.idle, soundLevel: 0);
    if (text.isNotEmpty) onFinalResult?.call(text);
  }

  // Discard everything, return to idle.
  void cancel() {
    _stt.cancel();
    state = const VoiceState();
  }

  void clearError() {
    if (state.status == VoiceStatus.error) {
      state = const VoiceState();
    }
  }

  // ── Private ───────────────────────────────────────────────────────────

  void _onSilenceDetected() {
    // Engine stopped on its own after a pause — treat as done.
    if (state.transcript.isNotEmpty) {
      state = state.copyWith(status: VoiceStatus.done, soundLevel: 0);
    } else {
      state = state.copyWith(status: VoiceStatus.idle, soundLevel: 0);
    }
  }

  void _onSttError(String raw) {
    debugPrint('[Voice] error: $raw');
    final String friendly;
    if (raw.contains('not-allowed') || raw.contains('permission')) {
      friendly = 'Izin mikrofon ditolak.';
    } else if (raw.contains('no-speech') || raw.contains('no_speech')) {
      friendly = 'Tidak ada suara terdeteksi. Coba lagi.';
    } else if (raw.contains('network')) {
      friendly = 'Koneksi internet diperlukan untuk pengenalan suara.';
    } else if (raw.contains('audio')) {
      friendly = 'Mikrofon tidak dapat diakses.';
    } else if (raw.contains('aborted')) {
      // User cancelled — silent, not an error
      state = const VoiceState();
      return;
    } else {
      friendly = 'Gagal mengenali suara. Coba lagi.';
    }
    _setError(friendly);
  }

  void _setError(String message) {
    state = state.copyWith(
      status: VoiceStatus.error,
      errorMessage: message,
      soundLevel: 0,
    );
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final voiceProvider =
    StateNotifierProvider.autoDispose<VoiceNotifier, VoiceState>(
  (_) => VoiceNotifier(),
);
