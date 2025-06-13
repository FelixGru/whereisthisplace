import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/engine.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _policyUrl =
      'https://felixgru.github.io/whereisthisplace/';

  void _openPolicy() {
    launchUrl(Uri.parse(_policyUrl));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settings)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                  title: Text(AppLocalizations.of(context).privacyPolicy),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _openPolicy,
                ),
              ],
            ),
          ),
          // Footer with attribution strings
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                Text(
                  '© Mapbox, © Mapillary CC-BY-SA 4.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
