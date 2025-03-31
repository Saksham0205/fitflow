class AppConstants {
  // App Information
  static const String appName = 'FitFlow';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String workoutsCollection = 'workouts';
  static const String challengesCollection = 'challenges';
  static const String trackingCollection = 'tracking';

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userProfileKey = 'user_profile';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String darkModeKey = 'dark_mode';

  // Feature Flags
  static const bool enablePoseDetection = true;
  static const bool enableSocialFeatures = true;
  static const bool enableInAppPurchases = true;

  // Workout Constants
  static const int defaultWorkoutDuration = 20; // in minutes
  static const int microWorkoutDuration = 5; // in minutes
  static const int waterReminderInterval = 60; // in minutes

  // Subscription Plans
  static const String freePlanId = 'free_plan';
  static const String monthlyPlanId = 'monthly_premium';
  static const String yearlyPlanId = 'yearly_premium';

  // API Endpoints
  static const String baseApiUrl = 'https://api.fitflow.example.com';

  // Animation Assets
  static const String splashAnimation = 'assets/animations/splash.json';
  static const String workoutAnimation = 'assets/animations/workout.json';
  static const String achievementAnimation =
      'assets/animations/achievement.json';
}
