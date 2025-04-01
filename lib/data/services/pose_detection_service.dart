import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PoseDetectionStatus { success, failed, retrying, switchedToVoice }

class PoseDetectionService {
  final PoseDetector _poseDetector;
  int _failureCount = 0;
  final int _maxFailures = 3;
  StreamController<PoseDetectionStatus>? _statusController;
  StreamController<List<PoseLandmark>>? _landmarksController;
  bool _isProcessing = false;

  PoseDetectionService()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: PoseDetectionModel.accurate,
          ),
        );

  Stream<PoseDetectionStatus> get detectionStatus =>
      _statusController?.stream ?? Stream.empty();

  Stream<List<PoseLandmark>> get poseLandmarks =>
      _landmarksController?.stream ?? Stream.empty();

  void initialize() {
    _statusController = StreamController<PoseDetectionStatus>.broadcast();
    _landmarksController = StreamController<List<PoseLandmark>>.broadcast();
  }

  Future<void> processImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image, camera);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        _handleDetectionFailure();
      } else {
        _failureCount = 0;
        _statusController?.add(PoseDetectionStatus.success);
        _landmarksController?.add(poses.first.landmarks.values.toList());
      }
    } catch (e) {
      _handleDetectionFailure();
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _handleDetectionFailure() {
    _failureCount++;
    if (_failureCount >= _maxFailures) {
      _statusController?.add(PoseDetectionStatus.switchedToVoice);
    } else {
      _statusController?.add(PoseDetectionStatus.failed);
    }
  }

  InputImage _convertCameraImageToInputImage(
      CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageRotation = _getImageRotation(camera.sensorOrientation);

    final imageMetadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: imageRotation,
      format: InputImageFormat.bgra8888,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: imageMetadata,
    );
  }

  InputImageRotation _getImageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  bool isPostureCorrect(
      List<PoseLandmark> landmarks, Map<String, dynamic> config) {
    // Implement posture validation logic based on the exercise configuration
    // This is a simplified example - expand based on specific exercise requirements
    try {
      final angles = _calculateJointAngles(landmarks);
      return _validateAngles(angles, config);
    } catch (e) {
      print('Error validating posture: $e');
      return false;
    }
  }

  Map<String, double> _calculateJointAngles(List<PoseLandmark> landmarks) {
    // Calculate relevant joint angles for posture validation
    // This is a simplified example - expand based on requirements
    return {
      'leftElbow': _calculateAngle(
        landmarks[PoseLandmarkType.leftShoulder.index],
        landmarks[PoseLandmarkType.leftElbow.index],
        landmarks[PoseLandmarkType.leftWrist.index],
      ),
      'rightElbow': _calculateAngle(
        landmarks[PoseLandmarkType.rightShoulder.index],
        landmarks[PoseLandmarkType.rightElbow.index],
        landmarks[PoseLandmarkType.rightWrist.index],
      ),
      // Add more joint angles as needed
    };
  }

  double _calculateAngle(
      PoseLandmark point1, PoseLandmark point2, PoseLandmark point3) {
    final vector1 = {
      'x': point1.x - point2.x,
      'y': point1.y - point2.y,
    };
    final vector2 = {
      'x': point3.x - point2.x,
      'y': point3.y - point2.y,
    };

    final dotProduct =
        vector1['x']! * vector2['x']! + vector1['y']! * vector2['y']!;
    final magnitude1 = _calculateMagnitude(vector1);
    final magnitude2 = _calculateMagnitude(vector2);

    return (180 / 3.14159) *
        (3.14159 - acos(dotProduct / (magnitude1 * magnitude2)));
  }

  double _calculateMagnitude(Map<String, double> vector) {
    return sqrt(vector['x']! * vector['x']! + vector['y']! * vector['y']!);
  }

  bool _validateAngles(
      Map<String, double> angles, Map<String, dynamic> config) {
    // Validate calculated angles against the configuration
    // This is a simplified example - expand based on requirements
    for (final entry in config.entries) {
      final angle = angles[entry.key];
      if (angle == null) continue;

      final range = entry.value as Map<String, dynamic>;
      if (angle < range['min'] || angle > range['max']) {
        return false;
      }
    }
    return true;
  }

  void dispose() {
    _statusController?.close();
    _landmarksController?.close();
    _poseDetector.close();
  }
}
