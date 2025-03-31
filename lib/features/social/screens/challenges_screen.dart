import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/config/theme.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeChallenges = [];
  List<Map<String, dynamic>> _availableChallenges = [];
  List<Map<String, dynamic>> _completedChallenges = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, redirect to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    setState(() {
      _userId = user.uid;
    });

    await _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get challenges from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.challengesCollection)
          .get();

      final challenges = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID to the data
        return data;
      }).toList();

      // Separate challenges into active, available, and completed
      final active = <Map<String, dynamic>>[];
      final available = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];

      for (final challenge in challenges) {
        final participants = List<String>.from(challenge['participants'] ?? []);
        final completedBy = List<String>.from(challenge['completedBy'] ?? []);

        if (completedBy.contains(_userId)) {
          completed.add(challenge);
        } else if (participants.contains(_userId)) {
          active.add(challenge);
        } else {
          available.add(challenge);
        }
      }

      setState(() {
        _activeChallenges = active;
        _availableChallenges = available;
        _completedChallenges = completed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading challenges: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinChallenge(String challengeId) async {
    if (_userId == null) return;

    try {
      // Add user to challenge participants
      await FirebaseFirestore.instance
          .collection(AppConstants.challengesCollection)
          .doc(challengeId)
          .update({
        'participants': FieldValue.arrayUnion([_userId]),
      });

      // Reload challenges
      await _loadChallenges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined challenge successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error joining challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join challenge')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Available'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active challenges tab
          _buildChallengesList(_activeChallenges, isActive: true),

          // Available challenges tab
          _buildChallengesList(_availableChallenges, isAvailable: true),

          // Completed challenges tab
          _buildChallengesList(_completedChallenges, isCompleted: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // In a real app, this would open a screen to create a new challenge
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Create challenge feature coming soon!')),
          );
        },
        tooltip: 'Create Challenge',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChallengesList(
    List<Map<String, dynamic>> challenges, {
    bool isActive = false,
    bool isAvailable = false,
    bool isCompleted = false,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (challenges.isEmpty) {
      String message;
      if (isActive) {
        message = 'You have no active challenges';
      } else if (isAvailable) {
        message = 'No available challenges found';
      } else {
        message = 'You have not completed any challenges yet';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: _loadChallenges,
                  child: const Text('Refresh'),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        return _buildChallengeCard(
          context,
          challenge,
          isActive: isActive,
          isAvailable: isAvailable,
          isCompleted: isCompleted,
        );
      },
    );
  }

  Widget _buildChallengeCard(
    BuildContext context,
    Map<String, dynamic> challenge, {
    bool isActive = false,
    bool isAvailable = false,
    bool isCompleted = false,
  }) {
    final title = challenge['title'] as String? ?? 'Untitled Challenge';
    final description = challenge['description'] as String? ?? 'No description';
    final goal = challenge['goal'] as int? ?? 0;
    final type = challenge['type'] as String? ?? 'steps';
    final endDate = challenge['endDate'] as Timestamp?;
    final participants = List<String>.from(challenge['participants'] ?? []);

    // Format end date
    String endDateText = 'No end date';
    if (endDate != null) {
      final date = endDate.toDate();
      endDateText = '${date.day}/${date.month}/${date.year}';
    }

    // Icon based on challenge type
    IconData typeIcon;
    String typeText;
    switch (type) {
      case 'steps':
        typeIcon = Icons.directions_walk;
        typeText = '$goal steps';
        break;
      case 'water':
        typeIcon = Icons.water_drop;
        typeText = '$goal ml';
        break;
      case 'workouts':
        typeIcon = Icons.fitness_center;
        typeText = '$goal workouts';
        break;
      case 'active_minutes':
        typeIcon = Icons.timer;
        typeText = '$goal minutes';
        break;
      default:
        typeIcon = Icons.emoji_events;
        typeText = '$goal goal';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Challenge header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.1)
                  : isActive
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  typeIcon,
                  color: isCompleted
                      ? Colors.green
                      : isActive
                          ? AppTheme.primaryColor
                          : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
              ],
            ),
          ),

          // Challenge details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 16),

                // Challenge stats
                Row(
                  children: [
                    // Goal
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Goal',
                        typeText,
                        typeIcon,
                      ),
                    ),

                    // End date
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'End Date',
                        endDateText,
                        Icons.calendar_today,
                      ),
                    ),

                    // Participants
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Participants',
                        participants.length.toString(),
                        Icons.people,
                      ),
                    ),
                  ],
                ),

                // Action button
                if (isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _joinChallenge(challenge['id']),
                        child: const Text('Join Challenge'),
                      ),
                    ),
                  ),

                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          // In a real app, this would show challenge details and progress
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Challenge details coming soon!')),
                          );
                        },
                        child: const Text('View Progress'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
