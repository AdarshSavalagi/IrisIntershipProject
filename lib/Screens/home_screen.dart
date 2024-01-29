import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'widgets/plotter.dart';

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
    controller = CameraController(
        cameras[_cameraState ? 1 : 0], ResolutionPreset.medium);
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
      await Future.delayed(const Duration(microseconds: 10));
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
    } catch (e) {}
  }

  bool _cameraState = false;
  @override
  void dispose() {
    _isMounted = false; 
    controller.dispose();
    interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    height: MediaQuery.of(context).size.width *
                        controller.value.aspectRatio,
                  ),
                  willChange: true,
                ),
              ],
            )
          : const CircularProgressIndicator(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _cameraState = !_cameraState;
          });
        },
        child: const Icon(Icons.change_circle),
      ),
    );
  }
}
