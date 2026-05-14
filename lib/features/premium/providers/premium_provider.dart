import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum PurchaseFlowStatus { idle, loading, success, error }

class PremiumState {
  final bool isAvailable;
  final List<ProductDetails> products;
  final PurchaseFlowStatus status;
  final String? errorMessage;

  const PremiumState({
    this.isAvailable = false,
    this.products = const [],
    this.status = PurchaseFlowStatus.idle,
    this.errorMessage,
  });

  PremiumState copyWith({
    bool? isAvailable,
    List<ProductDetails>? products,
    PurchaseFlowStatus? status,
    String? errorMessage,
  }) {
    return PremiumState(
      isAvailable: isAvailable ?? this.isAvailable,
      products: products ?? this.products,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  ProductDetails? get monthly => products.where(
    (p) => p.id == AppConstants.iapMonthly).firstOrNull;

  ProductDetails? get yearly => products.where(
    (p) => p.id == AppConstants.iapYearly).firstOrNull;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PremiumNotifier extends StateNotifier<PremiumState> {
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  PremiumNotifier(this._ref) : super(const PremiumState()) {
    _init();
  }

  Future<void> _init() async {
    final iap = InAppPurchase.instance;
    final available = await iap.isAvailable();

    if (!available) {
      if (mounted) state = state.copyWith(isAvailable: false);
      return;
    }

    // Listen to purchase stream for the lifetime of this notifier
    _purchaseSub = iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[IAP] Purchase stream error: $e'),
    );

    await _loadProducts();
    if (mounted) state = state.copyWith(isAvailable: true);
  }

  Future<void> _loadProducts() async {
    try {
      final response = await InAppPurchase.instance
          .queryProductDetails(AppConstants.iapProductIds);

      if (response.error != null) {
        debugPrint('[IAP] Query error: ${response.error}');
      }

      if (mounted && response.productDetails.isNotEmpty) {
        state = state.copyWith(products: response.productDetails);
      }
    } catch (e) {
      debugPrint('[IAP] Failed to load products: $e');
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (state.status == PurchaseFlowStatus.loading) return;

    state = state.copyWith(status: PurchaseFlowStatus.loading, errorMessage: null);

    try {
      final param = PurchaseParam(productDetails: product);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      // Result comes via purchase stream → _onPurchaseUpdate
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          status: PurchaseFlowStatus.error,
          errorMessage: 'Gagal memulai pembelian: $e',
        );
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      if (mounted) state = state.copyWith(status: PurchaseFlowStatus.loading);
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      if (mounted) {
        state = state.copyWith(
          status: PurchaseFlowStatus.error,
          errorMessage: purchase.error?.message ?? 'Pembelian gagal',
        );
      }
      await _complete(purchase);
      return;
    }

    if (purchase.status == PurchaseStatus.canceled) {
      if (mounted) state = state.copyWith(status: PurchaseFlowStatus.idle);
      await _complete(purchase);
      return;
    }

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      final token = purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;

      final success = await _activateOnBackend(token, productId);

      if (mounted) {
        state = state.copyWith(
          status: success ? PurchaseFlowStatus.success : PurchaseFlowStatus.error,
          errorMessage: success ? null : 'Verifikasi pembelian gagal. Hubungi support.',
        );
      }

      await _complete(purchase);
    }
  }

  Future<bool> _activateOnBackend(String token, String productId) async {
    try {
      final response = await ApiService().dio.post('/premium/activate', data: {
        'purchase_token': token,
        'product_id': productId,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final authNotifier = _ref.read(authProvider.notifier);
        final currentUser = _ref.read(authProvider).user;

        if (currentUser != null) {
          authNotifier.updateUser(
            currentUser.copyWith(isPremium: data['is_premium'] ?? true),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[IAP] Backend activation error: $e');
      return false;
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  void resetStatus() {
    if (mounted) state = state.copyWith(status: PurchaseFlowStatus.idle, errorMessage: null);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>((ref) {
  return PremiumNotifier(ref);
});
