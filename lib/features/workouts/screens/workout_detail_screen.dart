import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/config/theme.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _workout;
  List<Map<String, dynamic>> _exercises = [];
  bool _workoutStarted = false;
  int _currentExerciseIndex = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }

  Future<void> _loadWorkoutDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get workout details
      final workoutDoc = await FirebaseFirestore.instance
          .collection(AppConstants.workoutsCollection)
          .doc(widget.workoutId)
          .get();

      if (!workoutDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout not found')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final workoutData = workoutDoc.data()!;
      workoutData['id'] = workoutDoc.id;

      // Get exercises
      List<Map<String, dynamic>> exercises = [];
      if (workoutData['exercises'] != null) {
        exercises = List<Map<String, dynamic>>.from(
          workoutData['exercises'],
        );
      }

      setState(() {
        _workout = workoutData;
        _exercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading workout details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load workout details')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startWorkout() {
    setState(() {
      _workoutStarted = true;
      _currentExerciseIndex = 0;
    });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
    } else {
      _completeWorkout();
    }
  }

  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
      });
    }
  }

  Future<void> _completeWorkout() async {
    setState(() {
      _isCompleting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create workout session record
      final workoutSession = {
        'workoutId': widget.workoutId,
        'workoutTitle': _workout?['title'] ?? 'Unknown Workout',
        'completedAt': FieldValue.serverTimestamp(),
        'durationMinutes': _workout?['durationMinutes'] ?? 0,
      };

      // Get today's tracking document
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final trackingId = '${user.uid}_${today.millisecondsSinceEpoch}';

      // Update tracking document with completed workout
      await FirebaseFirestore.instance
          .collection(AppConstants.trackingCollection)
          .doc(trackingId)
          .update({
        'completedWorkouts': FieldValue.arrayUnion([workoutSession]),
        'activeMinutes':
            FieldValue.increment(_workout?['durationMinutes'] ?? 0),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout completed!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error completing workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record workout completion')),
        );
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workout?['title'] ?? 'Workout Details'),
        actions: [
          if (!_workoutStarted && _workout != null)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: () {
                Navigator.of(context).pushNamed('/posture');
              },
              tooltip: 'Posture Detection',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workout == null
              ? const Center(child: Text('Workout not found'))
              : _workoutStarted
                  ? _buildWorkoutInProgress()
                  : _buildWorkoutDetails(),
    );
  }

  Widget _buildWorkoutDetails() {
    final title = _workout?['title'] as String? ?? 'Untitled Workout';
    final description = _workout?['description'] as String? ?? 'No description';
    final duration = _workout?['durationMinutes'] as int? ?? 20;
    final level = _workout?['level'] as String? ?? 'Beginner';
    final type = _workout?['type'] as String? ?? 'fullBody';

    // Convert type to display name
    String typeDisplay;
    switch (type) {
      case 'quickBreak':
        typeDisplay = 'Quick Break';
        break;
      case 'officeFriendly':
        typeDisplay = 'Office Friendly';
        break;
      case 'fullBody':
        typeDisplay = 'Full Body';
        break;
      case 'cardio':
        typeDisplay = 'Cardio';
        break;
      case 'strength':
        typeDisplay = 'Strength';
        break;
      case 'flexibility':
        typeDisplay = 'Flexibility';
        break;
      case 'posture':
        typeDisplay = 'Posture';
        break;
      default:
        typeDisplay = 'Other';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workout image or placeholder
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          // Type and level chips
          Row(
            children: [
              Chip(
                label: Text(typeDisplay),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(level),
                backgroundColor: Colors.blue.withOpacity(0.1),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('$duration min'),
                backgroundColor: Colors.orange.withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Exercises
          Text(
            'Exercises',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Exercise list
          _exercises.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No exercises found for this workout',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    return _buildExerciseItem(exercise, index);
                  },
                ),
          const SizedBox(height: 32),

          // Start workout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startWorkout,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start Workout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise, int index) {
    final name = exercise['name'] as String? ?? 'Exercise ${index + 1}';
    final description = exercise['description'] as String? ?? 'No description';
    final duration = exercise['durationSeconds'] as int? ?? 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Exercise number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Exercise details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${duration}s',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutInProgress() {
    if (_exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No exercises in this workout'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _workoutStarted = false;
                });
              },
              child: const Text('Back to Details'),
            ),
          ],
        ),
      );
    }

    final exercise = _exercises[_currentExerciseIndex];
    final name =
        exercise['name'] as String? ?? 'Exercise ${_currentExerciseIndex + 1}';
    final description = exercise['description'] as String? ?? 'No description';
    final duration = exercise['durationSeconds'] as int? ?? 30;
    final requiresPostureDetection =
        exercise['requiresPostureDetection'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentExerciseIndex + 1) / _exercises.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Exercise ${_currentExerciseIndex + 1} of ${_exercises.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),

          // Exercise details
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Exercise image or placeholder
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Exercise name
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Duration chip
                  Chip(
                    label: Text('$duration seconds'),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Posture detection button
                  if (requiresPostureDetection)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/posture');
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Check Posture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous button
                ElevatedButton(
                  onPressed:
                      _currentExerciseIndex > 0 ? _previousExercise : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Previous'),
                ),

                // Next/Complete button
                ElevatedButton(
                  onPressed: _isCompleting ? null : _nextExercise,
                  child: _isCompleting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Text(
                          _currentExerciseIndex < _exercises.length - 1
                              ? 'Next'
                              : 'Complete',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
