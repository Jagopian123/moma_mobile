import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/subscription_model.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/hive/hive_service.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/subscription_provider.dart';

// Warna pilihan untuk langganan custom
const _kColors = [
  0xFF2563EB, 0xFF10B981, 0xFFEF4444, 0xFFF59E0B,
  0xFF8B5CF6, 0xFF06B6D4, 0xFFEC4899, 0xFFF97316,
  0xFF6366F1, 0xFF14B8A6, 0xFF84CC16, 0xFF64748B,
];

const _kCustom = SubscriptionPreset(
  name: 'Lainnya',
  icon: '➕',
  category: 'lainnya',
  amount: 0,
  cycle: 'monthly',
  color: 0xFF64748B,
);

class SubscriptionFormSheet extends ConsumerStatefulWidget {
  final SubscriptionModel? existing;

  const SubscriptionFormSheet({super.key, this.existing});

  @override
  ConsumerState<SubscriptionFormSheet> createState() =>
      _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends ConsumerState<SubscriptionFormSheet> {
  final _amountCtrl = TextEditingController();
  final _customNameCtrl = TextEditingController();

  SubscriptionPreset? _selectedPreset;
  String _customIcon = '📦';
  int _customColor = 0xFF2563EB;
  String _cycle = 'monthly';
  DateTime _startDate = DateTime.now();
  WalletModel? _wallet;

  String? _errorMsg;

  bool get _isEdit => widget.existing != null;
  bool get _isCustom => _selectedPreset == _kCustom;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = e.amount.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
      _cycle = e.cycle;
      _startDate = e.startDate;
      if (e.walletId != null) _wallet = HiveService.wallets.get(e.walletId);

      final match = kSubscriptionPresets.where((p) => p.name == e.name).firstOrNull;
      if (match != null) {
        _selectedPreset = match;
      } else {
        _selectedPreset = _kCustom;
        _customNameCtrl.text = e.name;
        _customIcon = e.icon;
        _customColor = e.color;
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _customNameCtrl.dispose();
    super.dispose();
  }

  String _formatNum(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  void _selectPreset(SubscriptionPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != _kCustom) {
        _amountCtrl.text = _formatNum(preset.amount.toInt());
        _cycle = preset.cycle;
      } else {
        _amountCtrl.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _errorMsg = null);

    if (_selectedPreset == null) {
      setState(() => _errorMsg = 'Pilih layanan terlebih dahulu');
      return;
    }

    final name = _isCustom ? _customNameCtrl.text.trim() : _selectedPreset!.name;
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Nama layanan tidak boleh kosong');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMsg = 'Jumlah tagihan tidak boleh kosong');
      return;
    }
    final icon = _isCustom ? _customIcon : _selectedPreset!.icon;
    final color = _isCustom ? _customColor : _selectedPreset!.color;
    final category = _selectedPreset!.category;
    final notifier = ref.read(subscriptionProvider.notifier);

    if (_isEdit) {
      await notifier.update(
        id: widget.existing!.id,
        name: name, icon: icon, category: category,
        amount: amount, cycle: _cycle, startDate: _startDate,
        color: color, walletId: _wallet?.id, walletName: _wallet?.name,
      );
    } else {
      await notifier.add(
        name: name, icon: icon, category: category,
        amount: amount, cycle: _cycle, startDate: _startDate,
        color: color, walletId: _wallet?.id, walletName: _wallet?.name,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Grid preset ───────────────────────────────────────────
        const Text(
          'Pilih Layanan',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        _buildPresetGrid(),
        const SizedBox(height: AppSpacing.md),

        // ── Hanya muncul saat Lainnya dipilih ────────────────────
        if (_isCustom) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _showIconPicker,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Color(_customColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: Color(_customColor).withValues(alpha: 0.4)),
                  ),
                  child: Center(
                      child: Text(_customIcon,
                          style: const TextStyle(fontSize: 26))),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppInput(
                  label: 'Nama Layanan',
                  hint: 'Contoh: Disney+, Duolingo...',
                  controller: _customNameCtrl,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildColorPicker(),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Jumlah ───────────────────────────────────────────────
        AppAmountInput(
          label: 'Jumlah Tagihan',
          controller: _amountCtrl,
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Siklus ───────────────────────────────────────────────
        const Text(
          'Siklus Tagihan',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _CycleChip(label: 'Mingguan', value: 'weekly',  selected: _cycle, onTap: (v) => setState(() => _cycle = v)),
            const SizedBox(width: 8),
            _CycleChip(label: 'Bulanan',  value: 'monthly', selected: _cycle, onTap: (v) => setState(() => _cycle = v)),
            const SizedBox(width: 8),
            _CycleChip(label: 'Tahunan',  value: 'yearly',  selected: _cycle, onTap: (v) => setState(() => _cycle = v)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Tanggal Mulai ────────────────────────────────────────
        const Text(
          'Tanggal Billing Pertama',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Text(
          'Tanggal pertama kali kamu ditagih layanan ini',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMMM yyyy', 'id').format(_startDate),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Dompet ───────────────────────────────────────────────
        const Text(
          'Dompet Pembayaran (opsional)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        _WalletPicker(
          selected: _wallet,
          onChanged: (w) => setState(() => _wallet = w),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Error banner ─────────────────────────────────────────
        if (_errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Submit ───────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(
              _isEdit ? 'Simpan Perubahan' : 'Tambah Langganan',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ── Grid 3 kolom ─────────────────────────────────────────────────────────────

  Widget _buildPresetGrid() {
    final allItems = [...kSubscriptionPresets, _kCustom];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: allItems.length,
      itemBuilder: (_, i) {
        final preset = allItems[i];
        final isSelected = _selectedPreset == preset;
        final isCustomEntry = preset == _kCustom;
        final brandColor = Color(preset.color);

        return GestureDetector(
          onTap: () => _selectPreset(preset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? brandColor.withValues(alpha: 0.15)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected ? brandColor : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCustomEntry)
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 30, color: AppColors.textHint)
                else
                  Text(preset.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    preset.name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? brandColor : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Color picker ─────────────────────────────────────────────────────────────

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Warna',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _kColors.map((c) {
            final isSelected = _customColor == c;
            return GestureDetector(
              onTap: () => setState(() => _customColor = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppColors.white, width: 2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Color(c).withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Icon picker ──────────────────────────────────────────────────────────────

  void _showIconPicker() {
    final icons = [
      '📦', '🎮', '📱', '💻', '🌐', '📰', '🏋️', '📚', '🎓',
      '🎯', '🛒', '🏠', '✈️', '🚗', '💊', '🎁', '🔑', '⚡',
      '🌟', '🔔', '📡', '🎤', '🖼️', '📷',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const Text('Pilih Ikon', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: icons
                  .map((icon) => GestureDetector(
                        onTap: () {
                          setState(() => _customIcon = icon);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _customIcon == icon
                                ? Color(_customColor).withValues(alpha: 0.15)
                                : AppColors.background,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _customIcon == icon
                                  ? Color(_customColor)
                                  : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(icon,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ── Cycle Chip ────────────────────────────────────────────────────────────────

class _CycleChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _CycleChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wallet Picker ─────────────────────────────────────────────────────────────

class _WalletPicker extends StatelessWidget {
  final WalletModel? selected;
  final ValueChanged<WalletModel?> onChanged;

  const _WalletPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final wallets = HiveService.wallets.values.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WalletModel?>(
          value: selected,
          isExpanded: true,
          hint: const Text('Pilih dompet...',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textHint)),
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem<WalletModel?>(
                value: null, child: Text('Tidak ada')),
            ...wallets.map(
                (w) => DropdownMenuItem(value: w, child: Text(w.name))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
