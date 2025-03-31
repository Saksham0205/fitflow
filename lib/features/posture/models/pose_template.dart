import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart' show Axis;

class PoseTemplate {
  final String exerciseId;
  final String exerciseName;
  final List<PoseKeypoint> keypoints;
  final List<AngleConstraint> angleConstraints;
  final List<AlignmentConstraint> alignmentConstraints;
  final Map<String, String> feedbackMessages;

  PoseTemplate({
    required this.exerciseId,
    required this.exerciseName,
    required this.keypoints,
    required this.angleConstraints,
    required this.alignmentConstraints,
    required this.feedbackMessages,
  });

  factory PoseTemplate.fromMap(Map<String, dynamic> data) {
    return PoseTemplate(
      exerciseId: data['exerciseId'],
      exerciseName: data['exerciseName'],
      keypoints: (data['keypoints'] as List)
          .map((k) => PoseKeypoint.fromMap(k))
          .toList(),
      angleConstraints: (data['angleConstraints'] as List)
          .map((a) => AngleConstraint.fromMap(a))
          .toList(),
      alignmentConstraints: (data['alignmentConstraints'] as List)
          .map((a) => AlignmentConstraint.fromMap(a))
          .toList(),
      feedbackMessages: Map<String, String>.from(data['feedbackMessages']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'keypoints': keypoints.map((k) => k.toMap()).toList(),
      'angleConstraints': angleConstraints.map((a) => a.toMap()).toList(),
      'alignmentConstraints':
          alignmentConstraints.map((a) => a.toMap()).toList(),
      'feedbackMessages': feedbackMessages,
    };
  }
}

class PoseKeypoint {
  final PoseLandmarkType type;
  final double x;
  final double y;
  final double z;
  final double confidence;

  PoseKeypoint({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  factory PoseKeypoint.fromMap(Map<String, dynamic> data) {
    return PoseKeypoint(
      type: PoseLandmarkType.values.firstWhere(
        (t) => t.toString() == data['type'],
        orElse: () => PoseLandmarkType.nose,
      ),
      x: data['x'].toDouble(),
      y: data['y'].toDouble(),
      z: data['z'].toDouble(),
      confidence: data['confidence'].toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'x': x,
      'y': y,
      'z': z,
      'confidence': confidence,
    };
  }
}

class AngleConstraint {
  final PoseLandmarkType joint1;
  final PoseLandmarkType joint2;
  final PoseLandmarkType joint3;
  final double minAngle;
  final double maxAngle;
  final String feedbackKey;

  AngleConstraint({
    required this.joint1,
    required this.joint2,
    required this.joint3,
    required this.minAngle,
    required this.maxAngle,
    required this.feedbackKey,
  });

  factory AngleConstraint.fromMap(Map<String, dynamic> data) {
    return AngleConstraint(
      joint1: PoseLandmarkType.values.firstWhere(
        (t) => t.toString() == data['joint1'],
        orElse: () => PoseLandmarkType.nose,
      ),
      joint2: PoseLandmarkType.values.firstWhere(
        (t) => t.toString() == data['joint2'],
        orElse: () => PoseLandmarkType.nose,
      ),
      joint3: PoseLandmarkType.values.firstWhere(
        (t) => t.toString() == data['joint3'],
        orElse: () => PoseLandmarkType.nose,
      ),
      minAngle: data['minAngle'].toDouble(),
      maxAngle: data['maxAngle'].toDouble(),
      feedbackKey: data['feedbackKey'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'joint1': joint1.toString(),
      'joint2': joint2.toString(),
      'joint3': joint3.toString(),
      'minAngle': minAngle,
      'maxAngle': maxAngle,
      'feedbackKey': feedbackKey,
    };
  }
}

class AlignmentConstraint {
  final PoseLandmarkType point1;
  final PoseLandmarkType point2;
  final Axis axis;
  final double maxDeviation;
  final String feedbackKey;

  AlignmentConstraint({
    required this.point1,
    required this.point2,
    required this.axis,
    required this.maxDeviation,
    required this.feedbackKey,
  });

  factory AlignmentConstraint.fromMap(Map<String, dynamic> data) {
    return AlignmentConstraint(
      point1: PoseLandmarkType.values.firstWhere(
        (t) => t.toString() == data['point1'],
        orElse: () => PoseLandmarkType.nose,
      ),
      point2: PoseLandmarkType.values.firstWhere(
        (t) => t.toString() == data['point2'],
        orElse: () => PoseLandmarkType.nose,
      ),
      axis: Axis.values.firstWhere(
        (a) => a.toString() == data['axis'],
        orElse: () => Axis.vertical,
      ),
      maxDeviation: data['maxDeviation'].toDouble(),
      feedbackKey: data['feedbackKey'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'point1': point1.toString(),
      'point2': point2.toString(),
      'axis': axis.toString(),
      'maxDeviation': maxDeviation,
      'feedbackKey': feedbackKey,
    };
  }
}
