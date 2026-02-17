import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ad_service.dart';
import 'storage_service.dart';
import 'power_up_service.dart';

/// Handles in-app purchases and entitlements.
class IapService extends ChangeNotifier {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  static const String removeAdsProductId = 'com.go7studio.stakd.remove_ads';
  static const String hintPack10ProductId = 'com.go7studio.stakd.hint_pack_10';
  static const int hintPackAmount = 10;

  // Power-up pack product IDs
  static const String powerUpPack5ProductId = 'com.go7studio.stakd.powerup_pack_5';
  static const String powerUpPack20ProductId = 'com.go7studio.stakd.powerup_pack_20';
  static const String powerUpPack50ProductId = 'com.go7studio.stakd.powerup_pack_50';
  static const int powerUpPack5Amount = 5;
  static const int powerUpPack20Amount = 20;
  static const int powerUpPack50Amount = 50;

  // Flip with --dart-define=STAKD_IAP_TEST_IDS=true for store test IDs.
  static const bool useTestProductIds = bool.fromEnvironment(
    'STAKD_IAP_TEST_IDS',
    defaultValue: false,
  );

  static const Set<String> _productIds = {
    removeAdsProductId,
    hintPack10ProductId,
    powerUpPack5ProductId,
    powerUpPack20ProductId,
    powerUpPack50ProductId,
  };

  // Google Play test SKU. Use StoreKit config on iOS.
  static const Set<String> _testProductIds = {'android.test.purchased'};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _initialized = false;
  bool _isAvailable = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingProductId;

  bool _adsRemoved = false;
  int _hintCount = 0;

  final Map<String, ProductDetails> _products = {};

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get adsRemoved => _adsRemoved;
  int get hintCount => _hintCount;

  String? get removeAdsPrice => _productFor(removeAdsProductId)?.price;
  String? get hintPackPrice => _productFor(hintPack10ProductId)?.price;
  String? get powerUpPack5Price => _productFor(powerUpPack5ProductId)?.price;
  String? get powerUpPack20Price => _productFor(powerUpPack20ProductId)?.price;
  String? get powerUpPack50Price => _productFor(powerUpPack50ProductId)?.price;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _loadLocalEntitlements();

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      _errorMessage = 'In-app purchases are unavailable.';
      notifyListeners();
      return;
    }

    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {
        _setError('Purchase stream error: $error');
      },
    );

    await _queryProducts();
  }

  void _loadLocalEntitlements() {
    final storage = StorageService();
    _adsRemoved = storage.getAdsRemoved();
    _hintCount = storage.getHintCount();
  }

  Future<void> _queryProducts() async {
    _setLoading(true);
    _errorMessage = null;

    final ids = useTestProductIds ? _testProductIds : _productIds;
    final response = await _iap.queryProductDetails(ids);

    _products
      ..clear()
      ..addEntries(
        response.productDetails.map((product) => MapEntry(product.id, product)),
      );

    if (response.error != null) {
      _errorMessage = response.error!.message;
    }

    if (_products.isEmpty) {
      _errorMessage ??= 'No products returned from the store.';
    }

    _setLoading(false);
  }

  ProductDetails? _productFor(String productId) {
    if (useTestProductIds) {
      return _products.values.isEmpty ? null : _products.values.first;
    }
    return _products[productId];
  }

  Future<void> buyRemoveAds() async {
    await _buyProduct(removeAdsProductId, isConsumable: false);
  }

  Future<void> buyHintPack() async {
    await _buyProduct(hintPack10ProductId, isConsumable: true);
  }

  Future<void> buyPowerUpPack5() async {
    await _buyProduct(powerUpPack5ProductId, isConsumable: true);
  }

  Future<void> buyPowerUpPack20() async {
    await _buyProduct(powerUpPack20ProductId, isConsumable: true);
  }

  Future<void> buyPowerUpPack50() async {
    await _buyProduct(powerUpPack50ProductId, isConsumable: true);
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      _setError('Store is unavailable.');
      return;
    }
    _setLoading(true);
    await _iap.restorePurchases();
  }

  bool consumeHint() {
    if (_hintCount <= 0) return false;
    _hintCount -= 1;
    StorageService().setHintCount(_hintCount);
    notifyListeners();
    return true;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _buyProduct(
    String productId, {
    required bool isConsumable,
  }) async {
    if (!_isAvailable) {
      _setError('Store is unavailable.');
      return;
    }

    final product = _productFor(productId);
    if (product == null) {
      _setError('Product not available.');
      return;
    }

    _pendingProductId = productId;
    _setLoading(true);

    final purchaseParam = PurchaseParam(productDetails: product);

    if (isConsumable) {
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    bool hasPending = false;

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          hasPending = true;
          break;
        case PurchaseStatus.error:
          _setError(purchase.error?.message ?? 'Purchase failed.');
          break;
        case PurchaseStatus.canceled:
          // User canceled the purchase flow; no action needed.
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _deliverPurchase(purchase);
          } else {
            _setError('Purchase verification failed.');
          }
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    _setLoading(hasPending);
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // TODO: Replace with server-side receipt validation.
    if (useTestProductIds) {
      return _testProductIds.contains(purchase.productID);
    }
    return _productIds.contains(purchase.productID);
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final storage = StorageService();
    final powerUpService = PowerUpService();
    var productId = purchase.productID;

    if (useTestProductIds && _testProductIds.contains(productId)) {
      productId = _pendingProductId ?? removeAdsProductId;
    }

    if (productId == removeAdsProductId) {
      if (!_adsRemoved) {
        _adsRemoved = true;
        await storage.setAdsRemoved(true);
        AdService().dispose();
      }
    } else if (productId == hintPack10ProductId) {
      _hintCount += hintPackAmount;
      await storage.setHintCount(_hintCount);
    } else if (productId == powerUpPack5ProductId) {
      await powerUpService.awardPack(powerUpPack5Amount);
    } else if (productId == powerUpPack20ProductId) {
      await powerUpService.awardPack(powerUpPack20Amount);
    } else if (productId == powerUpPack50ProductId) {
      await powerUpService.awardPack(powerUpPack50Amount);
    }

    _pendingProductId = null;
    notifyListeners();
  }

  void _setLoading(bool isLoading) {
    if (_isLoading == isLoading) return;
    _isLoading = isLoading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Cancel purchase stream subscription
  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    super.dispose();
  }
}
