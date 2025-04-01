import 'package:fitflow/data/services/ai_workout_service.dart';
import 'package:fitflow/data/services/ai_workout_service_hf.dart';

enum AIServiceType {
  gemini,
  huggingface,
}

class AIWorkoutServiceFactory {
  static dynamic createService(AIServiceType type, String apiKey) {
    switch (type) {
      case AIServiceType.gemini:
        return AIWorkoutService(apiKey);
      case AIServiceType.huggingface:
        return AIWorkoutServiceHF(apiKey);
      default:
        throw Exception('Unsupported AI service type');
    }
  }
}
