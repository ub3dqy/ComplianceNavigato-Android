import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'compliance_components.dart';

final class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  int _index() {
    if (location.startsWith('/questionnaire')) {
      return 1;
    }
    if (location.startsWith('/obligations')) {
      return 2;
    }
    if (location.startsWith('/ai')) {
      return 3;
    }
    if (location != '/dashboard') {
      return 4;
    }
    return 0;
  }

  void _go(BuildContext context, int index) {
    const List<String> paths = <String>[
      '/dashboard',
      '/questionnaire',
      '/obligations',
      '/ai',
      '/more',
    ];
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final int index = _index();
    final List<ComplianceNavigationDestination> destinations =
        <ComplianceNavigationDestination>[
          ComplianceNavigationDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_outlined,
            label: strings.dashboard,
          ),
          ComplianceNavigationDestination(
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_outlined,
            label: strings.questionnaire,
          ),
          ComplianceNavigationDestination(
            icon: Icons.task_alt_outlined,
            selectedIcon: Icons.task_alt_outlined,
            label: strings.tasks,
          ),
          ComplianceNavigationDestination(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome_outlined,
            label: strings.assistant,
          ),
          ComplianceNavigationDestination(
            icon: Icons.apps_outlined,
            selectedIcon: Icons.apps,
            label: strings.more,
          ),
        ];
    if (location.startsWith('/organizations')) {
      return child;
    }
    return AdaptiveNavigation(
      selectedIndex: index,
      destinations: destinations,
      onDestinationSelected: (int value) => _go(context, value),
      child: child,
    );
  }
}
