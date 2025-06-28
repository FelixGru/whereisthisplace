import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/geo_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/pro_provider.dart';
import 'paywall_screen.dart';
import 'result.dart';
import 'settings.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    
    try {
      final geo = context.read<GeoProvider>();
      final engine = context.read<SettingsProvider>().engine;
      print('🚀 Starting location request with engine: ${engine.name}');
      
      final result = await geo.locate(File(_image!.path), engine);
      
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      
      print('🚀 Location result: lat=${result.latitude}, lon=${result.longitude}, confidence=${result.confidence}');
      
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      print('❌ Location error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to get location: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _batchFeature() {
    if (context.read<ProProvider>().isPro) {
      // Pro users can access batch feature
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Batch Processing'),
          content: const Text('Batch processing feature is now available! This would allow you to process multiple photos at once.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Non-pro users see paywall
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Batch feature'),
          content: Text('This feature is available in Pro version.'),
        ),
      );
    }
  }



  Widget _buildImagePreview() {
    if (_image == null) {
      return const Text('No image selected');
    }
    return kIsWeb
        ? Image.network(_image!.path, height: 200)
        : Image.file(File(_image!.path), height: 200);
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'WhereIsThisPlace',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.location_on, size: 48),
      children: [
        const Text('AI-powered photo geolocation app that helps you discover where photos were taken.'),
        const SizedBox(height: 16),
        const Text('Key Features:'),
        const Text('• Photos deleted within 60 seconds'),
        const Text('• Optional AI descriptions (opt-in)'),
        const Text('• Privacy-focused design'),
        const SizedBox(height: 16),
        TextButton.icon(
          icon: const Icon(Icons.privacy_tip),
          label: const Text('Privacy Policy'),
          onPressed: () {
            launchUrl(Uri.parse('https://felixgru.github.io/whereisthisplace/'));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.home),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
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
            const SizedBox(height: 16),
            Consumer<ProProvider>(
              builder: (context, pro, _) {
                if (pro.isPro) {
                  // Show batch button for Pro users
                  return ElevatedButton(
                    onPressed: _batchFeature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.batch_prediction),
                        SizedBox(width: 8),
                        Text('Batch Process'),
                      ],
                    ),
                  );
                }
                // Show "Unlock Pro" button for non-Pro users
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaywallScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock),
                      SizedBox(width: 8),
                      Text('Unlock Pro'),
                    ],
                  ),
                );
              },
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
