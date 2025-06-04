import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/geo_provider.dart';
import '../providers/settings_provider.dart';
import 'result.dart';
import 'settings.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  XFile? _image;
  bool _loading = false;

  @visibleForTesting
  void setImage(XFile image) {
    setState(() {
      _image = image;
    });
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
    final geo = context.read<GeoProvider>();
    final settings = context.read<SettingsProvider>();
    final result = await geo.locate(File(_image!.path), settings.engine);
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
        title: Text(AppLocalizations.of(context).home),
        actions: [
          IconButton(
            key: const Key('settings_button'),
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
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
