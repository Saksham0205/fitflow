import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitflow/config/constants.dart';
import 'package:fitflow/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!.uid, email);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Implement Google Sign-In
      // This is a placeholder for the actual implementation
      throw UnimplementedError('Google Sign-In not implemented yet');
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(String uid, String email) async {
    final userModel = UserModel.fromFirebaseAuth(uid, email);

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(userModel.toFirestore());
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final docSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel updatedUser) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(updatedUser.id)
          .update(updatedUser.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Update user's last active timestamp
  Future<void> updateLastActive(String uid) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'lastActive': Timestamp.now(),
      });
    } catch (e) {
      // Silently fail as this is not critical
      print('Error updating last active: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
