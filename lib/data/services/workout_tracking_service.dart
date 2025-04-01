import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'dart:math' as math;

class WorkoutTrackingService {
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  // Callback for movement detection
  Function(bool isMoving)? onMovementDetected;
  Function(Map<String, dynamic> stats)? onWorkoutStatsUpdated;

  // Tracking state
  bool _isTracking = false;
  DateTime? _workoutStartTime;
  int _totalMovementSeconds = 0;
  int _caloriesBurned = 0;

  // Movement detection thresholds
  static const double _movementThreshold = 1.5; // Adjust based on testing
  static const int _samplingRateMs = 100;

  void startTracking() {
    if (_isTracking) return;

    _isTracking = true;
    _workoutStartTime = DateTime.now();
    _initializeSensors();
  }

  void stopTracking() {
    _isTracking = false;
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _workoutStartTime = null;
  }

  void _initializeSensors() {
    // Track accelerometer data
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      final magnitude = _calculateMagnitude(event.x, event.y, event.z);
      final isMoving = magnitude > _movementThreshold;

      onMovementDetected?.call(isMoving);

      if (isMoving) {
        _totalMovementSeconds += _samplingRateMs ~/ 1000;
        // Simple calorie calculation - can be improved with MET values
        _caloriesBurned = (_totalMovementSeconds * 0.1).round();

        onWorkoutStatsUpdated?.call({
          'duration': _totalMovementSeconds,
          'caloriesBurned': _caloriesBurned,
          'intensity': _calculateIntensity(magnitude),
        });
      }
    });

    // Track gyroscope data for rotation detection
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      // Implement rotation-based exercise detection
      // This can be used for exercises like twists, turns, etc.
    });
  }

  double _calculateMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  String _calculateIntensity(double magnitude) {
    if (magnitude > 3.0) return 'High';
    if (magnitude > 2.0) return 'Medium';
    return 'Low';
  }

  Map<String, dynamic> getWorkoutSummary() {
    return {
      'startTime': _workoutStartTime?.toIso8601String(),
      'duration': _totalMovementSeconds,
      'caloriesBurned': _caloriesBurned,
    };
  }
}
