import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/config/theme.dart';
import 'package:fitflow/data/models/user_model.dart';

class WorkoutListScreen extends StatefulWidget {
  const WorkoutListScreen({super.key});

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _workouts = [];
  String _selectedFilter = 'All';
  UserModel? _userProfile;

  final List<String> _filters = [
    'All',
    'Quick Break',
    'Office Friendly',
    'Full Body',
    'Posture',
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
        setState(() {
          _userProfile = UserModel.fromFirestore(doc);
        });
      }

      // Load workouts after getting user profile
      await _loadWorkouts();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      // Still try to load workouts even if profile loading fails
      await _loadWorkouts();
    }
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get workouts from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.workoutsCollection)
          .get();

      final workouts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID to the data
        return data;
      }).toList();

      // Sort workouts based on user preferences if available
      if (_userProfile != null &&
          _userProfile!.preferredWorkoutTypes.isNotEmpty) {
        workouts.sort((a, b) {
          final aType = a['type'] as String?;
          final bType = b['type'] as String?;

          final aIsPreferred = aType != null &&
              _userProfile!.preferredWorkoutTypes.contains(aType);
          final bIsPreferred = bType != null &&
              _userProfile!.preferredWorkoutTypes.contains(bType);

          if (aIsPreferred && !bIsPreferred) return -1;
          if (!aIsPreferred && bIsPreferred) return 1;
          return 0;
        });
      }

      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading workouts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredWorkouts() {
    if (_selectedFilter == 'All') {
      return _workouts;
    }

    // Convert filter name to workout type
    final filterType = _selectedFilter.replaceAll(' ', '').toLowerCase();

    return _workouts.where((workout) {
      final type = workout['type'] as String?;
      if (type == null) return false;
      return type.toLowerCase() == filterType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkouts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _selectedFilter == filter,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        }
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _selectedFilter == filter
                            ? AppTheme.primaryColor
                            : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Workouts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getFilteredWorkouts().isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No workouts found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _getFilteredWorkouts().length,
                        itemBuilder: (context, index) {
                          final workout = _getFilteredWorkouts()[index];
                          return _buildWorkoutCard(context, workout);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/posture');
        },
        child: const Icon(Icons.camera_alt),
        tooltip: 'Posture Detection',
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, Map<String, dynamic> workout) {
    final title = workout['title'] as String? ?? 'Untitled Workout';
    final description = workout['description'] as String? ?? 'No description';
    final duration = workout['durationMinutes'] as int? ?? 20;
    final level = workout['level'] as String? ?? 'Beginner';
    final type = workout['type'] as String? ?? 'fullBody';

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

    // Icon based on workout type
    IconData typeIcon;
    switch (type) {
      case 'quickBreak':
        typeIcon = Icons.timer;
        break;
      case 'officeFriendly':
        typeIcon = Icons.work;
        break;
      case 'fullBody':
        typeIcon = Icons.fitness_center;
        break;
      case 'cardio':
        typeIcon = Icons.directions_run;
        break;
      case 'strength':
        typeIcon = Icons.fitness_center;
        break;
      case 'flexibility':
        typeIcon = Icons.accessibility_new;
        break;
      case 'posture':
        typeIcon = Icons.accessibility;
        break;
      default:
        typeIcon = Icons.fitness_center;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            '/workout-detail',
            arguments: {'workoutId': workout['id']},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workout image or placeholder
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Icon(
                typeIcon,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Chip(
                        label: Text(
                          typeDisplay,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Duration and level
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$duration min',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.fitness_center,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        level,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
