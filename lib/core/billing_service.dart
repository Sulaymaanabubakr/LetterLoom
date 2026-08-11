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
  void Function(String, int)? _pendingFulfilment;
  void Function(String)? _pendingError;

  static const List<PurchasedHintPack> availablePacks = [
    PurchasedHintPack(
      productId: AppConfig.productMoveHintPack5,
      title: 'Move Hint Pack (5)',
      description: 'Get 5 Move Hints for any solo match',
      price: '\$0.99',
      hintType: 'move',
      count: 5,
    ),
    PurchasedHintPack(
      productId: AppConfig.productLetterHintPack5,
      title: 'Letter Hint Pack (5)',
      description: 'Get 5 Letter Hints for any solo match',
      price: '\$0.99',
      hintType: 'letter',
      count: 5,
    ),
    PurchasedHintPack(
      productId: AppConfig.productStrongHintPack3,
      title: 'Strong Hint Pack (3)',
      description: 'Get 3 Strong Hints for any solo match',
      price: '\$1.99',
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
        _pendingError?.call(purchase.error?.message ?? 'Purchase failed.');
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
        // These products are consumable. Restored consumables must never be
        // granted from the platform stream; the server ledger is authoritative.
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
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
        final move = (data['move'] as num?)?.toInt() ?? 0;
        final letter = (data['letter'] as num?)?.toInt() ?? 0;
        final strong = (data['strong'] as num?)?.toInt() ?? 0;
        if (move > 0) _pendingFulfilment?.call('move', move);
        if (letter > 0) _pendingFulfilment?.call('letter', letter);
        if (strong > 0) _pendingFulfilment?.call('strong', strong);
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

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
  }

  /// Executes a verified hint-pack purchase when billing is configured.
  Future<bool> purchasePack(
    PurchasedHintPack pack, {
    required void Function(String hintType, int amount) onPurchaseFulfilled,
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
}
