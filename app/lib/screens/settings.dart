import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/locale_provider.dart';
import '../models/engine.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settings)),
      body: ListView(
        children: [
          ListTile(
            title: DropdownButton<Engine>(
              key: const Key('engine_dropdown'),
              value: settings.engine,
              items: const [
                DropdownMenuItem(
                    value: Engine.fastai, child: Text('Default')),
                DropdownMenuItem(value: Engine.openai, child: Text('OpenAI')),
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
        ],
      ),
    );
  }
}
