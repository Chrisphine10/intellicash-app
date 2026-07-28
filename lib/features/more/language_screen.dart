import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_controller.dart';

/// Pick the language for this phone. Each option is shown in its own
/// language first, so a speaker recognises it without reading English.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final controller = context.watch<LocaleController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.language)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(l10n.languageSubtitle,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final language in AppLanguage.values)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: controller.language == language
                  ? AppColors.primaryTint
                  : null,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Icon(
                  controller.language == language
                      ? Icons.check_circle
                      : Icons.translate,
                  color: controller.language == language
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 22,
                ),
                title: Text(language.nativeName,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  language.complete
                      ? language.englishName
                      : '${language.englishName} · partly translated',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
                onTap: () => controller.setLanguage(language),
              ),
            ),
          if (!controller.language.complete) ...[
            const SizedBox(height: 6),
            Card(
              color: AppColors.pendingTint,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppColors.pending),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.languageNeedsReview,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
