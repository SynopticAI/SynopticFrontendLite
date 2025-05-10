import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/user_settings.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  void _showLanguageMenu(BuildContext context) async {
    final userSettings = UserSettings();
    final currentLang = await userSettings.getCurrentLanguage();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Language'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: UserSettings.supportedLanguages.entries.map((entry) {
                return ListTile(
                  leading: SvgPicture.asset(
                    'assets/flags/${entry.key}.svg',
                    width: 24,
                    height: 24,
                    placeholderBuilder: (context) => const Icon(Icons.language),
                  ),
                  title: Text(entry.value),
                  selected: currentLang == entry.key,
                  onTap: () async {
                    await userSettings.setUserLanguage(entry.key);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: UserSettings().languageStream,
      builder: (context, snapshot) {
        final languageCode = snapshot.data ?? 'en';
        final languageName = UserSettings.supportedLanguages[languageCode] ?? 'English';
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextButton.icon(
            icon: const Icon(Icons.translate),
            label: Text(languageName),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).appBarTheme.foregroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.withOpacity(0.3))
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _showLanguageMenu(context),
          ),
        );
      },
    );
  }
}