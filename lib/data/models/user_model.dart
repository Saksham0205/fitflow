import 'package:cloud_firestore/cloud_firestore.dart';

enum FitnessLevel { beginner, intermediate, advanced }

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final double? height; // in cm
  final double? weight; // in kg
  final FitnessLevel fitnessLevel;
  final List<String> preferredWorkoutTypes;
  final Map<String, dynamic> schedule; // Daily availability
  final bool isPremium;
  final DateTime createdAt;
  final DateTime? lastActive;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.height,
    this.weight,
    this.fitnessLevel = FitnessLevel.beginner,
    this.preferredWorkoutTypes = const [],
    this.schedule = const {},
    this.isPremium = false,
    required this.createdAt,
    this.lastActive,
  });

  // Create a user from Firebase Auth
  factory UserModel.fromFirebaseAuth(String uid, String email) {
    return UserModel(
      id: uid,
      email: email,
      createdAt: DateTime.now(),
    );
  }

  // Create a user from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      fitnessLevel: _parseFitnessLevel(data['fitnessLevel']),
      preferredWorkoutTypes:
          List<String>.from(data['preferredWorkoutTypes'] ?? []),
      schedule: data['schedule'] ?? {},
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert user to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'height': height,
      'weight': weight,
      'fitnessLevel': fitnessLevel.toString().split('.').last,
      'preferredWorkoutTypes': preferredWorkoutTypes,
      'schedule': schedule,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
    };
  }

  // Create a copy of the user with updated fields
  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    double? height,
    double? weight,
    FitnessLevel? fitnessLevel,
    List<String>? preferredWorkoutTypes,
    Map<String, dynamic>? schedule,
    bool? isPremium,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      preferredWorkoutTypes:
          preferredWorkoutTypes ?? this.preferredWorkoutTypes,
      schedule: schedule ?? this.schedule,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  // Helper method to parse fitness level from string
  static FitnessLevel _parseFitnessLevel(String? level) {
    if (level == null) return FitnessLevel.beginner;

    switch (level) {
      case 'intermediate':
        return FitnessLevel.intermediate;
      case 'advanced':
        return FitnessLevel.advanced;
      default:
        return FitnessLevel.beginner;
    }
  }
}
