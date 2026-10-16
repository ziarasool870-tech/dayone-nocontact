/// Real Google Play Billing for Day One Pro via `in_app_purchase`.
///
/// Product IDs live in [billing_products.dart] and MUST match Play Console.
/// Play Console registration (needs the user's $25 developer account) is the
/// only step that cannot be done in code.
///
/// Purchase verification note (v1): verification is CLIENT-SIDE only —
/// we trust the Play Billing purchase callback. Server-side verification
/// (Play Developer API purchase token check) requires a backend and is
/// deferred to v1.1+. For a v1 launch this is the standard approach.
///
/// States handled: available/unavailable store, product query, purchase,
/// pending (e.g. cash payment), user-cancelled, errors, restore.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../billing/billing_products.dart';
import '../data/prefs.dart';

/// UI-facing billing state.
class BillingUiState {
  const BillingUiState({
    this.storeAvailable = false,
    this.products = const [],
    this.isPro = false,
    this.pendingProductId,
    this.lastError,
    this.restoring = false,
  });

  final bool storeAvailable;
  final List<ProductDetails> products;
  final bool isPro;
  final String? pendingProductId;
  final String? lastError;
  final bool restoring;

  BillingUiState copyWith({
    bool? storeAvailable,
    List<ProductDetails>? products,
    bool? isPro,
    String? pendingProductId,
    String? lastError,
    bool? restoring,
    bool clearPending = false,
    bool clearError = false,
  }) =>
      BillingUiState(
        storeAvailable: storeAvailable ?? this.storeAvailable,
        products: products ?? this.products,
        isPro: isPro ?? this.isPro,
        pendingProductId:
            clearPending ? null : (pendingProductId ?? this.pendingProductId),
        lastError: clearError ? null : (lastError ?? this.lastError),
        restoring: restoring ?? this.restoring,
      );
}

class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final ValueNotifier<BillingUiState> uiState =
      ValueNotifier(const BillingUiState());

  bool _initialized = false;

  /// Must be called once at app start (after PrefsService is ready).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await PrefsService.instance();
    uiState.value = uiState.value.copyWith(isPro: prefs.isPro);

    // TEST ONLY — never enable in release builds. Force-unlocks Pro for the
    // owner's PROTEST build, compiled with --dart-define=PRO_UNLOCKED=true.
    // The Play Billing flow is untouched; this flag is off by default.
    if (const bool.fromEnvironment('PRO_UNLOCKED')) {
      await prefs.setPro(true);
      uiState.value = uiState.value.copyWith(isPro: true);
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _setError('Billing error: $e'),
    );

    final available = await _iap.isAvailable();
    if (!available) {
      _setError(
          'Google Play Billing is not available on this device. Pro purchases need the Play Store version of the app.');
      return;
    }
    uiState.value = uiState.value.copyWith(storeAvailable: true);

    final response = await _iap.queryProductDetails(kProProductIds);
    if (response.error != null) {
      _setError(
          'Could not load Pro products: ${response.error!.message}. Check that the product IDs exist in Play Console.');
      return;
    }
    if (response.productDetails.isEmpty) {
      _setError(
          'No Pro products found. The product IDs are not registered in Play Console yet.');
      return;
    }
    uiState.value = uiState.value.copyWith(products: response.productDetails);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Re-attempts the store-availability + product query after a
  /// transient failure (the paywall's "Try again" button). Safe to call
  /// any time; it just refreshes [uiState].
  Future<void> retryLoadingProducts() async {
    _clearError();
    final available = await _iap.isAvailable();
    if (!available) {
      _setError(
          'Google Play Billing is not available on this device. Pro purchases need the Play Store version of the app.');
      return;
    }
    uiState.value = uiState.value.copyWith(storeAvailable: true);

    final response = await _iap.queryProductDetails(kProProductIds);
    if (response.error != null) {
      _setError(
          'Could not load Pro products: ${response.error!.message}. Check that the product IDs exist in Play Console.');
      return;
    }
    if (response.productDetails.isEmpty) {
      _setError(
          'No Pro products found. The product IDs are not registered in Play Console yet.');
      return;
    }
    uiState.value = uiState.value.copyWith(products: response.productDetails);
  }

  /// Starts the purchase flow for [productId].
  Future<void> buy(String productId) async {
    _clearError();
    final product =
        uiState.value.products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      _setError(
          'Product "$productId" is not available. It may not be registered in Play Console yet.');
      return;
    }
    // buyNonConsumable covers both one-time products and subscriptions
    // on Google Play in in_app_purchase 3.x.
    final ok = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!ok) {
      _setError('Could not start the purchase. Please try again.');
    }
    // The result arrives asynchronously on purchaseStream.
  }

  /// Re-queries past purchases (e.g. user reinstalled or switched devices).
  /// Restored entitlements arrive on the purchase stream.
  Future<void> restorePurchases() async {
    _clearError();
    uiState.value = uiState.value.copyWith(restoring: true);
    try {
      await _iap.restorePurchases();
      // Results arrive on purchaseStream with status `restored`.
      // Give the stream a moment, then clear the spinner if nothing came.
      await Future<void>.delayed(const Duration(seconds: 4));
    } finally {
      if (uiState.value.restoring) {
        uiState.value = uiState.value.copyWith(restoring: false);
      }
    }
  }

  // ------------------------------------------------------------- internals

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      await _handlePurchase(p);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails p) async {
    switch (p.status) {
      case PurchaseStatus.pending:
        uiState.value = uiState.value
            .copyWith(pendingProductId: p.productID, clearError: true);
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final granted = await _grantPro(p);
        if (granted && p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        uiState.value = uiState.value.copyWith(
          clearPending: true,
          clearError: true,
          restoring: false,
        );
        break;

      case PurchaseStatus.error:
        final msg = p.error?.message ?? 'Unknown billing error';
        final code = p.error?.code ?? '';
        if (code == 'userCancelled' || msg.toLowerCase().contains('cancel')) {
          // Gentle UX: cancelling is not an error worth alarming about.
          uiState.value = uiState.value.copyWith(
              clearPending: true,
              lastError: 'Purchase cancelled — no charge was made.');
        } else {
          _setError('Purchase failed: $msg');
          uiState.value = uiState.value.copyWith(clearPending: true);
        }
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        break;

      case PurchaseStatus.canceled:
        uiState.value = uiState.value.copyWith(
          clearPending: true,
          lastError: 'Purchase cancelled — no charge was made.',
        );
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        break;
    }
  }

  /// Grants Pro for a purchased/restored product.
  /// Returns true when the entitlement was accepted.
  ///
  /// v1 verification: client-side only. We accept the Play Billing callback
  /// for [productID]s we know. Server-side token verification is deferred
  /// to v1.1+ (needs a backend).
  Future<bool> _grantPro(PurchaseDetails p) async {
    if (!kProProductIds.contains(p.productID)) {
      _setError('Unknown product "${p.productID}" — not granted.');
      return false;
    }
    final prefs = await PrefsService.instance();
    await prefs.setPro(true, productId: p.productID);
    uiState.value = uiState.value.copyWith(isPro: true);
    return true;
  }

  /// Local-only revoke (used in tests / account flows). Real subscription
  /// cancellation happens in the Play Store, not here.
  Future<void> revokeLocalProForTesting() async {
    final prefs = await PrefsService.instance();
    await prefs.setPro(false);
    uiState.value = uiState.value.copyWith(isPro: false);
  }

  void _setError(String message) {
    uiState.value = uiState.value
        .copyWith(lastError: message, restoring: false, clearPending: true);
  }

  void _clearError() {
    uiState.value = uiState.value.copyWith(clearError: true);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
