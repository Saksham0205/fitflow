import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart' show Axis;
import '../models/pose_template.dart';

class PoseAnalysisService {
  static const double _confidenceThreshold = 0.5;

  /// Analyzes a pose against a template and returns feedback
  static PoseAnalysisResult analyzePose(Pose pose, PoseTemplate template) {
    final List<String> feedbackMessages = [];
    bool isCorrectPose = true;

    // Check angle constraints
    for (final constraint in template.angleConstraints) {
      final angle = calculateAngle(
        pose.landmarks[constraint.joint1]!,
        pose.landmarks[constraint.joint2]!,
        pose.landmarks[constraint.joint3]!,
      );

      if (angle < constraint.minAngle || angle > constraint.maxAngle) {
        feedbackMessages
            .add(template.feedbackMessages[constraint.feedbackKey] ?? '');
        isCorrectPose = false;
      }
    }

    // Check alignment constraints
    for (final constraint in template.alignmentConstraints) {
      final deviation = calculateDeviation(
        pose.landmarks[constraint.point1]!,
        pose.landmarks[constraint.point2]!,
        constraint.axis,
      );

      if (deviation > constraint.maxDeviation) {
        feedbackMessages
            .add(template.feedbackMessages[constraint.feedbackKey] ?? '');
        isCorrectPose = false;
      }
    }

    return PoseAnalysisResult(
      isCorrectPose: isCorrectPose,
      feedbackMessages: feedbackMessages,
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

class PoseAnalysisResult {
  final bool isCorrectPose;
  final List<String> feedbackMessages;

  PoseAnalysisResult({
    required this.isCorrectPose,
    required this.feedbackMessages,
  });
}
