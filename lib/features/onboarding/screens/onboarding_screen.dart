import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 4;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to FitFlow',
      'description': 'Your AI-powered fitness companion for busy lifestyles',
      'image': 'assets/images/onboarding_1.png',
      'icon': Icons.fitness_center,
    },
    {
      'title': 'Quick Workouts',
      'description':
          'Short, effective workouts that fit into your busy schedule',
      'image': 'assets/images/onboarding_2.png',
      'icon': Icons.timer,
    },
    {
      'title': 'Posture Detection',
      'description': 'AI-powered posture correction to ensure proper form',
      'image': 'assets/images/onboarding_3.png',
      'icon': Icons.camera_alt,
    },
    {
      'title': 'Track Your Progress',
      'description': 'Monitor your activity, hydration, and fitness journey',
      'image': 'assets/images/onboarding_4.png',
      'icon': Icons.bar_chart,
    },
  ];

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/register');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _numPages,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(index);
                },
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final page = _pages[index];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image or icon placeholder
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page['icon'] as IconData,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 40),
          // Title
          Text(
            page['title'],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            page['description'],
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip button
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Skip',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          // Page indicator
          Row(
            children: List.generate(
              _numPages,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Next button
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: Icon(
              _currentPage < _numPages - 1 ? Icons.arrow_forward : Icons.check,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
