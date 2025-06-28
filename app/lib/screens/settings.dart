import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../providers/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/engine.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _policyUrl =
      'https://felixgru.github.io/whereisthisplace/privacy-policy.html';
  static const _termsUrl =
      'https://felixgru.github.io/whereisthisplace/terms-of-use.html';

  void _openPolicy() {
    launchUrl(Uri.parse(_policyUrl));
  }

  void _openTerms() {
    launchUrl(Uri.parse(_termsUrl));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: ListView(
        children: [
          ListTile(
            title: DropdownButton<Engine>(
              key: const Key('engine_dropdown'),
              value: settings.engine,
              items: const [
                DropdownMenuItem(
                  value: Engine.defaultEngine,
                  child: Text('Default'),
                ),
                DropdownMenuItem(
                  value: Engine.openai,
                  child: Text('OpenAI'),
                ),
              ],
              onChanged: (engine) {
                if (engine != null) settings.setEngine(engine);
              },
            ),
          ),
          ListTile(
            title: DropdownButton<Locale>(
              key: const Key('locale_dropdown'),
              value: localeProvider.locale,
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
                DropdownMenuItem(value: Locale('de'), child: Text('Deutsch')),
              ],
              onChanged: (locale) {
                if (locale != null) localeProvider.setLocale(locale);
              },
            ),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.privacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openPolicy,
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.termsOfUse),
            trailing: const Icon(Icons.open_in_new),
            onTap: _openTerms,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                '© Mapbox, © Mapillary CC-BY-SA 4.0',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
