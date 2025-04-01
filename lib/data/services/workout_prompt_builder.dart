import 'package:fitflow/data/models/workout_model.dart';

class WorkoutPromptBuilder {
  static String _buildWorkoutPrompt({
    required int availableMinutes,
    required String location,
    required String fitnessLevel,
  }) {
    return """
    Generate a personalized workout routine with the following specifications:
    - Duration: $availableMinutes minutes
    - Location: $location
    - Fitness Level: $fitnessLevel

    Please provide the workout in the following JSON format:
    {
      "title": "Workout title",
      "description": "Brief description of the workout",
      "exercises": [
        {
          "name": "Exercise name",
          "description": "Detailed instructions",
          "durationSeconds": seconds,
          "requiresPostureDetection": boolean
        }
      ],
      "caloriesBurn": estimated calories,
      "targetMuscles": ["muscle groups"]
    }

    Requirements:
    1. Exercises should be appropriate for the specified location
    2. Total workout duration should match available minutes
    3. Exercise difficulty should match fitness level
    4. Include proper warm-up and cool-down
    5. Focus on exercises that can be done safely without equipment
    6. For office location, include desk-friendly exercises
    """;
  }

  static String buildWorkoutPromptWithPreferences({
    required int availableMinutes,
    required String location,
    required String fitnessLevel,
    required List<String> preferences,
  }) {
    final basePrompt = _buildWorkoutPrompt(
      availableMinutes: availableMinutes,
      location: location,
      fitnessLevel: fitnessLevel,
    );

    final preferencesStr = preferences.join(', ');
    return "$basePrompt\nAdditional preferences: Focus on $preferencesStr exercises.";
  }
}
