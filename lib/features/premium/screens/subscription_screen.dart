import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/config/theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  bool _isPremium = false;
  List<ProductDetails> _products = [];
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _initializePurchases();
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, redirect to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _isPremium = doc.data()?['isPremium'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error checking premium status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializePurchases() async {
    // Set up the listener for purchase updates
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(_listenToPurchaseUpdated);

    // Check if in-app purchases are available
    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Get product details
    final productIds = <String>{
      AppConstants.monthlyPlanId,
      AppConstants.yearlyPlanId,
    };

    final response = await _inAppPurchase.queryProductDetails(productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    setState(() {
      _products = response.productDetails;
      _isLoading = false;
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show a dialog/indicator that purchase is pending
        setState(() {
          _isLoading = true;
        });
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error: ${purchaseDetails.error?.message ?? "Unknown error"}')),
          );
        }
        setState(() {
          _isLoading = false;
        });
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Grant entitlement to user
        _verifyPurchase(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a real app, you would verify the purchase with your backend
    // For this example, we'll just update the user's premium status in Firestore

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'isPremium': true,
        'subscriptionId': purchaseDetails.productID,
        'purchaseDate': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isPremium = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium subscription activated!')),
        );
      }
    } catch (e) {
      debugPrint('Error updating premium status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to activate premium subscription')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buySubscription(ProductDetails product) {
    final purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Subscription'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium
              ? _buildPremiumContent()
              : _buildSubscriptionOptions(),
    );
  }

  Widget _buildPremiumContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star,
                size: 80,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You are a Premium Member!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Enjoy all premium features including AI-guided workout corrections, custom diet plans, and ad-free experience.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Upgrade to Premium',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock all premium features and take your fitness journey to the next level.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Premium features
          _buildFeaturesList(),
          const SizedBox(height: 32),

          // Subscription plans
          Text(
            'Choose a Plan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Plans
          if (_products.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subscription plans available'),
              ),
            )
          else
            Column(
              children: _products.map((product) {
                final isMonthly = product.id == AppConstants.monthlyPlanId;
                final title = isMonthly ? 'Monthly Premium' : 'Annual Premium';
                final subtitle =
                    isMonthly ? 'Billed monthly' : 'Billed annually (save 20%)';

                return _buildPlanCard(
                  context,
                  title,
                  subtitle,
                  product.price,
                  isMonthly ? Icons.calendar_month : Icons.calendar_today,
                  isMonthly ? Colors.blue : Colors.green,
                  () => _buySubscription(product),
                  isBestValue: !isMonthly,
                );
              }).toList(),
            ),

          // Terms and conditions
          const SizedBox(height: 32),
          Text(
            'By subscribing, you agree to our Terms of Service and Privacy Policy. Subscriptions will automatically renew unless canceled at least 24 hours before the end of the current period.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'title': 'AI-Guided Workout Corrections',
        'description': 'Get real-time feedback on your exercise form',
        'icon': Icons.camera_alt,
      },
      {
        'title': 'Custom Diet Plans',
        'description': 'Personalized nutrition recommendations',
        'icon': Icons.restaurant_menu,
      },
      {
        'title': 'Advanced Analytics',
        'description': 'Detailed insights into your fitness progress',
        'icon': Icons.bar_chart,
      },
      {
        'title': 'Ad-Free Experience',
        'description': 'Enjoy the app without advertisements',
        'icon': Icons.block,
      },
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      feature['description'] as String,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlanCard(BuildContext context, String title, String subtitle,
      String price, IconData icon, Color color, VoidCallback onTap,
      {bool isBestValue = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          subtitle,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Best Value',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    price,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                    ),
                    child: const Text('Subscribe'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
