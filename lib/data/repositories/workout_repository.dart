import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'package:fitflow/data/models/tracking_model.dart';
import 'package:fitflow/data/services/workout_recommendation_service.dart';
import 'package:fitflow/data/services/ai_workout_service_factory.dart';
import 'package:flutter/foundation.dart';

class WorkoutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WorkoutRecommendationService _recommendationService =
      WorkoutRecommendationService();
  final dynamic _aiService;

  WorkoutRepository(String aiApiKey)
      : _aiService = AIWorkoutServiceFactory.createService(
            AIServiceType.huggingface, aiApiKey);

  // Get recommended workouts for user
  Future<List<WorkoutModel>> getRecommendedWorkouts(String userId) {
    return _recommendationService.getRecommendedWorkouts(userId);
  }

  Future<WorkoutModel> generateAIWorkout({
    required int availableMinutes,
    required String location,
    required String fitnessLevel,
  }) async {
    try {
      return await _aiService.generateWorkout(
        availableMinutes: availableMinutes,
        location: location,
        fitnessLevel: fitnessLevel,
      );
    } catch (e) {
      debugPrint('Error generating AI workout: $e');
      throw Exception('Failed to generate workout');
    }
  }

  // Get all available workouts
  Future<List<WorkoutModel>> getAllWorkouts() async {
    try {
      final snapshot = await _firestore.collection('workouts').get();
      return snapshot.docs
          .map((doc) => WorkoutModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting workouts: $e');
      return [];
    }
  }

  // Get workout by ID
  Future<WorkoutModel?> getWorkoutById(String workoutId) async {
    try {
      final doc = await _firestore.collection('workouts').doc(workoutId).get();
      if (!doc.exists) return null;
      return WorkoutModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting workout: $e');
      return null;
    }
  }

  // Record completed workout
  Future<bool> recordWorkoutCompletion(
    String userId,
    WorkoutSession session,
  ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final trackingId = '${userId}_${today.millisecondsSinceEpoch}';

      // Get or create today's tracking document
      final trackingRef = _firestore.collection('tracking').doc(trackingId);
      final trackingDoc = await trackingRef.get();

      if (trackingDoc.exists) {
        final tracking = DailyTrackingModel.fromFirestore(trackingDoc);
        final updated = tracking.addWorkout(session);
        await trackingRef.update(updated.toFirestore());
      } else {
        final newTracking =
            DailyTrackingModel.create(userId).addWorkout(session);
        await trackingRef.set(newTracking.toFirestore());
      }

      // Update user's workout stats
      await _updateUserWorkoutStats(userId, session);

      return true;
    } catch (e) {
      print('Error recording workout completion: $e');
      return false;
    }
  }

  // Update user's workout statistics
  Future<void> _updateUserWorkoutStats(
    String userId,
    WorkoutSession session,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'totalWorkouts': FieldValue.increment(1),
        'totalActiveMinutes':
            FieldValue.increment(session.durationMinutes ?? 0),
        'totalCaloriesBurned':
            FieldValue.increment(session.caloriesBurned ?? 0),
        'lastWorkoutDate':
            Timestamp.fromDate(session.endTime ?? DateTime.now()),
      });
    } catch (e) {
      print('Error updating user workout stats: $e');
    }
  }

  // Get user's workout history
  Future<List<WorkoutSession>> getWorkoutHistory(String userId,
      {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('tracking')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => DailyTrackingModel.fromFirestore(doc))
          .expand((tracking) => tracking.completedWorkouts)
          .toList();
    } catch (e) {
      print('Error getting workout history: $e');
      return [];
    }
  }
}
