import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitflow/config/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkFirstTime();
      }
    });

    _animationController.forward();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool(AppConstants.onboardingCompleteKey) ?? false;

    if (mounted) {
      if (onboardingComplete) {
        // Check if user is logged in
        final String? userToken = prefs.getString(AppConstants.userTokenKey);
        if (userToken != null && userToken.isNotEmpty) {
          Navigator.of(context).pushReplacementNamed('/tracking');
        } else {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animation
            Lottie.asset(
              AppConstants.splashAnimation,
              controller: _animationController,
              height: 200,
              width: 200,
              animate: true,
              // If animation file doesn't exist yet, use a placeholder
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.fitness_center,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // App name
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            // Tagline
            Text(
              'AI-Powered Fitness & Wellness',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
