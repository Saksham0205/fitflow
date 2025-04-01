import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class WorkoutProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GenerativeModel _model;

  WorkoutProgressService() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    );
  }

  Future<void> saveWorkoutProgress({
    required String userId,
    required WorkoutModel workout,
    required Map<String, dynamic> trackingStats,
  }) async {
    try {
      await _firestore.collection('workout_progress').add({
        'userId': userId,
        'workoutId': workout.id,
        'workoutType': workout.type.toString(),
        'completedAt': DateTime.now().toIso8601String(),
        'duration': trackingStats['duration'],
        'caloriesBurned': trackingStats['caloriesBurned'],
        'intensity': trackingStats['intensity'],
        'location':
            workout.type == WorkoutType.officeFriendly ? 'Office' : 'Other',
        'environmentFactors': trackingStats['environmentFactors'] ?? {},
        'performanceMetrics': trackingStats['performanceMetrics'] ?? {},
      });
    } catch (e) {
      print('Error saving workout progress: $e');
      throw Exception('Failed to save workout progress');
    }
  }

  Future<Map<String, dynamic>> getWorkoutStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('workout_progress')
          .where('userId', isEqualTo: userId)
          .orderBy('completedAt', descending: true)
          .limit(30)
          .get();

      int totalWorkouts = snapshot.docs.length;
      int totalMinutes = 0;
      int totalCalories = 0;
      Map<String, int> workoutTypeCount = {};
      Map<String, int> locationCount = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Another approach:
        totalMinutes += (data['duration'] as num? ?? 0).toInt() ~/ 60;
        totalCalories += (data['caloriesBurned'] as num? ?? 0).toInt();
        final workoutType = data['workoutType'] ?? '';
        final location = data['location'] ?? 'Other';

        workoutTypeCount[workoutType] =
            (workoutTypeCount[workoutType] ?? 0) + 1;
        locationCount[location] = (locationCount[location] ?? 0) + 1;
      }

      return {
        'totalWorkouts': totalWorkouts,
        'totalMinutes': totalMinutes,
        'totalCalories': totalCalories,
        'workoutTypes': workoutTypeCount,
        'locations': locationCount,
        'lastWorkout':
            snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null,
      };
    } catch (e) {
      print('Error getting workout stats: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getWeeklyProgress(String userId) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('workout_progress')
          .where('userId', isEqualTo: userId)
          .where('completedAt',
              isGreaterThanOrEqualTo: weekAgo.toIso8601String())
          .orderBy('completedAt')
          .get();

      Map<String, Map<String, dynamic>> dailyStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date =
            DateTime.parse(data['completedAt']).toIso8601String().split('T')[0];

        if (!dailyStats.containsKey(date)) {
          dailyStats[date] = {
            'date': date,
            'workouts': 0,
            'minutes': 0,
            'calories': 0,
            'locations': <String, int>{},
          };
        }

        dailyStats[date]?['workouts'] =
            (dailyStats[date]?['workouts'] ?? 0) + 1;
        dailyStats[date]?['minutes'] =
            (dailyStats[date]?['minutes'] ?? 0) + (data['duration'] ?? 0) ~/ 60;
        dailyStats[date]?['calories'] = (dailyStats[date]?['calories'] ?? 0) +
            (data['caloriesBurned'] ?? 0);

        final location = data['location'] ?? 'Other';
        final locationStats =
            dailyStats[date]?['locations'] as Map<String, int>;
        locationStats[location] = (locationStats[location] ?? 0) + 1;
      }

      return dailyStats.values.toList();
    } catch (e) {
      print('Error getting weekly progress: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAIWorkoutInsights(String userId) async {
    try {
      final stats = await getWorkoutStats(userId);
      final weeklyProgress = await getWeeklyProgress(userId);

      final prompt = _generateInsightsPrompt(stats, weeklyProgress);
      final content = await _model.generateContent([Content.text(prompt)]);
      final response = content.text;

      return {
        'insights': response,
        'stats': stats,
        'weeklyProgress': weeklyProgress,
      };
    } catch (e) {
      print('Error generating AI insights: $e');
      return {
        'insights': 'Unable to generate insights at this time.',
        'error': e.toString(),
      };
    }
  }

  String _generateInsightsPrompt(
      Map<String, dynamic> stats, List<Map<String, dynamic>> weeklyProgress) {
    return '''
    Analyze the following workout data and provide personalized insights and recommendations:

    Overall Stats:
    - Total Workouts: ${stats['totalWorkouts']}
    - Total Minutes: ${stats['totalMinutes']}
    - Total Calories: ${stats['totalCalories']}
    - Workout Types: ${stats['workoutTypes']}
    - Locations: ${stats['locations']}

    Weekly Progress:
    ${weeklyProgress.map((day) => '${day['date']}: ${day['workouts']} workouts, ${day['minutes']} minutes').join('\n')}

    Please provide:
    1. Pattern analysis of workout frequency and intensity
    2. Location-based workout effectiveness
    3. Suggestions for improvement
    4. Personalized recommendations for next workouts
    ''';
  }

  Future<Map<String, dynamic>> generateAdaptiveWorkout({
    required String userId,
    required String location,
    required int availableMinutes,
    required String fitnessLevel,
  }) async {
    try {
      final stats = await getWorkoutStats(userId);
      final prompt = _generateWorkoutPrompt(
        location: location,
        availableMinutes: availableMinutes,
        fitnessLevel: fitnessLevel,
        stats: stats,
      );

      final content = await _model.generateContent([Content.text(prompt)]);
      final response = content.text;

      return {
        'workout': response,
        'location': location,
        'duration': availableMinutes,
        'fitnessLevel': fitnessLevel,
      };
    } catch (e) {
      print('Error generating adaptive workout: $e');
      return {
        'error': 'Unable to generate workout at this time.',
        'details': e.toString(),
      };
    }
  }

  String _generateWorkoutPrompt({
    required String location,
    required int availableMinutes,
    required String fitnessLevel,
    required Map<String, dynamic> stats,
  }) {
    return '''
    Generate a personalized workout routine with the following parameters:

    Location: $location
    Available Time: $availableMinutes minutes
    Fitness Level: $fitnessLevel

    User's Workout History:
    - Total Workouts: ${stats['totalWorkouts']}
    - Preferred Locations: ${stats['locations']}
    - Common Workout Types: ${stats['workoutTypes']}

    Please provide:
    1. Warm-up exercises (2-3 minutes)
    2. Main workout routine optimized for the location and time
    3. Cool-down exercises (2-3 minutes)
    4. Intensity levels and modifications
    5. Equipment needed (if any)
    ''';
  }
}
