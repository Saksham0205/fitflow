import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:fitflow/app.dart';
import 'package:fitflow/features/auth/providers/auth_provider.dart';
import 'package:fitflow/features/premium/providers/subscription_provider.dart';
import 'package:fitflow/features/tracking/providers/fitness_tracking_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Configure Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Run app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => FitnessTrackingProvider()),
      ],
      child: const FitFlowApp(),
    ),
  );
}
