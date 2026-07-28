import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../dashboard/dashboard_screen.dart';
import '../loans/loans_screen.dart';
import '../meetings/meetings_screen.dart';
import '../members/members_screen.dart';
import '../more/more_screen.dart';

/// Five-tab shell: everything a group leader does hangs off this bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.grid_view_outlined),
        selectedIcon: const Icon(Icons.grid_view_rounded),
        label: l10n.navDashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_note_outlined),
        selectedIcon: const Icon(Icons.event_note),
        label: l10n.navMeetings,
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: l10n.navMembers,
      ),
      NavigationDestination(
        icon: const Icon(Icons.payments_outlined),
        selectedIcon: const Icon(Icons.payments),
        label: l10n.navLoans,
      ),
      NavigationDestination(
        icon: const Icon(Icons.more_horiz_outlined),
        selectedIcon: const Icon(Icons.more_horiz),
        label: l10n.navMore,
      ),
    ];
    return Scaffold(
      body: switch (_index) {
        0 => const DashboardScreen(),
        1 => const MeetingsScreen(),
        2 => const MembersScreen(),
        3 => const LoansScreen(),
        _ => const MoreScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: destinations,
      ),
    );
  }
}
