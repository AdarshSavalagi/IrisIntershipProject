import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class YourCameraWidget extends StatefulWidget {
  @override
  _YourCameraWidgetState createState() => _YourCameraWidgetState();
}

class _YourCameraWidgetState extends State<YourCameraWidget> {
  late CameraController controller;
  late List<CameraDescription> cameras;
  late tfl.Interpreter interpreter;
  bool _isMounted = false;
  @override
  void initState() {
    super.initState();
    initializeCamera();
    loadModel();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    await controller.initialize();
    setState(() {
    _isMounted = true;
    });
  }

  Future<void> loadModel() async {
    interpreter = await tfl.Interpreter.fromAsset('assets/ml_model.tflite');
    interpreter.allocateTensors();
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

      List<List<List<double>>> outputData = output.first;
      // Process or use the outputData as needed
    } catch (e) {
      print('Error: $e');
      // Handle the error appropriately, such as showing an error message
    }
  }

  @override
  void dispose() {
    controller.dispose();
    interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container(); // Placeholder widget or loading indicator
    }

    return Scaffold(
      body:
          _isMounted ? CameraPreview(controller) : CircularProgressIndicator(),
      floatingActionButton: FloatingActionButton(
        onPressed: captureAndProcessImage,
        child: Icon(Icons.camera),
      ),
    );
  }
}
