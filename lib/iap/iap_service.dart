import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'iap_constants.dart';

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Set<String> ownedProductIds = {};
  bool isInitialized = false;

  Future<void> initialize() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;

    final Stream<List<PurchaseDetails>> purchaseStream = _iap.purchaseStream;
    _subscription = purchaseStream.listen((purchases) {
      _handlePurchaseUpdates(purchases);
    }, onError: (error) {
      // Handle error
    });

    // Query for existing purchases to restore state
    await _iap.restorePurchases();
    
    // Also query product details to ensure they exist in the store
    await _iap.queryProductDetails(kAllProductIds);
    
    isInitialized = true;
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        ownedProductIds.add(purchase.productID);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  bool owns(String productId) {
    return ownedProductIds.contains(productId);
  }

  Future<void> buy(String productId) async {
    final ProductDetailsResponse response =
        await _iap.queryProductDetails({productId});

    if (response.productDetails.isEmpty) return;

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    if (productId == kSupportProject) {
      // If you want support to be repeatable, use buyConsumable
      // For now, keeping as non-consumable per your original code but completing it.
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
