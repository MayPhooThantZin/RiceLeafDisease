import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(PlantScannerApp(camera: firstCamera));
}

class PlantScannerApp extends StatelessWidget {
  final CameraDescription camera;

  const PlantScannerApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Scanner',
      theme: ThemeData.dark(),
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> detectLeafLikeGreenArea(XFile imageFile) async {
    final bytes = await File(imageFile.path).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return false;

    int greenPixelCount = 0;
    int sampleInterval = 10;

    for (int y = 0; y < image.height; y += sampleInterval) {
      for (int x = 0; x < image.width; x += sampleInterval) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble() / 255.0;
        final g = pixel.g.toDouble() / 255.0;
        final b = pixel.b.toDouble() / 255.0;

        final maxVal = max(r, max(g, b));
        final minVal = min(r, min(g, b));
        final delta = maxVal - minVal;

        double h = 0;
        if (delta != 0) {
          if (maxVal == r) {
            h = 60 * (((g - b) / delta) % 6);
          } else if (maxVal == g) {
            h = 60 * (((b - r) / delta) + 2);
          } else {
            h = 60 * (((r - g) / delta) + 4);
          }
        }
        if (h < 0) h += 360;

        final s = maxVal == 0 ? 0 : delta / maxVal;
        final v = maxVal;

        // Green detection
        if (h >= 30 && h <= 85 && s > 0.4 && v > 0.2) {
          greenPixelCount++;
        }
      }
    }
    double ratio = greenPixelCount / ((image.width / sampleInterval) * (image.height / sampleInterval));
    return ratio > 0.15; // Similar to contour area check
  }

  

  void _scanImage() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      bool result = await detectLeafLikeGreenArea(image);

      if (result) {
        // Show loading spinner
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Analyzing..."),
              ],
            ),
          ),
        );
        // Replace with server IP
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://10.101.155.213:5001/predict'), 
        );
        request.files.add(await http.MultipartFile.fromPath('image', image.path));

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        Navigator.of(context).pop(); // Close the loading dialog

        if (response.statusCode == 200) {
          final decoded = jsonDecode(responseBody);
          final prediction = decoded['prediction'];

          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Prediction Result"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(File(image.path), height: 150),
                  const SizedBox(height: 10),
                  Text("Prediction: $prediction"),
                ],
              ),
            ),
          );
        } else {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text("Error"),
              content: Text("Failed to get prediction"),
            ),
          );
        }
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Scan Result"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.file(File(image.path), height: 150),
                const SizedBox(height: 10),
                const Text("No Leaf Part Found ❌"),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog if open
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plant Scanner')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanImage,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
