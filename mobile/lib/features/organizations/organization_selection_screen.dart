import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../l10n/app_localizations.dart';
import 'organization_controller.dart';

final class OrganizationSelectionScreen extends ConsumerWidget {
  const OrganizationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OrganizationSelection> selection = ref.watch(
      organizationControllerProvider,
    );
    final canCreate = ref.watch(canCreateOrganizationProvider);
    final value = selection.value;
    final busy = selection.isLoading || value?.isRefreshing == true;
    final error = selection.error ?? value?.refreshError;
    Future<void> reload() =>
        ref.read(organizationControllerProvider.notifier).load();
    return ComplianceScaffold(
      showOrganization: false,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).organizations),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            onPressed: busy ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).logout,
            onPressed: ref.read(authControllerProvider.notifier).logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: <Widget>[
            if (canCreate) ...[
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => context.push('/organizations/new'),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Добавить организацию'),
              ),
              const SizedBox(height: 20),
            ],
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null)
              ErrorState(message: safeUiError(error), onRetry: reload),
            if (!busy && error == null && value != null && value.items.isEmpty)
              EmptyState(
                icon: Icons.business_outlined,
                title: 'Пока нет организаций',
                message: canCreate
                    ? 'Добавьте организацию, чтобы начать работу.'
                    : 'Попросите администратора пилота добавить организацию и предоставить вам доступ.',
              ),
            if (value != null && value.items.isNotEmpty) ...[
              Text(
                'Выберите организацию для работы',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'При переключении откроются только данные выбранной организации.',
              ),
              const SizedBox(height: 16),
              for (final item in value.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    selected: item.id == value.current?.id,
                    child: Card(
                      child: ListTile(
                        minTileHeight: 80,
                        selected: item.id == value.current?.id,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        shape: Theme.of(context).cardTheme.shape,
                        leading: const ComplianceIconTile(
                          Icons.business_outlined,
                        ),
                        title: Text(item.shortName),
                        subtitle: Text(
                          '${item.kind == 'ie' ? 'ИП' : 'ООО'} · ${humanRole(item.role)}${item.id == value.current?.id ? '\nТекущая организация' : ''}',
                        ),
                        trailing: Icon(
                          item.id == value.current?.id
                              ? Icons.check_circle_outline
                              : Icons.chevron_right,
                        ),
                        onTap: busy
                            ? null
                            : () async {
                                final bool selected = await ref
                                    .read(
                                      organizationControllerProvider.notifier,
                                    )
                                    .select(item.id);
                                if (context.mounted && selected) {
                                  context.go('/dashboard');
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Не удалось безопасно сменить организацию.',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
