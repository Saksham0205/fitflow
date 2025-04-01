import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/data/models/user_model.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'package:fitflow/data/models/tracking_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class WorkoutRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GenerativeModel _model;

  WorkoutRecommendationService() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    );
  }

  // Get personalized workout recommendations for a user
  Future<List<WorkoutModel>> getRecommendedWorkouts(String userId) async {
    try {
      // Get user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');

      final user = UserModel.fromFirestore(userDoc);

      // Get user's workout history (last 30 days)
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final trackingDocs = await _firestore
          .collection('tracking')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();

      final trackingHistory = trackingDocs.docs
          .map((doc) => DailyTrackingModel.fromFirestore(doc))
          .toList();

      // Analyze workout history
      final completedWorkoutIds = trackingHistory
          .expand((day) => day.completedWorkouts)
          .map((session) => session.workoutId)
          .toSet();

      // Get all available workouts
      final workoutDocs = await _firestore.collection('workouts').get();
      final allWorkouts = workoutDocs.docs
          .map((doc) => WorkoutModel.fromFirestore(doc))
          .toList();

      // Apply AI-powered recommendation rules
      final recommendations = await _generateAIRecommendations(
        allWorkouts,
        user,
        completedWorkoutIds,
        trackingHistory,
      );

      return recommendations;
    } catch (e) {
      print('Error getting recommended workouts: $e');
      return [];
    }
  }

  Future<List<WorkoutModel>> _generateAIRecommendations(
    List<WorkoutModel> allWorkouts,
    UserModel user,
    Set<String> completedWorkoutIds,
    List<DailyTrackingModel> trackingHistory,
  ) async {
    try {
      // Generate prompt for AI recommendation
      final prompt = _generateRecommendationPrompt(
        user: user,
        completedWorkouts: completedWorkoutIds.length,
        trackingHistory: trackingHistory,
      );

      final content = await _model.generateContent([Content.text(prompt)]);
      final response = content.text;

      // Parse AI response and match with available workouts
      return _matchWorkoutsWithAIRecommendations(
          allWorkouts, response ?? '', user);
    } catch (e) {
      print('Error generating AI recommendations: $e');
      return _fallbackRecommendations(allWorkouts, user);
    }
  }

  String _generateRecommendationPrompt({
    required UserModel user,
    required int completedWorkouts,
    required List<DailyTrackingModel> trackingHistory,
  }) {
    final recentWorkouts = trackingHistory
        .expand((day) => day.completedWorkouts)
        .take(5)
        .map((session) => session.workoutId)
        .toList();

    return '''
    Generate personalized workout recommendations based on the following user profile:

    Fitness Level: ${user.fitnessLevel}
    Preferred Workout Types: ${user.preferredWorkoutTypes.join(', ')}
    Available Days: ${user.schedule.entries.where((e) => e.value).map((e) => e.key).join(', ')}
    Completed Workouts: $completedWorkouts
    Recent Workout IDs: ${recentWorkouts.join(', ')}

    Please recommend workouts that:
    1. Match the user's fitness level
    2. Align with preferred workout types
    3. Can be done in available time slots
    4. Provide proper progression
    5. Consider location constraints (office, home, etc.)
    ''';
  }

  List<WorkoutModel> _matchWorkoutsWithAIRecommendations(
    List<WorkoutModel> allWorkouts,
    String aiResponse,
    UserModel user,
  ) {
    // Filter workouts based on AI recommendations and user preferences
    final recommendations = allWorkouts.where((workout) {
      // Match workout type with user preferences
      final typeMatch = user.preferredWorkoutTypes.contains(workout.type);

      // Match difficulty level
      final levelMatch =
          _isAppropriateLevel(workout, user.fitnessLevel.toString());

      // Consider location constraints
      final locationMatch = workout.type == WorkoutType.officeFriendly
          ? user.schedule.containsValue(true) // Has available office time
          : true; // Non-office workouts are always location-compatible

      return typeMatch && levelMatch && locationMatch;
    }).toList();

    // Sort recommendations by relevance
    recommendations.sort((a, b) {
      // Prioritize office-friendly workouts during work hours
      if (a.type == WorkoutType.officeFriendly &&
          b.type != WorkoutType.officeFriendly) {
        return -1;
      }
      if (b.type == WorkoutType.officeFriendly &&
          a.type != WorkoutType.officeFriendly) {
        return 1;
      }

      // Then sort by match with user's fitness level
      final aLevel = int.parse(a.difficulty);
      final bLevel = int.parse(b.difficulty);
      final userLevelNum = int.parse(user.fitnessLevel.toString());

      return (aLevel - userLevelNum)
          .abs()
          .compareTo((bLevel - userLevelNum).abs());
    });

    // Return top recommendations
    return recommendations.take(5).toList();
  }

  bool _isAppropriateLevel(WorkoutModel workout, String userLevel) {
    final userLevelNum = int.parse(userLevel);
    final workoutLevel =
        int.parse(workout.difficulty); // Convert to int before subtracting

    // Allow workouts within +/- 1 of user's level
    return (workoutLevel - userLevelNum).abs() <= 1;
  }

  List<WorkoutModel> _fallbackRecommendations(
    List<WorkoutModel> allWorkouts,
    UserModel user,
  ) {
    // Simple fallback logic when AI recommendations fail
    return allWorkouts
        .where((w) => user.preferredWorkoutTypes.contains(w.type))
        .take(5)
        .toList();
  }

  double _calculateWorkoutScore(
      WorkoutModel workout, UserModel user, double avgActiveMinutes) {
    double score = 0;

    // Preferred workout type bonus
    if (user.preferredWorkoutTypes
        .contains(workout.type.toString().split('.').last)) {
      score += 5;
    }

    // Duration match based on average activity
    final durationDiff = (workout.durationMinutes - avgActiveMinutes).abs();
    if (durationDiff <= 10) {
      score += 3;
    } else if (durationDiff <= 20) {
      score += 1;
    }

    // Difficulty progression
    if (user.fitnessLevel == FitnessLevel.beginner &&
        workout.difficulty == 'beginner') {
      score += 2;
    } else if (user.fitnessLevel == FitnessLevel.intermediate) {
      if (workout.difficulty == 'intermediate') score += 2;
      if (workout.difficulty == 'beginner') score += 1;
    } else if (user.fitnessLevel == FitnessLevel.advanced &&
        workout.difficulty == 'advanced') {
      score += 2;
    }

    return score;
  }
}
