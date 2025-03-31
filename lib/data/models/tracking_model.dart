import 'package:cloud_firestore/cloud_firestore.dart';

class DailyTrackingModel {
  final String id;
  final String userId;
  final DateTime date;
  final int waterIntake; // in ml
  final int steps;
  final int activeMinutes;
  final List<WorkoutSession> completedWorkouts;
  final Map<String, dynamic>? additionalMetrics;

  DailyTrackingModel({
    required this.id,
    required this.userId,
    required this.date,
    this.waterIntake = 0,
    this.steps = 0,
    this.activeMinutes = 0,
    this.completedWorkouts = const [],
    this.additionalMetrics,
  });

  factory DailyTrackingModel.create(String userId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return DailyTrackingModel(
      id: '${userId}_${today.millisecondsSinceEpoch}',
      userId: userId,
      date: today,
    );
  }

  factory DailyTrackingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse completed workouts
    List<WorkoutSession> workoutsList = [];
    if (data['completedWorkouts'] != null) {
      workoutsList = List<Map<String, dynamic>>.from(data['completedWorkouts'])
          .map((w) => WorkoutSession.fromMap(w))
          .toList();
    }

    return DailyTrackingModel(
      id: doc.id,
      userId: data['userId'],
      date: (data['date'] as Timestamp).toDate(),
      waterIntake: data['waterIntake'] ?? 0,
      steps: data['steps'] ?? 0,
      activeMinutes: data['activeMinutes'] ?? 0,
      completedWorkouts: workoutsList,
      additionalMetrics: data['additionalMetrics'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'waterIntake': waterIntake,
      'steps': steps,
      'activeMinutes': activeMinutes,
      'completedWorkouts': completedWorkouts.map((w) => w.toMap()).toList(),
      'additionalMetrics': additionalMetrics,
    };
  }

  DailyTrackingModel copyWith({
    int? waterIntake,
    int? steps,
    int? activeMinutes,
    List<WorkoutSession>? completedWorkouts,
    Map<String, dynamic>? additionalMetrics,
  }) {
    return DailyTrackingModel(
      id: id,
      userId: userId,
      date: date,
      waterIntake: waterIntake ?? this.waterIntake,
      steps: steps ?? this.steps,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      completedWorkouts: completedWorkouts ?? this.completedWorkouts,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
    );
  }

  // Add water intake
  DailyTrackingModel addWater(int amount) {
    return copyWith(waterIntake: waterIntake + amount);
  }

  // Add steps
  DailyTrackingModel addSteps(int count) {
    return copyWith(steps: steps + count);
  }

  // Add completed workout
  DailyTrackingModel addWorkout(WorkoutSession session) {
    final updatedWorkouts = List<WorkoutSession>.from(completedWorkouts);
    updatedWorkouts.add(session);

    // Calculate active minutes from workout
    final updatedActiveMinutes = activeMinutes + (session.durationMinutes ?? 0);

    return copyWith(
      completedWorkouts: updatedWorkouts,
      activeMinutes: updatedActiveMinutes,
    );
  }
}

class WorkoutSession {
  final String workoutId;
  final String workoutTitle;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final int? caloriesBurned;
  final bool completed;
  final Map<String, dynamic>? performance; // Performance metrics

  WorkoutSession({
    required this.workoutId,
    required this.workoutTitle,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.caloriesBurned,
    this.completed = false,
    this.performance,
  });

  factory WorkoutSession.fromMap(Map<String, dynamic> data) {
    return WorkoutSession(
      workoutId: data['workoutId'],
      workoutTitle: data['workoutTitle'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      durationMinutes: data['durationMinutes'],
      caloriesBurned: data['caloriesBurned'],
      completed: data['completed'] ?? false,
      performance: data['performance'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'workoutTitle': workoutTitle,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'completed': completed,
      'performance': performance,
    };
  }

  // Complete a workout session
  WorkoutSession complete({
    required DateTime endTime,
    required int durationMinutes,
    required int caloriesBurned,
    Map<String, dynamic>? performance,
  }) {
    return WorkoutSession(
      workoutId: workoutId,
      workoutTitle: workoutTitle,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      completed: true,
      performance: performance ?? this.performance,
    );
  }
}
