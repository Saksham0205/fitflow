import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/data/models/user_model.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'package:fitflow/data/models/tracking_model.dart';

class WorkoutRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // Apply recommendation rules
      final recommendations = _applyRecommendationRules(
        allWorkouts,
        user,
        completedWorkoutIds,
        trackingHistory,
      );

      return recommendations;
    } catch (e) {
      print('Error getting workout recommendations: $e');
      return [];
    }
  }

  List<WorkoutModel> _applyRecommendationRules(
    List<WorkoutModel> allWorkouts,
    UserModel user,
    Set<String> completedWorkoutIds,
    List<DailyTrackingModel> trackingHistory,
  ) {
    // Calculate user's activity level
    final avgActiveMinutes = trackingHistory.isEmpty
        ? 0
        : trackingHistory
                .map((day) => day.activeMinutes)
                .reduce((a, b) => a + b) /
            trackingHistory.length;

    // Filter workouts based on user's fitness level
    var recommendations = allWorkouts.where((workout) {
      if (user.fitnessLevel == FitnessLevel.beginner) {
        return workout.difficulty == 'beginner';
      } else if (user.fitnessLevel == FitnessLevel.intermediate) {
        return workout.difficulty != 'advanced';
      }
      return true; // For advanced users, show all workouts
    }).toList();

    // Prioritize workouts based on user preferences
    recommendations.sort((a, b) {
      var aScore = _calculateWorkoutScore(a, user, avgActiveMinutes.toDouble());
      var bScore = _calculateWorkoutScore(b, user, avgActiveMinutes.toDouble());
      return bScore.compareTo(aScore);
    });

    // Ensure variety by including some workouts not yet completed
    var newWorkouts = recommendations
        .where((w) => !completedWorkoutIds.contains(w.id))
        .take(3)
        .toList();

    // Mix new workouts with successful ones from history
    var finalRecommendations = [...newWorkouts];

    // Add some workouts that the user has successfully completed
    var successfulWorkouts = recommendations
        .where((w) => completedWorkoutIds.contains(w.id))
        .take(2)
        .toList();

    finalRecommendations.addAll(successfulWorkouts);

    return finalRecommendations;
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
