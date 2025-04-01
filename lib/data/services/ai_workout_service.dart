import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'package:fitflow/data/services/workout_prompt_builder.dart';

class AIWorkoutService {
  final GenerativeModel _model;

  AIWorkoutService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-pro',
          apiKey: apiKey,
        );

  Future<WorkoutModel> generateWorkout({
    required int availableMinutes,
    required String location,
    required String fitnessLevel,
    List<String>? preferences,
  }) async {
    try {
      final prompt = preferences != null
          ? WorkoutPromptBuilder.buildWorkoutPromptWithPreferences(
              availableMinutes: availableMinutes,
              location: location,
              fitnessLevel: fitnessLevel,
              preferences: preferences,
            )
          : _buildWorkoutPrompt(
              // Use the local method
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
    if (exercisesData == null || exercisesData.isEmpty) {
      throw Exception('No exercises data provided by AI');
    }

    return exercisesData.map((data) {
      if (data == null || !(data is Map)) {
        throw Exception('Invalid exercise data format');
      }

      final name = data['name'];
      final description = data['description'];
      final durationSeconds = data['durationSeconds'];

      if (name == null || description == null || durationSeconds == null) {
        throw Exception('Missing required exercise data fields');
      }

      if (!(durationSeconds is num)) {
        throw Exception('Duration must be a number');
      }

      return Exercise(
        id: '${DateTime.now().millisecondsSinceEpoch}_${name.toString().toLowerCase().replaceAll(' ', '_')}',
        name: name.toString(),
        description: description.toString(),
        durationSeconds: durationSeconds.toInt(),
        requiresPostureDetection: data['requiresPostureDetection'] ?? false,
      );
    }).toList();
  }
}
