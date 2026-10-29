import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../updates/app_updates.dart';
import '../updates/update_dialog.dart';

final class SessionGateScreen extends ConsumerWidget {
  const SessionGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState state = ref.watch(authControllerProvider);
    final bool locked = state.phase == AuthPhase.locked;
    final bool blocked = state.phase == AuthPhase.blocked;
    final AppLocalizations strings = AppLocalizations.of(context);
    return ComplianceScaffold(
      showOrganization: false,
      appBar: AppBar(title: const Text('Соединение и доступ')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    locked
                        ? Icons.fingerprint
                        : blocked
                        ? Icons.gpp_bad_outlined
                        : Icons.cloud_off_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    state.safeError ??
                        (locked
                            ? 'Приложение заблокировано локально.'
                            : strings.offline),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: blocked
                        ? null
                        : locked
                        ? ref.read(authControllerProvider.notifier).unlock
                        : ref
                              .read(authControllerProvider.notifier)
                              .retryRestore,
                    icon: Icon(locked ? Icons.fingerprint : Icons.refresh),
                    label: Text(locked ? strings.unlock : strings.retry),
                  ),
                  if (!locked) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: ref
                          .read(authControllerProvider.notifier)
                          .logout,
                      child: Text(strings.logout),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: () =>
                        showAppUpdates(context, ref.read(appUpdatesProvider)),
                    icon: const Icon(Icons.system_update_outlined),
                    label: const Text('Обновить приложение'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
