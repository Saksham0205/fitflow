import 'package:flutter/material.dart';
import 'package:fitflow/data/repositories/workout_repository.dart';
import 'package:fitflow/data/models/workout_model.dart';
import 'package:fitflow/config/constants.dart';

class AIWorkoutScreen extends StatefulWidget {
  const AIWorkoutScreen({super.key});

  @override
  State<AIWorkoutScreen> createState() => _AIWorkoutScreenState();
}

class _AIWorkoutScreenState extends State<AIWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';

  // Form values
  int _availableMinutes = 20;
  String _location = 'Home';
  String _fitnessLevel = 'Beginner';

  final List<String> _locations = ['Home', 'Office', 'Gym'];
  final List<String> _fitnessLevels = ['Beginner', 'Intermediate', 'Advanced'];

  Future<void> _generateWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // TODO: Get API key from secure storage
      final repository = WorkoutRepository('your-api-key-here');
      final workout = await repository.generateAIWorkout(
        availableMinutes: _availableMinutes,
        location: _location,
        fitnessLevel: _fitnessLevel,
      );

      if (!mounted) return;

      // Navigate to workout detail screen
      Navigator.pushNamed(
        context,
        '/workout-detail',
        arguments: {'workoutId': workout.id},
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate workout. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Available minutes slider
              Text(
                'Available Time: $_availableMinutes minutes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _availableMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                label: '$_availableMinutes minutes',
                onChanged: (value) {
                  setState(() {
                    _availableMinutes = value.round();
                  });
                },
              ),
              const SizedBox(height: 24),

              // Location dropdown
              DropdownButtonFormField<String>(
                value: _location,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                items: _locations.map((location) {
                  return DropdownMenuItem(
                    value: location,
                    child: Text(location),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _location = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Fitness level dropdown
              DropdownButtonFormField<String>(
                value: _fitnessLevel,
                decoration: const InputDecoration(
                  labelText: 'Fitness Level',
                  border: OutlineInputBorder(),
                ),
                items: _fitnessLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _fitnessLevel = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

              // Generate button
              ElevatedButton(
                onPressed: _isLoading ? null : _generateWorkout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Generate Workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
