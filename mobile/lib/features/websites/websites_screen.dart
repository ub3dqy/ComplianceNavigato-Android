import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../core/widgets/organization_save_dialog.dart';
import '../../l10n/app_localizations.dart';

typedef WebsitesKey = ({String organizationId, int generation});

final websitesProvider = FutureProvider.autoDispose
    .family<List<WebsiteDto>, WebsitesKey>(
      (Ref ref, WebsitesKey key) =>
          ref.read(repositoryProvider).websites(key.organizationId),
    );

final class WebsitesScreen extends ConsumerWidget {
  const WebsitesScreen({super.key});

  Future<void> _form(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    WebsitesKey key, {
    WebsiteDto? current,
  }) async {
    String name = current?.name ?? '';
    String url = current?.url ?? '';
    String purpose = current?.purpose ?? '';
    String operator = current?.publicOperatorName ?? '';
    bool authority = current?.scanAuthorityConfirmed ?? false;
    bool active = current?.isActive ?? true;
    String forms = current?.userReportsForms ?? 'unknown';
    String etag = current?.etag ?? '';
    final repository = ref.read(repositoryProvider);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrganizationSaveDialog(
        organizationId: organization.id,
        generation: key.generation,
        title: current == null ? 'Добавить сайт' : 'Изменить сайт',
        canSave: () =>
            name.trim().isNotEmpty && url.trim().isNotEmpty && authority,
        fields: (context, setDialogState, enabled) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                enabled: enabled,
                initialValue: name,
                onChanged: (String value) => setDialogState(() => name = value),
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                enabled: enabled,
                initialValue: url,
                onChanged: (String value) => setDialogState(() => url = value),
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'HTTPS/HTTP адрес',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                enabled: enabled,
                initialValue: purpose,
                onChanged: (String value) => purpose = value,
                decoration: const InputDecoration(labelText: 'Назначение'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                enabled: enabled,
                initialValue: operator,
                onChanged: (String value) => operator = value,
                decoration: const InputDecoration(
                  labelText: 'Оператор на сайте',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: forms,
                decoration: const InputDecoration(
                  labelText: 'Есть формы с данными',
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'yes', child: Text('Да')),
                  DropdownMenuItem(value: 'no', child: Text('Нет')),
                  DropdownMenuItem(value: 'unknown', child: Text('Не знаю')),
                ],
                onChanged: !enabled
                    ? null
                    : (String? value) =>
                          setDialogState(() => forms = value ?? 'unknown'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: !enabled
                    ? null
                    : (bool value) => setDialogState(() => active = value),
                title: const Text('Активный сайт'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: authority,
                onChanged: !enabled
                    ? null
                    : (bool? value) =>
                          setDialogState(() => authority = value ?? false),
                title: const Text(
                  'Подтверждаю полномочия на безопасную проверку сайта',
                ),
              ),
            ],
          ),
        ),
        payload: () => <String, Object?>{
          'name': name.trim(),
          'url': url.trim(),
          'purpose': purpose.trim(),
          'public_operator_name': operator.trim(),
          'is_active': active,
          'user_reports_forms': forms,
          'scan_authority_confirmed': authority,
        },
        save: (data, requestKey) async {
          if (current == null) {
            await repository.createWebsite(
              organization.id,
              data,
              idempotencyKey: requestKey,
            );
          } else {
            await repository.updateWebsite(
              organization.id,
              current.id,
              data,
              etag,
              idempotencyKey: requestKey,
            );
          }
        },
        reloadVersion: current == null
            ? null
            : () async {
                final latest = await repository.websites(organization.id);
                etag = latest.singleWhere((site) => site.id == current.id).etag;
              },
        afterSave: () async {
          if (!context.mounted ||
              !isCurrentOrganization(
                ref,
                organization.id,
                generation: key.generation,
              )) {
            return;
          }
          ref.invalidate(websitesProvider(key));
          await ref.read(websitesProvider(key).future);
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    WebsiteDto website,
    WebsitesKey key,
  ) async {
    final bool accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            title: const Text('Удалить сайт?'),
            content: Text(website.name),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .deleteWebsite(organization.id, website);
      ref.invalidate(websitesProvider(key));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrganizationSummaryDto? organization = ref.watch(
      currentOrganizationProvider,
    );
    if (organization == null) {
      return const Center(child: Text('Выберите организацию.'));
    }
    final WebsitesKey key = (
      organizationId: organization.id,
      generation: ref.watch(organizationGenerationProvider),
    );
    final AsyncValue<List<WebsiteDto>> value = ref.watch(websitesProvider(key));
    final bool canEdit = organization.role != 'viewer';
    return ComplianceScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).websites),
        actions: <Widget>[
          IconButton(
            tooltip: AppLocalizations.of(context).refresh,
            onPressed: () => ref.invalidate(websitesProvider(key)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              tooltip: 'Добавить сайт',
              onPressed: () => _form(context, ref, organization, key),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(websitesProvider(key)),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(websitesProvider(key).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              Text(
                'Сайты организации',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Для проверки сайта нужно подтвердить право на его проверку.',
              ),
              const SizedBox(height: 16),
              if (items.isEmpty) const Text('Сайты ещё не добавлены.'),
              for (final website in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const ComplianceIconTile(Icons.language_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      website.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      website.url,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              if (canEdit)
                                IconButton(
                                  tooltip: 'Изменить сайт',
                                  onPressed: () => _form(
                                    context,
                                    ref,
                                    organization,
                                    key,
                                    current: website,
                                  ),
                                  icon: const Icon(Icons.settings_outlined),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SemanticStatusBadge(
                              label: website.scanAuthorityConfirmed
                                  ? 'Право на проверку подтверждено'
                                  : 'Нужно разрешение',
                              status: website.scanAuthorityConfirmed
                                  ? SemanticStatus.success
                                  : SemanticStatus.needsHumanReview,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              FilledButton.tonalIcon(
                                onPressed: !canEdit
                                    ? null
                                    : () => context.push(
                                        '/scanner?site=${Uri.encodeQueryComponent(website.id)}',
                                      ),
                                icon: const Icon(Icons.radar_outlined),
                                label: const Text('Проверить'),
                              ),
                              OutlinedButton(
                                onPressed: canEdit
                                    ? () => _delete(
                                        context,
                                        ref,
                                        organization,
                                        website,
                                        key,
                                      )
                                    : null,
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
