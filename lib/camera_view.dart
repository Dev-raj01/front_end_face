import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CameraView extends StatefulWidget {
  const CameraView({Key? key}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(cameras[1], ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _captureImage() async {
    try {
      await _initializeControllerFuture;

      final Directory extDir = await getTemporaryDirectory();
      final String dirPath = '${extDir.path}/flutter_camera';
      await Directory(dirPath).create(recursive: true);

      final String filePath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      XFile? imageFile = await _controller.takePicture();
      if (imageFile != null) {
        File savedImage = File(imageFile.path);
        await savedImage.copy(filePath);
        await _sendImageToAPI(savedImage); // Send the image to the API
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image captured and saved')),
        );
      }
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  Future<void> _sendImageToAPI(File imageFile) async {
    final url = Uri.parse('http://192.168.1.19:8000/recognize');
    try {
      var request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      var response = await request.send();
      if (response.statusCode == 200) {
        // Handle successful response from API
        String responseBody = await response.stream.bytesToString();
        _showResponseDialog(responseBody);
      } else {
        // Handle API failure
        print('Failed to upload image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Handle any errors that occurred while uploading
      print('Error uploading image: $e');
    }
  }

  void _showResponseDialog(String responseMessage) {
    // Parse the JSON response
    Map<String, dynamic> jsonResponse = jsonDecode(responseMessage);

    // Extract recognized names from the response
    List<dynamic> recognizedNames = jsonResponse['recognized_names'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('List of Present Students'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: recognizedNames.length,
              itemBuilder: (context, index) {
                String studentName = recognizedNames[index];
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text(studentName),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Preview'),
      ),
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
        onPressed: _captureImage,
        child: const Icon(Icons.camera),
      ),
    );
  }
}
