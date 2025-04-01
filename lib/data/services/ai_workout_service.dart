import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fitflow/data/models/workout_model.dart';

class AIWorkoutService {
  final GenerativeModel _model;

  AIWorkoutService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: 'AIzaSyBGC1rU_dAWrDE5yTZgzyJWbCQfCf1tplU',
        );

  Future<WorkoutModel> generateWorkout({
    required int availableMinutes,
    required String location,
    required String fitnessLevel,
  }) async {
    try {
      final prompt = _buildWorkoutPrompt(
        availableMinutes: availableMinutes,
        location: location,
        fitnessLevel: fitnessLevel,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final workoutData = _parseAIResponse(response.text ?? '');

      return WorkoutModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: workoutData['title'],
        description: workoutData['description'],
        type: _getWorkoutType(location),
        difficulty: fitnessLevel.toLowerCase(),
        durationMinutes: availableMinutes,
        exercises: _createExercises(workoutData['exercises']),
        caloriesBurn: workoutData['caloriesBurn'] ?? 150,
        targetMuscles: List<String>.from(workoutData['targetMuscles'] ?? []),
        tags: [
          'ai-generated',
          location.toLowerCase(),
          fitnessLevel.toLowerCase()
        ],
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to generate workout: $e');
    }
  }

  String _buildWorkoutPrompt({
    required int availableMinutes,
    required String location,
    required String fitnessLevel,
  }) {
    return '''
    Generate a personalized workout plan with the following specifications:
    - Duration: $availableMinutes minutes
    - Location: $location
    - Fitness Level: $fitnessLevel

    Please provide the workout in the following JSON format:
    {
      "title": "Workout title",
      "description": "Brief description",
      "exercises": [
        {
          "name": "Exercise name",
          "description": "Exercise description",
          "durationSeconds": seconds,
          "requiresPostureDetection": boolean
        }
      ],
      "caloriesBurn": estimated_calories,
      "targetMuscles": ["muscle1", "muscle2"]
    }
    ''';
  }

  Map<String, dynamic> _parseAIResponse(String response) {
    // Extract JSON from the response
    final jsonStr = response.substring(
      response.indexOf('{'),
      response.lastIndexOf('}') + 1,
    );
    return Map<String, dynamic>.from(jsonDecode(jsonStr));
  }

  WorkoutType _getWorkoutType(String location) {
    switch (location.toLowerCase()) {
      case 'office':
        return WorkoutType.officeFriendly;
      case 'gym':
        return WorkoutType.fullBody;
      case 'home':
      default:
        return WorkoutType.quickBreak;
    }
  }

  List<Exercise> _createExercises(List<dynamic> exercisesData) {
    return exercisesData.map((data) {
      return Exercise(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            '_${data['name']}',
        name: data['name'],
        description: data['description'],
        durationSeconds: data['durationSeconds'],
        requiresPostureDetection: data['requiresPostureDetection'] ?? false,
      );
    }).toList();
  }
}
