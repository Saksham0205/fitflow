import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart' show Axis;
import '../models/pose_template.dart';

class PoseAnalysisService {
  static const double _confidenceThreshold = 0.5;
  static const double _minorErrorThreshold =
      0.15; // 15% deviation for minor errors
  static const double _majorErrorThreshold =
      0.25; // 25% deviation for major errors

  /// Analyzes a pose against a template and returns feedback with error severity
  static PoseAnalysisResult analyzePose(Pose pose, PoseTemplate template) {
    final List<String> feedbackMessages = [];
    bool isCorrectPose = true;
    double maxDeviation = 0.0;
    ErrorSeverity severity = ErrorSeverity.none;

    // Check angle constraints
    for (final constraint in template.angleConstraints) {
      final angle = calculateAngle(
        pose.landmarks[constraint.joint1]!,
        pose.landmarks[constraint.joint2]!,
        pose.landmarks[constraint.joint3]!,
      );

      final targetAngle = (constraint.minAngle + constraint.maxAngle) / 2;
      final allowedDeviation = (constraint.maxAngle - constraint.minAngle) / 2;
      final currentDeviation = (angle - targetAngle).abs() / allowedDeviation;

      maxDeviation = max(maxDeviation, currentDeviation);

      if (currentDeviation > _minorErrorThreshold) {
        final message = template.feedbackMessages[constraint.feedbackKey] ?? '';
        feedbackMessages.add(message);
        isCorrectPose = false;

        if (currentDeviation > _majorErrorThreshold) {
          severity = ErrorSeverity.major;
        } else if (severity != ErrorSeverity.major) {
          severity = ErrorSeverity.minor;
        }
      }
    }

    // Check alignment constraints
    for (final constraint in template.alignmentConstraints) {
      final deviation = calculateDeviation(
        pose.landmarks[constraint.point1]!,
        pose.landmarks[constraint.point2]!,
        constraint.axis,
      );

      final currentDeviation = deviation / constraint.maxDeviation;
      maxDeviation = max(maxDeviation, currentDeviation);

      if (currentDeviation > _minorErrorThreshold) {
        final message = template.feedbackMessages[constraint.feedbackKey] ?? '';
        feedbackMessages.add(message);
        isCorrectPose = false;

        if (currentDeviation > _majorErrorThreshold) {
          severity = ErrorSeverity.major;
        } else if (severity != ErrorSeverity.major) {
          severity = ErrorSeverity.minor;
        }
      }
    }

    return PoseAnalysisResult(
      isCorrectPose: isCorrectPose,
      feedbackMessages: feedbackMessages,
      severity: severity,
      maxDeviation: maxDeviation,
    );
  }

  /// Calculates the angle between three points in degrees
  static double calculateAngle(
      PoseLandmark point1, PoseLandmark point2, PoseLandmark point3) {
    if (point1.likelihood < _confidenceThreshold ||
        point2.likelihood < _confidenceThreshold ||
        point3.likelihood < _confidenceThreshold) {
      return 0;
    }

    final vector1 = Point(point1.x - point2.x, point1.y - point2.y);
    final vector2 = Point(point3.x - point2.x, point3.y - point2.y);

    final dotProduct = vector1.x * vector2.x + vector1.y * vector2.y;
    final magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y);
    final magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y);

    final angle = acos(dotProduct / (magnitude1 * magnitude2));
    return angle * 180 / pi;
  }

  /// Calculates deviation from axis alignment
  static double calculateDeviation(
      PoseLandmark point1, PoseLandmark point2, Axis axis) {
    if (point1.likelihood < _confidenceThreshold ||
        point2.likelihood < _confidenceThreshold) {
      return double.infinity;
    }

    switch (axis) {
      case Axis.horizontal:
        return (point1.y - point2.y).abs();
      case Axis.vertical:
        return (point1.x - point2.x).abs();
    }
  }

  /// Creates a pose template for a specific exercise
  static PoseTemplate createSquatTemplate() {
    return PoseTemplate(
      exerciseId: 'squat',
      exerciseName: 'Squat',
      keypoints: [],
      angleConstraints: [
        AngleConstraint(
          joint1: PoseLandmarkType.leftHip,
          joint2: PoseLandmarkType.leftKnee,
          joint3: PoseLandmarkType.leftAnkle,
          minAngle: 90,
          maxAngle: 140,
          feedbackKey: 'kneeAngle',
        ),
        AngleConstraint(
          joint1: PoseLandmarkType.rightHip,
          joint2: PoseLandmarkType.rightKnee,
          joint3: PoseLandmarkType.rightAnkle,
          minAngle: 90,
          maxAngle: 140,
          feedbackKey: 'kneeAngle',
        ),
      ],
      alignmentConstraints: [
        AlignmentConstraint(
          point1: PoseLandmarkType.leftShoulder,
          point2: PoseLandmarkType.rightShoulder,
          axis: Axis.horizontal,
          maxDeviation: 20.0,
          feedbackKey: 'shoulderAlignment',
        ),
      ],
      feedbackMessages: {
        'kneeAngle': 'Bend your knees more, keep them aligned with your toes',
        'shoulderAlignment': 'Keep your shoulders level and back straight',
      },
    );
  }

  /// Creates a pose template for push-ups
  static PoseTemplate createPushUpTemplate() {
    return PoseTemplate(
      exerciseId: 'pushup',
      exerciseName: 'Push-up',
      keypoints: [],
      angleConstraints: [
        AngleConstraint(
          joint1: PoseLandmarkType.leftShoulder,
          joint2: PoseLandmarkType.leftElbow,
          joint3: PoseLandmarkType.leftWrist,
          minAngle: 80,
          maxAngle: 110,
          feedbackKey: 'elbowAngle',
        ),
      ],
      alignmentConstraints: [
        AlignmentConstraint(
          point1: PoseLandmarkType.leftShoulder,
          point2: PoseLandmarkType.leftHip,
          axis: Axis.vertical,
          maxDeviation: 15.0,
          feedbackKey: 'backAlignment',
        ),
      ],
      feedbackMessages: {
        'elbowAngle': 'Keep your elbows at 90 degrees',
        'backAlignment': 'Maintain a straight back, don\'t sag in the middle',
      },
    );
  }
}

enum ErrorSeverity {
  none,
  minor,
  major,
}

class PoseAnalysisResult {
  final bool isCorrectPose;
  final List<String> feedbackMessages;
  final ErrorSeverity severity;
  final double maxDeviation;

  PoseAnalysisResult({
    required this.isCorrectPose,
    required this.feedbackMessages,
    this.severity = ErrorSeverity.none,
    this.maxDeviation = 0.0,
  });
}
