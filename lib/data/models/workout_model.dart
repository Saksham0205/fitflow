import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkoutType {
  quickBreak, // 2-5 min exercises for quick breaks
  officeFriendly, // Seated or standing exercises suitable for office
  fullBody, // Complete body workout
  cardio, // Cardio focused
  strength, // Strength focused
  flexibility, // Stretching and flexibility
  posture // Posture improvement
}

class Exercise {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final int durationSeconds;
  final bool requiresPostureDetection;
  final Map<String, dynamic>?
      postureConfig; // Configuration for posture detection

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.videoUrl,
    required this.durationSeconds,
    this.requiresPostureDetection = false,
    this.postureConfig,
  });

  factory Exercise.fromFirestore(Map<String, dynamic> data) {
    return Exercise(
      id: data['id'],
      name: data['name'],
      description: data['description'],
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      durationSeconds: data['durationSeconds'],
      requiresPostureDetection: data['requiresPostureDetection'] ?? false,
      postureConfig: data['postureConfig'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'durationSeconds': durationSeconds,
      'requiresPostureDetection': requiresPostureDetection,
      'postureConfig': postureConfig,
    };
  }
}

class WorkoutModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final WorkoutType type;
  final String difficulty; // 'beginner', 'intermediate', 'advanced'
  final int durationMinutes;
  final List<Exercise> exercises;
  final bool isPremium;
  final int caloriesBurn; // Estimated calories burned
  final List<String> targetMuscles;
  final List<String> tags;
  final DateTime createdAt;

  WorkoutModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.type,
    required this.difficulty,
    required this.durationMinutes,
    required this.exercises,
    this.isPremium = false,
    required this.caloriesBurn,
    required this.targetMuscles,
    this.tags = const [],
    required this.createdAt,
  });

  factory WorkoutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse exercises
    List<Exercise> exercisesList = [];
    if (data['exercises'] != null) {
      exercisesList = List<Map<String, dynamic>>.from(data['exercises'])
          .map((e) => Exercise.fromFirestore(e))
          .toList();
    }

    return WorkoutModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      type: _parseWorkoutType(data['type']),
      difficulty: data['difficulty'] ?? 'beginner',
      durationMinutes: data['durationMinutes'] ?? 0,
      exercises: exercisesList,
      isPremium: data['isPremium'] ?? false,
      caloriesBurn: data['caloriesBurn'] ?? 0,
      targetMuscles: List<String>.from(data['targetMuscles'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'type': type.toString().split('.').last,
      'difficulty': difficulty,
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((e) => e.toFirestore()).toList(),
      'isPremium': isPremium,
      'caloriesBurn': caloriesBurn,
      'targetMuscles': targetMuscles,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Helper method to parse workout type from string
  static WorkoutType _parseWorkoutType(String? type) {
    if (type == null) return WorkoutType.quickBreak;

    switch (type) {
      case 'officeFriendly':
        return WorkoutType.officeFriendly;
      case 'fullBody':
        return WorkoutType.fullBody;
      case 'cardio':
        return WorkoutType.cardio;
      case 'strength':
        return WorkoutType.strength;
      case 'flexibility':
        return WorkoutType.flexibility;
      case 'posture':
        return WorkoutType.posture;
      default:
        return WorkoutType.quickBreak;
    }
  }
}
