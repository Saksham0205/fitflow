import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fitflow/data/models/workout_model.dart';

class AIWorkoutServiceHF {
  final String _apiKey;
  final String _modelEndpoint =
      'https://api-inference.huggingface.co/models/gpt2';

  AIWorkoutServiceHF(this._apiKey);

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

      final response = await http.post(
        Uri.parse(_modelEndpoint),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': prompt,
          'parameters': {
            'max_length': 1000,
            'temperature': 0.7,
            'top_p': 0.9,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate workout: ${response.body}');
      }

      final workoutData = _parseAIResponse(response.body);

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
    final List<dynamic> generated = jsonDecode(response);
    final jsonStr = generated[0]['generated_text'];

    // Extract JSON from the response
    final startIndex = jsonStr.indexOf('{');
    final endIndex = jsonStr.lastIndexOf('}') + 1;
    final jsonContent = jsonStr.substring(startIndex, endIndex);

    return Map<String, dynamic>.from(jsonDecode(jsonContent));
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
