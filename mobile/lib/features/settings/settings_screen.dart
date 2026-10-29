import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/providers.dart';
import '../../core/network/sanitized_diagnostics.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/routing/questionnaire_exit_guard.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../updates/app_updates.dart';
import '../updates/update_dialog.dart';

final biometricPreferenceProvider = FutureProvider.autoDispose<bool>(
  (Ref ref) => ref.read(preferencesProvider).readBiometricEnabled(),
);

final packageInfoProvider = FutureProvider.autoDispose<PackageInfo>(
  (Ref ref) => PackageInfo.fromPlatform(),
);

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _setBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      if (enabled) {
        final auth = ref.read(localAuthenticationProvider);
        final supported =
            await auth.isDeviceSupported() && await auth.canCheckBiometrics;
        if (!supported) {
          throw StateError('На устройстве нет доступной биометрии.');
        }
      }
      await ref.read(preferencesProvider).writeBiometricEnabled(enabled);
      ref.invalidate(biometricPreferenceProvider);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            title: const Text('Выйти из приложения?'),
            content: const Text(
              'Токены, выбор организации и временные файлы будут удалены.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выйти'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) {
      return;
    }
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    final theme = ref.watch(themeControllerProvider).value ?? ThemeMode.system;
    final biometric = ref.watch(biometricPreferenceProvider);
    final packageInfo = ref.watch(packageInfoProvider);
    final config = ref.watch(appConfigProvider);
    final List<DiagnosticEntry> diagnostics = ref
        .watch(diagnosticsProvider)
        .entries;
    return ComplianceScaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: <Widget>[
          ListTile(
            leading: const ComplianceIconTile(Icons.business_outlined),
            title: Text(organization?.shortName ?? 'Организация не выбрана'),
            subtitle: Text(
              organization == null
                  ? 'Организация не выбрана'
                  : humanRole(organization.role),
            ),
            trailing: const Icon(Icons.swap_horiz),
            onTap: () => context.push('/organizations'),
          ),
          const Divider(),
          Text('Оформление', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<ThemeMode>(
            initialValue: theme,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Тема приложения',
              prefixIcon: Icon(Icons.palette_outlined),
            ),
            items: const <DropdownMenuItem<ThemeMode>>[
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Как в системе'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Светлая')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Тёмная')),
            ],
            onChanged: (ThemeMode? value) {
              if (value != null) {
                ref.read(themeControllerProvider.notifier).setThemeMode(value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text('Безопасность', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Биометрическая блокировка'),
            subtitle: const Text('На этом устройстве'),
            value: biometric.value ?? false,
            onChanged: biometric.isLoading
                ? null
                : (bool value) => _setBiometric(context, ref, value),
          ),
          const Divider(),
          _SettingsDetails(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Диагностика'),
            subtitle: Text(
              '${diagnostics.length} событий без токенов и тела запросов',
            ),
            children: diagnostics.reversed
                .take(20)
                .map(
                  (DiagnosticEntry item) => ListTile(
                    dense: true,
                    title: Text('${item.method} ${item.path}'),
                    subtitle: Text(
                      '${item.timestamp.toLocal()} · ${item.statusCode ?? item.errorCode ?? 'без статуса'}',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          _SettingsDetails(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            children: <Widget>[
              packageInfo.when(
                loading: () => const LinearProgressIndicator(),
                error: (Object _, StackTrace _) =>
                    const ListTile(title: Text('Версия недоступна.')),
                data: (PackageInfo info) => Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('Версия / сборка'),
                      subtitle: Text('${info.version} / ${info.buildNumber}'),
                    ),
                    ListTile(
                      title: const Text('Git commit'),
                      subtitle: SelectableText(config.gitCommitSha),
                    ),
                    ListTile(
                      title: const Text('API schema SHA-256'),
                      subtitle: SelectableText(config.apiSchemaSha256),
                    ),
                    ListTile(
                      title: const Text('Среда / сервер'),
                      subtitle: Text(
                        '${config.environment} / ${config.serverHostname}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ListTile(
            leading: const ComplianceIconTile(Icons.system_update_outlined),
            title: const Text('Обновление приложения'),
            subtitle: const Text('Проверить новую версию'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => showAppUpdates(
              context,
              ref.read(appUpdatesProvider),
              beforeInstall: () async =>
                  await ref
                      .read(questionnaireExitGuardProvider)
                      .confirm
                      ?.call() ??
                  true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

final class _SettingsDetails extends StatelessWidget {
  const _SettingsDetails({
    required this.leading,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: leading,
    title: title,
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: title,
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[?subtitle, ...children],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    ),
  );
}
