import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:health/health.dart';

class FitnessTrackingProvider extends ChangeNotifier {
  final health = Health();
  late Stream<StepCount> _stepCountStream;

  int _steps = 0;
  int _waterIntake = 0; // in ml
  final List<String> _completedWorkouts = [];

  int get steps => _steps;
  int get waterIntake => _waterIntake;
  List<String> get completedWorkouts => List.unmodifiable(_completedWorkouts);

  FitnessTrackingProvider() {
    initializeStepCounting();
    fetchHealthData();
  }

  void initializeStepCounting() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
    );
  }

  void _onStepCount(StepCount event) {
    _steps = event.steps;
    notifyListeners();
  }

  void _onStepCountError(dynamic error) {
    if (kDebugMode) {
      print('Step counting error: $error');
    }
  }

  Future<void> fetchHealthData() async {
    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.WATER,
      ];

      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      final authorized = await health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (authorized) {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);

        final steps = await health.getTotalStepsInInterval(midnight, now);
        if (steps != null) {
          _steps = steps;
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching health data: $e');
      }
    }
  }

  void updateWaterIntake(int amount) {
    if (amount >= 0) {
      _waterIntake += amount;
      notifyListeners();
    }
  }

  void addCompletedWorkout(String workoutId) {
    if (workoutId.isNotEmpty) {
      _completedWorkouts.add(workoutId);
      notifyListeners();
    }
  }

  void dispose() {
    // Cancel any subscriptions if needed
    super.dispose();
  }
}
