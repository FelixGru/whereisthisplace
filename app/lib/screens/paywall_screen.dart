import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import '../providers/pro_provider.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const _policyUrl = 'https://felixgru.github.io/whereisthisplace/privacy-policy.html';
  static const _termsUrl = 'https://felixgru.github.io/whereisthisplace/terms-of-use.html';
  
  bool _isLoading = false;
  String? _errorMessage;
  late StreamSubscription _errorSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to IAP errors to show them in UI
    _errorSubscription = context.read<ProProvider>().iapService.errorStream.listen((error) {
      setState(() {
        _errorMessage = error;
      });
    });
  }

  @override
  void dispose() {
    _errorSubscription.cancel();
    super.dispose();
  }

  Future<void> _buyPro() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<ProProvider>().buyProSubscription();
      
      if (kDebugMode) {
        // In debug mode, the purchase succeeds immediately
        // Pop the screen after a short delay to show the success
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Purchase failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<ProProvider>().restorePurchases();
    } catch (e) {
      setState(() {
        _errorMessage = 'Restore failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openPrivacyPolicy() async {
    final uri = Uri.parse(_policyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openTermsOfUse() async {
    final uri = Uri.parse(_termsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProProvider>(
      builder: (context, proProvider, _) {
        // If user becomes Pro, close the paywall
        if (proProvider.isPro) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
          });
        }

    return Scaffold(
          appBar: AppBar(
            title: const Text('Unlock Pro Features'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                const SizedBox(height: 20),
                
                // App Icon/Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'WhereIsThisPlace Pro',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Unlock premium features to get the most out of your photo geolocation experience.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Features List
                _buildFeaturesList(),
                
                const SizedBox(height: 32),
                
                // Pricing Card
                _buildPricingCard(proProvider),
                
                const SizedBox(height: 24),
                
                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Purchase Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _buyPro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Subscribe for ${proProvider.proProductPrice}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Restore Purchases Button
                TextButton(
                  onPressed: _isLoading ? null : _restorePurchases,
                  child: const Text('Restore Purchases'),
                ),
                
                const SizedBox(height: 16),
                
                // Terms and Privacy
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'By subscribing, you agree to our ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    GestureDetector(
                      onTap: _openTermsOfUse,
                      child: Text(
                        'Terms of Service',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      ' and ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                    GestureDetector(
                      onTap: _openPrivacyPolicy,
                      child: Text(
                        'Privacy Policy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '. Subscription automatically renews unless canceled.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      'DEBUG MODE: Purchase will be simulated',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturesList() {
    const features = [
      {
        'icon': Icons.batch_prediction,
        'title': 'Batch Processing',
        'description': 'Process multiple photos at once',
      },
      {
        'icon': Icons.high_quality,
        'title': 'Enhanced Accuracy',
        'description': 'Access to premium AI models',
      },
      {
        'icon': Icons.cloud_upload,
        'title': 'Cloud Sync',
        'description': 'Sync your results across devices',
      },
      {
        'icon': Icons.support_agent,
        'title': 'Priority Support',
        'description': 'Get help when you need it',
      },
    ];

    return Column(
      children: features.map((feature) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      feature['description'] as String,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildPricingCard(ProProvider proProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Pro Monthly',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            proProvider.proProductPrice,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'per month',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
