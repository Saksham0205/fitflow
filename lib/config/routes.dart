import 'package:flutter/material.dart';
import 'package:fitflow/features/auth/screens/login_screen.dart';
import 'package:fitflow/features/auth/screens/register_screen.dart';
import 'package:fitflow/features/onboarding/screens/onboarding_screen.dart';
import 'package:fitflow/features/onboarding/screens/splash_screen.dart';
import 'package:fitflow/features/profile/screens/profile_screen.dart';
import 'package:fitflow/features/workouts/screens/workout_list_screen.dart';
import 'package:fitflow/features/workouts/screens/workout_detail_screen.dart';
import 'package:fitflow/features/posture/screens/posture_detection_screen.dart';
import 'package:fitflow/features/tracking/screens/tracking_dashboard_screen.dart';
import 'package:fitflow/features/social/screens/challenges_screen.dart';
import 'package:fitflow/features/premium/screens/subscription_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/onboarding':
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case '/workouts':
        return MaterialPageRoute(builder: (_) => const WorkoutListScreen());
      case '/workout-detail':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(workoutId: args['workoutId']),
        );
      case '/posture':
        return MaterialPageRoute(
            builder: (_) => const PostureDetectionScreen());
      case '/tracking':
        return MaterialPageRoute(
            builder: (_) => const TrackingDashboardScreen());
      case '/challenges':
        return MaterialPageRoute(builder: (_) => const ChallengesScreen());
      case '/subscription':
        return MaterialPageRoute(builder: (_) => const SubscriptionScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
