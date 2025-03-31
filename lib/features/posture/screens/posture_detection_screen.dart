import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fitflow/config/theme.dart';

class PostureDetectionScreen extends StatefulWidget {
  const PostureDetectionScreen({super.key});

  @override
  State<PostureDetectionScreen> createState() => _PostureDetectionScreenState();
}

class _PostureDetectionScreenState extends State<PostureDetectionScreen> {
  bool _isPermissionGranted = false;
  late final Future<void> _future;
  CameraController? _cameraController;
  final _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _postureFeedback;
  bool _isGoodPosture = false;

  @override
  void initState() {
    super.initState();
    _future = _requestCameraPermission();
  }

  @override
  void dispose() {
    _stopCamera();
    _poseDetector.close();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    _isPermissionGranted = status == PermissionStatus.granted;

    if (_isPermissionGranted) {
      await _startCamera();
    }
  }

  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Use the front camera for posture detection
    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (!mounted) return;

    _cameraController!.startImageStream(_processCameraImage);

    setState(() {});
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      await _cameraController!.stopImageStream();
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    final inputImage = _convertCameraImageToInputImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    final poses = await _poseDetector.processImage(inputImage);

    if (poses.isNotEmpty) {
      final painter = PosePainter(
        poses.first,
        Size(image.width.toDouble(), image.height.toDouble()),
        InputImageRotation.rotation0deg,
        CameraLensDirection.front,
      );

      _customPaint = CustomPaint(painter: painter);

      // Analyze posture and provide feedback
      _analyzePosture(poses.first);
    } else {
      _customPaint = null;
      _postureFeedback = 'No pose detected';
      _isGoodPosture = false;
    }

    if (mounted) {
      setState(() {});
    }

    _isBusy = false;
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    // Since we're using ML Kit, we need to convert the camera image to the format it expects
    // This is a simplified version - in a production app, you'd need to handle different image formats
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // For simplicity, we're assuming the first plane contains the image data
    // In a production app, you'd need to handle different image formats properly
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _analyzePosture(Pose pose) {
    // This is a simplified posture analysis
    // In a real app, you would implement more sophisticated algorithms
    // based on the specific exercises and posture requirements

    // Get key landmarks
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rightEar = pose.landmarks[PoseLandmarkType.rightEar];

    // Check if all required landmarks are detected
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftEar == null ||
        rightEar == null) {
      _postureFeedback = 'Cannot analyze posture - some landmarks not detected';
      _isGoodPosture = false;
      return;
    }

    // Check shoulder alignment (horizontal)
    final shoulderDiff = (leftShoulder.y - rightShoulder.y).abs();
    final shoulderThreshold = 20.0; // Threshold for acceptable difference

    // Check hip alignment (horizontal)
    final hipDiff = (leftHip.y - rightHip.y).abs();
    final hipThreshold = 20.0;

    // Check head alignment (vertical with shoulders)
    final leftEarToShoulder = (leftEar.x - leftShoulder.x).abs();
    final rightEarToShoulder = (rightEar.x - rightShoulder.x).abs();
    final earThreshold = 30.0;

    // Determine if posture is good based on these checks
    final isShoulderAligned = shoulderDiff < shoulderThreshold;
    final isHipAligned = hipDiff < hipThreshold;
    final isHeadAligned =
        leftEarToShoulder < earThreshold && rightEarToShoulder < earThreshold;

    _isGoodPosture = isShoulderAligned && isHipAligned && isHeadAligned;

    // Provide feedback
    if (_isGoodPosture) {
      _postureFeedback = 'Good posture! Keep it up!';
    } else {
      if (!isShoulderAligned) {
        _postureFeedback = 'Shoulders not level - try to balance them';
      } else if (!isHipAligned) {
        _postureFeedback = 'Hips not level - try to balance your weight';
      } else if (!isHeadAligned) {
        _postureFeedback = 'Head not aligned - try to keep your head centered';
      } else {
        _postureFeedback = 'Adjust your posture';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview or permission message
              if (!_isPermissionGranted)
                _buildPermissionDenied()
              else if (_cameraController?.value.isInitialized ?? false)
                _buildCameraPreview()
              else
                const Center(child: CircularProgressIndicator()),

              // Posture feedback overlay
              if (_postureFeedback != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: _isGoodPosture
                        ? Colors.green.withOpacity(0.7)
                        : Colors.red.withOpacity(0.7),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _postureFeedback!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_rounded,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera permission is required\nfor posture detection',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await _requestCameraPermission();
              setState(() {});
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / _cameraController!.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraController!),
            if (_customPaint != null) _customPaint!,
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Posture Detection'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This feature uses AI to analyze your posture during exercises.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Tips for best results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Ensure good lighting'),
              Text('• Position your full body in the frame'),
              Text('• Wear fitted clothing for better detection'),
              Text('• Keep a neutral background if possible'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  PosePainter(
    this.pose,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = AppTheme.primaryColor;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = AppTheme.primaryColor;

    // Draw all the landmarks
    pose.landmarks.forEach((type, landmark) {
      canvas.drawCircle(
        _translatePoint(Point(landmark.x, landmark.y), size),
        8,
        dotPaint,
      );
    });

    // Draw connections between landmarks
    _drawLine(canvas, pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
        size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee,
        size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee, size, paint);
    _drawLine(canvas, pose, PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle, size, paint);
  }

  void _drawLine(Canvas canvas, Pose pose, PoseLandmarkType type1,
      PoseLandmarkType type2, Size size, Paint paint) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];

    if (landmark1 != null && landmark2 != null) {
      canvas.drawLine(
        _translatePoint(Point(landmark1.x, landmark1.y), size),
        _translatePoint(Point(landmark2.x, landmark2.y), size),
        paint,
      );
    }
  }

  Offset _translatePoint(Point point, Size size) {
    // Convert the point from the image coordinate system to the canvas coordinate system
    // This is a simplified version - in a production app, you'd need to handle different rotations
    final double x = point.x.toDouble();
    final double y = point.y.toDouble();

    // Handle mirroring for front camera
    final double translateX = cameraLensDirection == CameraLensDirection.front
        ? size.width - (x / imageSize.width * size.width)
        : x / imageSize.width * size.width;

    return Offset(
      translateX,
      y / imageSize.height * size.height,
    );
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.pose != pose;
  }
}
