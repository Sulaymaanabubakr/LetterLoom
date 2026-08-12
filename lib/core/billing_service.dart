import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'app_config.dart';
import 'supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchasedHintPack {
  final String productId;
  final String title;
  final String description;
  final String price;
  final String hintType; // 'move', 'letter', 'strong', 'mixed'
  final int count;

  const PurchasedHintPack({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.hintType,
    required this.count,
  });
}

/// In-App Purchase Service for consumable hint packs.
class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _initialized = false;
  bool _purchaseInFlight = false;
  void Function()? _pendingFulfilment;
  void Function(String)? _pendingError;
  Map<String, ProductDetails> _storeProducts = const {};

  Map<String, ProductDetails> get storeProducts => _storeProducts;

  /// Loads live, localised Play prices for the shop. Directly shared APKs are
  /// not Play-entitled, so this safely leaves the fallback labels in place.
  Future<void> refreshStoreProducts() async {
    await initialize();
    if (kIsWeb || !await _iap.isAvailable()) return;
    try {
      final response = await _iap.queryProductDetails(
        availablePacks.map((pack) => pack.productId).toSet(),
      );
      if (response.error == null) {
        _storeProducts = {
          for (final product in response.productDetails) product.id: product,
        };
      }
    } catch (error) {
      debugPrint('[Billing] Product details unavailable: $error');
    }
  }

  static const List<PurchasedHintPack> availablePacks = [
    PurchasedHintPack(
      productId: AppConfig.productMoveHintPack5,
      title: 'Move Hint Pack (5)',
      description: 'Get 5 Word Path Boosts for any match',
      price: '\$0.99',
      hintType: 'move',
      count: 5,
    ),
    PurchasedHintPack(
      productId: AppConfig.productLetterHintPack5,
      title: 'Letter Hint Pack (5)',
      description: 'Get 5 Letter Spark Boosts for any match',
      price: '\$0.99',
      hintType: 'letter',
      count: 5,
    ),
    PurchasedHintPack(
      productId: AppConfig.productStrongHintPack3,
      title: 'Strong Hint Pack (3)',
      description: 'Get 3 Word Weaver Boosts for any match',
      price: '\$1.49',
      hintType: 'strong',
      count: 3,
    ),
    PurchasedHintPack(
      productId: AppConfig.productMixedHintBundle,
      title: 'Mixed Hint Bundle',
      description: 'Get 5 Move, 5 Letter, and 2 Strong Hints',
      price: '\$2.99',
      hintType: 'mixed',
      count: 12,
    ),
  ];

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) =>
          debugPrint('[Billing] Purchase stream error: $error'),
    );
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.error) {
        _pendingError?.call(purchaseErrorMessage(purchase.error?.code));
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        _clearPending();
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased) {
        await _verifyAndFulfil(purchase);
        continue;
      }
      if (purchase.status == PurchaseStatus.restored) {
        // An unfinished consumable can be redelivered after a verification
        // outage. The server ledger is idempotent, so recovery is safe.
        await _verifyAndFulfil(purchase);
      }
    }
  }

  Future<void> _verifyAndFulfil(PurchaseDetails purchase) async {
    if (!SupabaseBootstrap.configured ||
        Supabase.instance.client.auth.currentUser?.isAnonymous != false) {
      _pendingError?.call('Sign in with Google before buying hints.');
      return;
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'billing-verify',
        body: {
          'product_id': purchase.productID,
          'purchase_token': purchase.verificationData.serverVerificationData,
        },
      );
      final data = response.data is Map ? response.data as Map : const {};
      if (data['verified'] != true) {
        _pendingError?.call(
          'Purchase verification failed. No hints were granted.',
        );
        return;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      if (data['fulfilled'] == true) {
        // The server is the source of truth for balances. Notify the UI once
        // only after Play's purchase is verified and fulfilled, then let it
        // refresh the wallet immediately rather than waiting for a relaunch.
        _pendingFulfilment?.call();
      } else {
        _pendingError?.call(
          'This purchase was already processed. Your boost balance is up to date.',
        );
        return;
      }
      _clearPending();
    } catch (error) {
      debugPrint('[Billing] Server verification failed: $error');
      _pendingError?.call('Purchase verification is temporarily unavailable.');
    }
  }

  void _clearPending() {
    _purchaseInFlight = false;
    _pendingFulfilment = null;
    _pendingError = null;
  }

  /// Platform billing messages can include internal response codes, package
  /// names, or account diagnostics. Never send those raw details to the UI.
  @visibleForTesting
  static String purchaseErrorMessage(String? code) {
    final normalized = code?.toLowerCase() ?? '';
    if (normalized.contains('user_canceled') ||
        normalized.contains('cancel') ||
        normalized == '1') {
      return 'Purchase canceled.';
    }
    if (normalized.contains('item_unavailable') || normalized == '4') {
      return 'This boost is not available for this Google Play account yet.';
    }
    if (normalized.contains('billing_unavailable') || normalized == '3') {
      return 'Google Play Billing is unavailable right now. Please try again later.';
    }
    return 'We could not complete that purchase. Please try again.';
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
  }

  /// Executes a verified hint-pack purchase when billing is configured.
  Future<bool> purchasePack(
    PurchasedHintPack pack, {
    required VoidCallback onPurchaseFulfilled,
    required void Function(String error) onError,
  }) async {
    await initialize();
    if (_purchaseInFlight) {
      onError('A purchase is already being processed.');
      return false;
    }
    final available = await _iap.isAvailable();
    if (!available) {
      onError('Google Play Billing is unavailable.');
      return false;
    }
    final response = await _iap.queryProductDetails({pack.productId});
    if (response.error != null || response.productDetails.isEmpty) {
      onError('This hint pack is not configured in the store.');
      return false;
    }
    _purchaseInFlight = true;
    _pendingFulfilment = onPurchaseFulfilled;
    _pendingError = (error) {
      onError(error);
      _clearPending();
    };
    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: response.productDetails.single,
        ),
        autoConsume: false,
      );
      if (!started) {
        onError('Google Play Billing could not start this purchase.');
        _clearPending();
      }
      return started;
    } catch (error) {
      onError('Google Play Billing failed to start.');
      _clearPending();
      return false;
    }
  }

  /// Restore previous purchases (for non-consumable items if added in future).
  Future<void> restorePurchases() async {
    await initialize();
    try {
      await _iap.restorePurchases();
    } catch (error) {
      debugPrint('[Billing] Restore failed: $error');
    }
  }

  /// Replays unfinished Play purchases after startup/authentication. This is
  /// intentionally best-effort: the stream remains the source of truth and
  /// the server ledger prevents duplicate fulfilment.
  Future<void> recoverPendingPurchases({
    VoidCallback? onPurchaseFulfilled,
    void Function(String error)? onError,
  }) async {
    await initialize();
    _pendingFulfilment = onPurchaseFulfilled;
    _pendingError = onError == null
        ? null
        : (error) {
            onError(error);
            _clearPending();
          };
    try {
      await _iap.restorePurchases();
    } catch (error) {
      debugPrint('[Billing] Pending purchase recovery failed: $error');
      _clearPending();
    }
  }
}
