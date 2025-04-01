import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fitflow/config/theme.dart';
import '../models/pose_template.dart';
import '../services/pose_analysis_service.dart';

class PostureDetectionScreen extends StatefulWidget {
  final PoseTemplate? exerciseTemplate;

  const PostureDetectionScreen({
    super.key,
    this.exerciseTemplate,
  });

  @override
  State<PostureDetectionScreen> createState() => _PostureDetectionScreenState();
}

class _PostureDetectionScreenState extends State<PostureDetectionScreen> with WidgetsBindingObserver {
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
  int _frameCount = 0;
  static const int _processEveryNFrames = 3; // Process every 3rd frame for better performance/accuracy balance
  double _lastDeviation = 0.0;
  ErrorSeverity _currentSeverity = ErrorSeverity.none;
  double _fps = 0.0;
  DateTime _lastProcessedTime = DateTime.now();

  // Current exercise template
  PoseTemplate? _currentTemplate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTemplate = widget.exerciseTemplate;
    _future = _requestCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly manage camera resources
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      ResolutionPreset.medium, // Medium resolution for better performance
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();

      if (!mounted) return;

      _cameraController!.startImageStream(_processCameraImage);

      setState(() {});
    } catch (e) {
      print('Error starting camera: $e');
      // Show error to user
      if (mounted) {
        setState(() {
          _postureFeedback = 'Error initializing camera: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _frameCount++;
    if (_frameCount % _processEveryNFrames != 0) {
      return; // Skip frames for performance
    }

    if (_isBusy) return;
    _isBusy = true;

    // Calculate FPS
    final now = DateTime.now();
    final duration = now.difference(_lastProcessedTime);
    if (duration.inMilliseconds > 0) {
      _fps = 1000 / duration.inMilliseconds * _processEveryNFrames;
    }
    _lastProcessedTime = now;

    try {
      final inputImage = _getInputImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final painter = PosePainter(
          poses.first,
          Size(inputImage.metadata!.size.width, inputImage.metadata!.size.height),
          inputImage.metadata!.rotation,
          _cameraController!.description.lensDirection,
        );

        // Analyze posture and provide feedback
        _analyzePosture(poses.first);

        if (mounted) {
          setState(() {
            _customPaint = CustomPaint(painter: painter);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _customPaint = null;
            _postureFeedback = 'No pose detected';
            _isGoodPosture = false;
          });
        }
      }
    } catch (e) {
      print('Error processing image: $e');
      if (mounted) {
        setState(() {
          _postureFeedback = 'Error processing image';
          _isGoodPosture = false;
        });
      }
    }

    _isBusy = false;
  }

  InputImage? _getInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(
      Platform.isAndroid ? camera.sensorOrientation : 0,
    );
    if (rotation == null) return null;

    // Handle different image formats
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Use the appropriate method based on platform and format
    if (Platform.isAndroid) {
      // For Android, use plane data
      return InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else if (Platform.isIOS) {
      // For iOS, handle BGRA format
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    return null;
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    // For YUV420 format, just use the Y plane for ML Kit
    return planes[0].bytes;
  }

  void _analyzePosture(Pose pose) {
    if (_currentTemplate == null) {
      // Default to general posture analysis if no specific exercise is selected
      _analyzeGeneralPosture(pose);
      return;
    }

    // Analyze pose against current exercise template
    final analysis = PoseAnalysisService.analyzePose(pose, _currentTemplate!);

    setState(() {
      _isGoodPosture = analysis.isCorrectPose;
      _lastDeviation = analysis.maxDeviation;
      _currentSeverity = analysis.severity;

      if (_isGoodPosture) {
        _postureFeedback = 'Good form! Keep it up!';
      } else {
        _postureFeedback = analysis.feedbackMessages.join('\n');

        // Provide haptic feedback based on error severity
        if (_currentSeverity == ErrorSeverity.major) {
          HapticFeedback.heavyImpact();
        } else if (_currentSeverity == ErrorSeverity.minor) {
          HapticFeedback.mediumImpact();
        }
      }
    });
  }

  void _analyzeGeneralPosture(Pose pose) {
    // Get key landmarks
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    // Check if key landmarks are detected
    final missingLandmarks = <String>[];
    if (leftShoulder == null) missingLandmarks.add('left shoulder');
    if (rightShoulder == null) missingLandmarks.add('right shoulder');
    if (leftHip == null) missingLandmarks.add('left hip');
    if (rightHip == null) missingLandmarks.add('right hip');
    if (leftEar == null) missingLandmarks.add('left ear');
    if (rightEar == null) missingLandmarks.add('right ear');

    if (missingLandmarks.isNotEmpty) {
      setState(() {
        _postureFeedback = 'Cannot analyze posture - missing ${missingLandmarks.join(', ')}';
        _isGoodPosture = false;
      });
      return;
    }

    // Calculate posture metrics
    final feedbacks = <String>[];
    var totalSeverity = 0.0;
    var checksFailed = 0;

    // Check shoulder alignment (horizontal)
    final shoulderDiff = (leftShoulder!.y - rightShoulder!.y).abs();
    final shoulderThreshold = 15.0;
    if (shoulderDiff > shoulderThreshold) {
      feedbacks.add('Level your shoulders');
      totalSeverity += shoulderDiff / shoulderThreshold;
      checksFailed++;
    }

    // Check hip alignment (horizontal)
    final hipDiff = (leftHip!.y - rightHip!.y).abs();
    final hipThreshold = 15.0;
    if (hipDiff > hipThreshold) {
      feedbacks.add('Balance your hips');
      totalSeverity += hipDiff / hipThreshold;
      checksFailed++;
    }

    // Check head alignment
    if (nose != null) {
      final shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2;
      final headOffsetX = (nose.x - shoulderMidX).abs();
      final headThreshold = 20.0;

      if (headOffsetX > headThreshold) {
        feedbacks.add('Center your head');
        totalSeverity += headOffsetX / headThreshold;
        checksFailed++;
      }
    }

    // Check if back is straight
    if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
      // Calculate back angle
      final backAngleLeft = _calculateAngle(
        Point(leftShoulder.x, leftShoulder.y),
        Point(leftHip.x, leftHip.y),
        Point(leftHip.x, leftHip.y - 100), // Vertical reference
      );

      final backAngleRight = _calculateAngle(
        Point(rightShoulder.x, rightShoulder.y),
        Point(rightHip.x, rightHip.y),
        Point(rightHip.x, rightHip.y - 100), // Vertical reference
      );

      final avgBackAngle = (backAngleLeft + backAngleRight) / 2;
      final backThreshold = 10.0; // Degrees from vertical

      if (avgBackAngle.abs() > backThreshold) {
        feedbacks.add('Straighten your back');
        totalSeverity += avgBackAngle.abs() / backThreshold;
        checksFailed++;
      }
    }

    // Determine overall posture quality
    setState(() {
      if (feedbacks.isEmpty) {
        _isGoodPosture = true;
        _postureFeedback = 'Good posture! Keep it up!';
        _currentSeverity = ErrorSeverity.none;
      } else {
        _isGoodPosture = false;

        // Calculate average severity
        final avgSeverity = totalSeverity / checksFailed;

        if (avgSeverity > 2.0) {
          _currentSeverity = ErrorSeverity.major;
          HapticFeedback.heavyImpact();
        } else {
          _currentSeverity = ErrorSeverity.minor;
          HapticFeedback.mediumImpact();
        }

        _postureFeedback = feedbacks.join('\n');
      }

      _lastDeviation = checksFailed > 0 ? totalSeverity / checksFailed / 3.0 : 0.0;
    });
  }

  // Calculate angle between three points in degrees
  double _calculateAngle(Point p1, Point p2, Point p3) {
    final angle1 = atan2(p1.y - p2.y, p1.x - p2.x);
    final angle2 = atan2(p3.y - p2.y, p3.x - p2.x);

    var angle = (angle2 - angle1) * (180 / pi);
    if (angle < 0) angle += 360;
    if (angle > 180) angle = 360 - angle;

    return angle;
  }

  Widget _buildPerformanceOverlay() {
    return Positioned(
      top: 60,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'FPS: ${_fps.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Deviation: ${(_lastDeviation * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: _isGoodPosture ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
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

              // Performance overlay
              _buildPerformanceOverlay(),

              // Exercise template info
              if (_currentTemplate != null)
                Positioned(
                  top: 120,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Exercise: ${_currentTemplate!.exerciseName}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

              // Posture feedback overlay
              if (_postureFeedback != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: _isGoodPosture
                        ? Colors.green.withOpacity(0.7)
                        : _currentSeverity == ErrorSeverity.major
                        ? Colors.red.withOpacity(0.7)
                        : Colors.orange.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _postureFeedback!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!_isGoodPosture)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Adjust your form to continue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
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
          const Icon(
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
        child: CameraPreview(_cameraController!),
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

    // Define landmark connections for better visualization
    final connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar],
      [PoseLandmarkType.leftEar, PoseLandmarkType.nose],
      [PoseLandmarkType.rightEar, PoseLandmarkType.nose],
    ];

    // Draw connections between landmarks
    for (final connection in connections) {
      final start = pose.landmarks[connection[0]];
      final end = pose.landmarks[connection[1]];

      if (start != null && end != null) {
        canvas.drawLine(
          _translatePoint(Point(start.x, start.y), size),
          _translatePoint(Point(end.x, end.y), size),
          paint,
        );
      }
    }

    // Draw all the landmarks
    pose.landmarks.forEach((type, landmark) {
      // Use different colors for different body parts for better visibility
      if (type == PoseLandmarkType.nose ||
          type == PoseLandmarkType.leftEye ||
          type == PoseLandmarkType.rightEye ||
          type == PoseLandmarkType.leftEar ||
          type == PoseLandmarkType.rightEar) {
        dotPaint.color = Colors.red;
      } else if (type == PoseLandmarkType.leftShoulder ||
          type == PoseLandmarkType.rightShoulder ||
          type == PoseLandmarkType.leftElbow ||
          type == PoseLandmarkType.rightElbow ||
          type == PoseLandmarkType.leftWrist ||
          type == PoseLandmarkType.rightWrist) {
        dotPaint.color = Colors.blue;
      } else {
        dotPaint.color = AppTheme.primaryColor;
      }

      // Draw landmark point
      canvas.drawCircle(
        _translatePoint(Point(landmark.x, landmark.y), size),
        8,
        dotPaint,
      );
    });
  }

  Offset _translatePoint(Point point, Size size) {
    // Handle scaling between image and canvas size
    double x = point.x.toDouble();
    double y = point.y.toDouble();

    // Handle rotation
    if (rotation == InputImageRotation.rotation90deg) {
      final temp = x;
      x = imageSize.height - y;
      y = temp;
    } else if (rotation == InputImageRotation.rotation270deg) {
      final temp = x;
      x = y;
      y = imageSize.width - temp;
    } else if (rotation == InputImageRotation.rotation180deg) {
      x = imageSize.width - x;
      y = imageSize.height - y;
    }

    // Handle mirroring for front camera
    if (cameraLensDirection == CameraLensDirection.front) {
      x = imageSize.width - x;
    }

    // Scale to the canvas size
    return Offset(
      x / imageSize.width * size.width,
      y / imageSize.height * size.height,
    );
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.pose != pose;
  }
}