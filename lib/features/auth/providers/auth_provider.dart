import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    // TODO: Implement Google Sign In
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateUserProfile({
    required String height,
    required String weight,
    required String fitnessLevel,
    required Map<String, dynamic> schedule,
  }) async {
    // TODO: Update user profile in Firestore
  }
}
