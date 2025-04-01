import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fitflow/data/models/workout_model.dart';

class WorkoutRecordingService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  CameraController? _cameraController;
  bool _isRecording = false;

  WorkoutRecordingService()
      : _firestore = FirebaseFirestore.instance,
        _storage = FirebaseStorage.instance;

  Future<void> initializeCamera(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController?.initialize();
    } catch (e) {
      throw Exception('Failed to initialize camera: $e');
    }
  }

  Future<void> startRecording(String userId, String workoutId) async {
    if (_cameraController == null || _isRecording) return;

    try {
      await _cameraController?.startVideoRecording();
      _isRecording = true;
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  Future<String> stopRecording(String userId, String workoutId) async {
    if (_cameraController == null || !_isRecording) {
      throw Exception('No active recording');
    }

    try {
      final videoFile = await _cameraController?.stopVideoRecording();
      _isRecording = false;

      // Upload video to Firebase Storage
      final videoUrl =
          await _uploadVideo(userId, workoutId, File(videoFile!.path));

      // Save metadata to Firestore
      await _saveRecordingMetadata(
        userId: userId,
        workoutId: workoutId,
        videoUrl: videoUrl,
      );

      return videoUrl;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  Future<String> _uploadVideo(
      String userId, String workoutId, File videoFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'workouts/$userId/$workoutId/recording_$timestamp.mp4';
    final ref = _storage.ref().child(path);

    try {
      await ref.putFile(videoFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<void> _saveRecordingMetadata({
    required String userId,
    required String workoutId,
    required String videoUrl,
  }) async {
    final metadata = {
      'userId': userId,
      'workoutId': workoutId,
      'videoUrl': videoUrl,
      'recordedAt': FieldValue.serverTimestamp(),
      'duration': await _getVideoDuration(videoUrl),
    };

    try {
      await _firestore.collection('workout_recordings').add(metadata);
    } catch (e) {
      throw Exception('Failed to save recording metadata: $e');
    }
  }

  Future<int> _getVideoDuration(String videoUrl) async {
    // Implement video duration calculation
    // This is a placeholder - you'll need to use a video player plugin
    // to get the actual duration
    return 0;
  }

  Future<List<Map<String, dynamic>>> getWorkoutRecordings(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('workout_recordings')
          .where('userId', isEqualTo: userId)
          .orderBy('recordedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch workout recordings: $e');
    }
  }

  void dispose() {
    _cameraController?.dispose();
  }
}
