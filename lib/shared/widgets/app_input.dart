import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// ── Base Input ────────────────────────────────────────────────────────────────

class AppInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          focusNode: focusNode,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            counterText: '',
            filled: true,
            fillColor: enabled ? AppColors.white : AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.danger, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Amount Input (khusus input uang Rupiah) ───────────────────────────────────

class AppAmountInput extends StatefulWidget {
  final String? label;
  final TextEditingController? controller;
  final ValueChanged<double>? onChanged;
  final bool enabled;

  const AppAmountInput({
    super.key,
    this.label,
    this.controller,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<AppAmountInput> createState() => _AppAmountInputState();
}

class _AppAmountInputState extends State<AppAmountInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  String _formatNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final number = int.parse(digits);
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: widget.label ?? 'Jumlah',
      hint: '0',
      controller: _controller,
      keyboardType: TextInputType.number,
      enabled: widget.enabled,
      prefixIcon: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Rp',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      onChanged: (value) {
        final formatted = _formatNumber(value);
        if (formatted != value) {
          _controller.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
        final digits = formatted.replaceAll('.', '');
        if (widget.onChanged != null && digits.isNotEmpty) {
          widget.onChanged!(double.parse(digits));
        }
      },
    );
  }
}

// ── Select Input (dropdown-like, tap to open) ─────────────────────────────────

class AppSelectInput extends StatelessWidget {
  final String? label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final Widget? prefixIcon;
  final bool enabled;

  const AppSelectInput({
    super.key,
    this.label,
    this.value,
    required this.hint,
    required this.onTap,
    this.prefixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: label,
      hint: hint,
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(text: value ?? ''),
      prefixIcon: prefixIcon,
      suffixIcon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textHint,
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
