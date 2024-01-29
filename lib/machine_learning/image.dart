import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class YourCameraWidget extends StatefulWidget {
  const YourCameraWidget({super.key});

  @override
  _YourCameraWidgetState createState() => _YourCameraWidgetState();
}

class _YourCameraWidgetState extends State<YourCameraWidget> {
  late CameraController controller;
  late List<CameraDescription> cameras;
  late tfl.Interpreter interpreter;
  List<List<List<double>>> outputData = [];
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    loadModel();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.high);
    await controller.initialize();
    controller.setFlashMode(FlashMode.off);
    setState(() {
      _isMounted = true;
    });
    captureAndProcessImageContinuously();
  }

  Future<void> loadModel() async {
    interpreter = await tfl.Interpreter.fromAsset('assets/ml_model.tflite');
    interpreter.allocateTensors();
  }

  Future<void> captureAndProcessImageContinuously() async {
    while (_isMounted) {
      await captureAndProcessImage();
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> captureAndProcessImage() async {
    try {
      XFile imageFile = await controller.takePicture();
      Uint8List bytes = await imageFile.readAsBytes();
      img.Image originalImage = img.decodeImage(bytes)!;
      img.Image resizedImage =
          img.copyResize(originalImage, width: 192, height: 192);

      List<List<List<num>>> imageMatrix = List.generate(
        resizedImage.height,
        (y) => List.generate(
          resizedImage.width,
          (x) => [
            resizedImage.getPixel(x, y).r,
            resizedImage.getPixel(x, y).g,
            resizedImage.getPixel(x, y).b,
          ],
        ),
      );

      final input = [imageMatrix];
      List<List<List<List<double>>>> output =
          List.filled(1, List.filled(1, List.filled(17, List.filled(3, 0.0))));

      interpreter.run(input, output);
      setState(() {
        outputData = output.first;
      });
    } catch (e) {
      // Handle the error appropriately, such as showing an error message
    }
  }

  @override
  void dispose() {
    _isMounted = false; // Stop continuous processing when disposing the widget
    controller.dispose();
    interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:const  Text('Posture Detection ')),
      body: _isMounted
          ? Stack(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width *
                      controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
                CustomPaint(
                  painter: KeypointsPainter(
                    keypoints: outputData,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                  willChange: true,
                ),
              ],
            )
          : const CircularProgressIndicator(),
    );
  }
}

class KeypointsPainter extends CustomPainter {
  final List<List<List<double>>> keypoints;
  final double width;
  final double height;

  KeypointsPainter({
    required this.keypoints,
    required this.width,
    required this.height,
  });
  final List<List<int>> EDGES = [
    [0, 1],
    [0, 2],
    [1, 3],
    [2, 4],
    [0, 5],
    [0, 6],
    [5, 7],
    [7, 9],
    [6, 8],
    [8, 10],
    [5, 6],
    [5, 11],
    [6, 12],
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (keypoints.isEmpty) {
      return;
    }
    Paint pointPaint = Paint()..color = Colors.green;
    Paint linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0;

    for (var edge in EDGES) {
      int i = edge[0];
      int j = edge[1];
      double confidence1 = keypoints[0][i][2];
      double confidence2 = keypoints[0][j][2];

      if (confidence1 > 0.4 && confidence2 > 0.4) {
        connectKeypoints(canvas, i, j, linePaint, pointPaint);
      }
    }
  }

  void connectKeypoints(
      Canvas canvas, int i, int j, Paint paint, Paint pointPaint) {
    double x1 = keypoints[0][i][1] * width;
    double y1 = keypoints[0][i][0] * height;
    double x2 = keypoints[0][j][1] * width;
    double y2 = keypoints[0][j][0] * height;

    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    canvas.drawCircle(Offset(x1, y1), 3, pointPaint);
    canvas.drawCircle(Offset(x2, y2), 3, pointPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
