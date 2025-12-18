import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'iap_constants.dart';

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  Set<String> ownedProductIds = {};

  Future<void> initialize() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;

    final ProductDetailsResponse response =
    await _iap.queryProductDetails(kAllProductIds);

    // We don’t use ProductDetails yet — only ownership
    final Stream<List<PurchaseDetails>> purchaseStream =
        _iap.purchaseStream;

    purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          ownedProductIds.add(purchase.productID);
        }
      }
    });
  }

  bool owns(String productId) {
    return ownedProductIds.contains(productId);
  }
}
