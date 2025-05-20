import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/result_model.dart';
import '../services/api.dart';
import 'result.dart';

class HomeScreen extends StatefulWidget {
  final XFile? initialImage;

  HomeScreen({super.key, this.initialImage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Api _api = Api();
  XFile? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    setState(() {
      _image = pickedFile;
    });
  }

  Future<void> _locate() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
    });
    final file = File(_image!.path);
    final result = await _api.locate(file);
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_image == null) {
      return const Text('No image selected');
    }
    return kIsWeb
        ? Image.network(_image!.path, height: 200)
        : Image.file(File(_image!.path), height: 200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Pick Image'),
            ),
            const SizedBox(height: 16),
            _buildImagePreview(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _image == null || _loading ? null : _locate,
              child: const Text('Locate'),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
