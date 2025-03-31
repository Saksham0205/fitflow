import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/config/theme.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/data/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  FitnessLevel _selectedFitnessLevel = FitnessLevel.beginner;
  final List<String> _selectedWorkoutTypes = [];
  final Map<String, bool> _availabilityByDay = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  bool _isLoading = false;
  String? _errorMessage;

  final _workoutTypes = [
    {'id': 'quickBreak', 'name': 'Quick Breaks (2-5 min)'},
    {'id': 'officeFriendly', 'name': 'Office-Friendly'},
    {'id': 'fullBody', 'name': 'Full Body'},
    {'id': 'cardio', 'name': 'Cardio'},
    {'id': 'strength', 'name': 'Strength'},
    {'id': 'flexibility', 'name': 'Flexibility & Stretching'},
    {'id': 'posture', 'name': 'Posture Improvement'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, redirect to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _heightController.text = data['height']?.toString() ?? '';
            _weightController.text = data['weight']?.toString() ?? '';

            // Set fitness level
            if (data['fitnessLevel'] != null) {
              _selectedFitnessLevel = FitnessLevel.values.firstWhere(
                (e) => e.toString() == 'FitnessLevel.${data['fitnessLevel']}',
                orElse: () => FitnessLevel.beginner,
              );
            }

            // Set workout types
            if (data['preferredWorkoutTypes'] != null) {
              _selectedWorkoutTypes.clear();
              _selectedWorkoutTypes.addAll(
                List<String>.from(data['preferredWorkoutTypes']),
              );
            }

            // Set availability
            if (data['schedule'] != null) {
              final schedule = data['schedule'] as Map<String, dynamic>;
              schedule.forEach((key, value) {
                if (_availabilityByDay.containsKey(key)) {
                  _availabilityByDay[key] = value as bool;
                }
              });
            }
          });
        }
      }
    } catch (e) {
      // Error loading profile, but continue with empty form
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        // Prepare data
        final userData = {
          'height': double.tryParse(_heightController.text) ?? 0,
          'weight': double.tryParse(_weightController.text) ?? 0,
          'fitnessLevel': _selectedFitnessLevel.toString().split('.').last,
          'preferredWorkoutTypes': _selectedWorkoutTypes,
          'schedule': _availabilityByDay,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Save to Firestore
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .update(userData);

        if (mounted) {
          // Navigate to tracking dashboard
          Navigator.of(context).pushReplacementNamed('/tracking');
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to save profile. Please try again.';
        });
        debugPrint('Error saving profile: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Height field
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: Icon(Icons.height),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your height';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Weight field
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your weight';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Fitness level
                Text(
                  'Fitness Level',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Fitness level radio buttons
                _buildFitnessLevelSelector(),
                const SizedBox(height: 24),

                // Workout preferences
                Text(
                  'Workout Preferences',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the types of workouts you prefer',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Workout type checkboxes
                _buildWorkoutTypeSelector(),
                const SizedBox(height: 24),

                // Availability
                Text(
                  'Weekly Availability',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the days you are available for workouts',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Availability checkboxes
                _buildAvailabilitySelector(),
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  ),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                        : const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFitnessLevelSelector() {
    return Column(
      children: [
        RadioListTile<FitnessLevel>(
          title: const Text('Beginner'),
          subtitle:
              const Text('New to fitness or returning after a long break'),
          value: FitnessLevel.beginner,
          groupValue: _selectedFitnessLevel,
          onChanged: (FitnessLevel? value) {
            if (value != null) {
              setState(() {
                _selectedFitnessLevel = value;
              });
            }
          },
        ),
        RadioListTile<FitnessLevel>(
          title: const Text('Intermediate'),
          subtitle: const Text('Regular exercise with some experience'),
          value: FitnessLevel.intermediate,
          groupValue: _selectedFitnessLevel,
          onChanged: (FitnessLevel? value) {
            if (value != null) {
              setState(() {
                _selectedFitnessLevel = value;
              });
            }
          },
        ),
        RadioListTile<FitnessLevel>(
          title: const Text('Advanced'),
          subtitle: const Text('Experienced with consistent training'),
          value: FitnessLevel.advanced,
          groupValue: _selectedFitnessLevel,
          onChanged: (FitnessLevel? value) {
            if (value != null) {
              setState(() {
                _selectedFitnessLevel = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildWorkoutTypeSelector() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _workoutTypes.map((type) {
        final isSelected = _selectedWorkoutTypes.contains(type['id']);
        return FilterChip(
          label: Text(type['name'] as String),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedWorkoutTypes.add(type['id'] as String);
              } else {
                _selectedWorkoutTypes.remove(type['id'] as String);
              }
            });
          },
          backgroundColor: Colors.grey[200],
          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
          checkmarkColor: AppTheme.primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildAvailabilitySelector() {
    return Column(
      children: _availabilityByDay.entries.map((entry) {
        return CheckboxListTile(
          title: Text(entry.key),
          value: entry.value,
          onChanged: (bool? value) {
            if (value != null) {
              setState(() {
                _availabilityByDay[entry.key] = value;
              });
            }
          },
          activeColor: AppTheme.primaryColor,
        );
      }).toList(),
    );
  }
}
