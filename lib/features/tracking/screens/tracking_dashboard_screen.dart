import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/config/theme.dart';
import 'package:fitflow/data/models/tracking_model.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackingDashboardScreen extends StatefulWidget {
  const TrackingDashboardScreen({super.key});

  @override
  State<TrackingDashboardScreen> createState() =>
      _TrackingDashboardScreenState();
}

class _TrackingDashboardScreenState extends State<TrackingDashboardScreen> {
  late Stream<DocumentSnapshot> _trackingStream;
  final _waterController = TextEditingController(text: '250');
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
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

    // Initialize tracking stream
    _initializeTrackingStream();
  }

  void _initializeTrackingStream() {
    if (_userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trackingId = '${_userId}_${today.millisecondsSinceEpoch}';

    // Check if today's tracking document exists, create if not
    FirebaseFirestore.instance
        .collection(AppConstants.trackingCollection)
        .doc(trackingId)
        .get()
        .then((doc) {
      if (!doc.exists) {
        // Create new tracking document for today
        final newTracking = DailyTrackingModel.create(_userId!);
        FirebaseFirestore.instance
            .collection(AppConstants.trackingCollection)
            .doc(trackingId)
            .set(newTracking.toFirestore());
      }
    });

    // Set up stream
    _trackingStream = FirebaseFirestore.instance
        .collection(AppConstants.trackingCollection)
        .doc(trackingId)
        .snapshots();
  }

  Future<void> _addWaterIntake() async {
    if (_userId == null) return;

    final amount = int.tryParse(_waterController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final trackingId = '${_userId}_${today.millisecondsSinceEpoch}';

      // Update water intake
      await FirebaseFirestore.instance
          .collection(AppConstants.trackingCollection)
          .doc(trackingId)
          .update({
        'waterIntake': FieldValue.increment(amount),
      });

      // Reset text field
      _waterController.text = '250';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $amount ml of water')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update water intake')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Clear user token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.userTokenKey);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out')),
        );
      }
    }
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _trackingStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading data',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                      child: Text('No tracking data available'));
                }

                // Parse tracking data
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final waterIntake = data['waterIntake'] ?? 0;
                final steps = data['steps'] ?? 0;
                final activeMinutes = data['activeMinutes'] ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Stats cards
                      Row(
                        children: [
                          // Water intake card
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Water',
                              '$waterIntake ml',
                              Icons.water_drop,
                              Colors.blue,
                              waterIntake / 2500, // Target: 2500ml
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Steps card
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Steps',
                              steps.toString(),
                              Icons.directions_walk,
                              Colors.green,
                              steps / 10000, // Target: 10,000 steps
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Active minutes card
                      _buildStatCard(
                        context,
                        'Active Minutes',
                        '$activeMinutes mins',
                        Icons.timer,
                        Colors.orange,
                        activeMinutes / 60, // Target: 60 minutes
                        fullWidth: true,
                      ),
                      const SizedBox(height: 32),

                      // Add water intake
                      Text(
                        'Add Water Intake',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _waterController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Amount (ml)',
                                suffixText: 'ml',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _addWaterIntake,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Quick actions
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(
                            context,
                            'Workouts',
                            Icons.fitness_center,
                            () {
                              Navigator.of(context).pushNamed('/workouts');
                            },
                          ),
                          _buildActionButton(
                            context,
                            'Posture',
                            Icons.camera_alt,
                            () {
                              Navigator.of(context).pushNamed('/posture');
                            },
                          ),
                          _buildActionButton(
                            context,
                            'Challenges',
                            Icons.people,
                            () {
                              Navigator.of(context).pushNamed('/challenges');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on dashboard
              break;
            case 1:
              Navigator.of(context).pushNamed('/workouts');
              break;
            case 2:
              Navigator.of(context).pushNamed('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color, double progress,
      {bool fullWidth = false}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
