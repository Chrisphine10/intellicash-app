import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_controller.dart';

/// How the app looks on this phone.
///
/// Its own screen so it can be reached from Account by every role. It used to
/// be a section inside the group's settings list, which meant a field agent —
/// who never opens that screen — had no way to change the theme at all.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final controller = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionAppearance)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            l10n.appearanceChooseHowIntelliCashLooks,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final option in const [
            (ThemeMode.system, 'Follow the phone', Icons.smartphone_outlined,
                'Matches whatever this phone is set to.'),
            (ThemeMode.light, 'Always light', Icons.light_mode_outlined,
                'Easier to read in bright sunlight.'),
            (ThemeMode.dark, 'Always dark', Icons.dark_mode_outlined,
                'Easier on the eyes indoors and at night.'),
          ])
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(option.$3, size: 20),
                title: Text(option.$2, style: const TextStyle(fontSize: 14)),
                subtitle: Text(option.$4,
                    style: Theme.of(context).textTheme.bodySmall),
                // A full row per option rather than a segmented control: the
                // three choices need a sentence each to be meaningful, and a
                // row is a far larger tap target on a low-end handset.
                trailing: controller.mode == option.$1
                    ? Icon(Icons.check_circle, size: 20, color: AppColors.primary)
                    : null,
                selected: controller.mode == option.$1,
                onTap: () => controller.setMode(option.$1),
              ),
            ),
        ],
      ),
    );
  }
}
