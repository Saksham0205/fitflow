import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionProvider extends ChangeNotifier {
  bool _isPremium = false;
  List<ProductDetails> _products = [];

  bool get isPremium => _isPremium;
  List<ProductDetails> get products => _products;

  Future<void> initializeProducts() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) return;

    const Set<String> _productIds = {
      'premium_monthly',
      'premium_yearly',
    };

    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      // Handle the error
      return;
    }

    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> buySubscription(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void updatePremiumStatus(bool isPremium) {
    _isPremium = isPremium;
    notifyListeners();
  }
}
