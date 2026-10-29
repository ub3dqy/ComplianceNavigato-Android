import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../core/widgets/organization_save_dialog.dart';

typedef ServicesKey = ({String organizationId, int generation});
typedef ServicesSnapshot = ({
  List<ExternalServiceDto> services,
  List<ProcessingCountryDto> countries,
});

final servicesProvider = FutureProvider.autoDispose
    .family<ServicesSnapshot, ServicesKey>((Ref ref, ServicesKey key) async {
      final results = await Future.wait<Object>(<Future<Object>>[
        ref.read(repositoryProvider).services(key.organizationId),
        ref.read(repositoryProvider).countries(key.organizationId),
      ]);
      return (
        services: results[0] as List<ExternalServiceDto>,
        countries: results[1] as List<ProcessingCountryDto>,
      );
    });

final class ExternalServicesScreen extends ConsumerStatefulWidget {
  const ExternalServicesScreen({super.key});

  @override
  ConsumerState<ExternalServicesScreen> createState() =>
      _ExternalServicesScreenState();
}

final class _ExternalServicesScreenState
    extends ConsumerState<ExternalServicesScreen> {
  bool _countries = false;

  Future<void> _addService(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    ServicesKey key,
  ) async {
    String name = '';
    String purpose = '';
    String categories = '';
    String country = '';
    String type = 'other';
    String location = 'unknown';
    String agreement = 'unknown';
    final repository = ref.read(repositoryProvider);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrganizationSaveDialog(
        organizationId: organization.id,
        generation: key.generation,
        title: 'Добавить сервис',
        canSave: () => name.trim().isNotEmpty,
        fields: (context, setState, enabled) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                enabled: enabled,
                initialValue: name,
                onChanged: (String value) => setState(() => name = value),
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Тип'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'email', child: Text('Почта')),
                  DropdownMenuItem(value: 'cloud', child: Text('Облако')),
                  DropdownMenuItem(value: 'hosting', child: Text('Хостинг')),
                  DropdownMenuItem(value: 'crm', child: Text('CRM')),
                  DropdownMenuItem(value: 'other', child: Text('Другое')),
                ],
                onChanged: !enabled
                    ? null
                    : (String? value) =>
                          setState(() => type = value ?? 'other'),
              ),
              TextFormField(
                enabled: enabled,
                initialValue: purpose,
                onChanged: (String value) => purpose = value,
                decoration: const InputDecoration(labelText: 'Назначение'),
              ),
              TextFormField(
                enabled: enabled,
                initialValue: categories,
                onChanged: (String value) => categories = value,
                decoration: const InputDecoration(
                  labelText: 'Категории данных',
                ),
              ),
              TextFormField(
                enabled: enabled,
                initialValue: country,
                onChanged: (String value) => country = value,
                decoration: const InputDecoration(labelText: 'Основная страна'),
              ),
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Инфраструктура'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'russian', child: Text('Российская')),
                  DropdownMenuItem(
                    value: 'foreign',
                    child: Text('Иностранная'),
                  ),
                  DropdownMenuItem(value: 'unknown', child: Text('Неизвестно')),
                ],
                onChanged: !enabled
                    ? null
                    : (String? value) =>
                          setState(() => location = value ?? 'unknown'),
              ),
              DropdownButtonFormField<String>(
                initialValue: agreement,
                decoration: const InputDecoration(
                  labelText: 'Договор обработки',
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'yes', child: Text('Есть')),
                  DropdownMenuItem(value: 'no', child: Text('Нет')),
                  DropdownMenuItem(value: 'unknown', child: Text('Не знаю')),
                ],
                onChanged: !enabled
                    ? null
                    : (String? value) =>
                          setState(() => agreement = value ?? 'unknown'),
              ),
            ],
          ),
        ),
        payload: () => <String, Object?>{
          'name': name.trim(),
          'service_type': type,
          'purpose': purpose.trim(),
          'data_categories': categories.trim(),
          'recipient_entity': '',
          'primary_country': country.trim(),
          'additional_countries': '',
          'location_status': location,
          'processing_agreement': agreement,
          'terms_url': '',
          'notes': '',
        },
        save: (data, requestKey) async {
          await repository.createService(
            organization.id,
            data,
            idempotencyKey: requestKey,
          );
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
          ref.invalidate(servicesProvider(key));
          await ref.read(servicesProvider(key).future);
        },
      ),
    );
  }

  Future<void> _addCountry(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    ServicesKey key,
  ) async {
    String name = '';
    String purpose = '';
    String basis = '';
    String status = 'unknown';
    final repository = ref.read(repositoryProvider);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrganizationSaveDialog(
        organizationId: organization.id,
        generation: key.generation,
        title: 'Добавить страну',
        canSave: () => name.trim().isNotEmpty,
        fields: (context, setState, enabled) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              enabled: enabled,
              initialValue: name,
              onChanged: (String value) => setState(() => name = value),
              decoration: const InputDecoration(labelText: 'Страна'),
            ),
            TextFormField(
              enabled: enabled,
              initialValue: purpose,
              onChanged: (String value) => purpose = value,
              decoration: const InputDecoration(labelText: 'Цель обработки'),
            ),
            TextFormField(
              enabled: enabled,
              initialValue: basis,
              onChanged: (String value) => basis = value,
              decoration: const InputDecoration(
                labelText: 'Основание передачи',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Статус'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'russian', child: Text('Россия')),
                DropdownMenuItem(
                  value: 'adequate',
                  child: Text('Требует проверки перечня'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Иная')),
                DropdownMenuItem(value: 'unknown', child: Text('Неизвестно')),
              ],
              onChanged: !enabled
                  ? null
                  : (String? value) =>
                        setState(() => status = value ?? 'unknown'),
            ),
          ],
        ),
        payload: () => <String, Object?>{
          'name': name.trim(),
          'status': status,
          'purpose': purpose.trim(),
          'transfer_basis': basis.trim(),
        },
        save: (data, requestKey) async {
          await repository.createCountry(
            organization.id,
            data,
            idempotencyKey: requestKey,
          );
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
          ref.invalidate(servicesProvider(key));
          await ref.read(servicesProvider(key).future);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(currentOrganizationProvider);
    if (organization == null) {
      return const ComplianceScaffold(
        body: Center(child: Text('Выберите организацию.')),
      );
    }
    final key = (
      organizationId: organization.id,
      generation: ref.watch(organizationGenerationProvider),
    );
    final value = ref.watch(servicesProvider(key));
    final canEdit = organization.role != 'viewer';
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Сервисы и страны'),
        actions: <Widget>[
          if (canEdit)
            IconButton(
              tooltip: _countries ? 'Добавить страну' : 'Добавить сервис',
              onPressed: () => _countries
                  ? _addCountry(context, ref, organization, key)
                  : _addService(context, ref, organization, key),
              icon: const Icon(Icons.add),
            )
          else
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => ref.invalidate(servicesProvider(key)),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (error, _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(servicesProvider(key)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(servicesProvider(key).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: <Widget>[
                      for (final entry in <(String, bool)>[
                        ('Сервисы', false),
                        ('Страны', true),
                      ])
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: _countries == entry.$2
                                  ? Theme.of(context).colorScheme.surface
                                  : Colors.transparent,
                            ),
                            onPressed: () =>
                                setState(() => _countries = entry.$2),
                            child: Text(entry.$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _countries
                    ? 'Укажите страны обработки. Применимость требований проверяется отдельно.'
                    : 'Сервисы, которым организация передаёт или поручает обработку сведений.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_countries) ...<Widget>[
                if (data.countries.isEmpty) const Text('Страны не добавлены.'),
                for (final item in data.countries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const ComplianceIconTile(Icons.language_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(item.purpose),
                                  if (item.transferBasis.isNotEmpty)
                                    Text('Основание: ${item.transferBasis}'),
                                  const SizedBox(height: 12),
                                  SemanticStatusBadge(
                                    label: item.needsReview
                                        ? 'Нужна проверка'
                                        : humanStatus(item.status),
                                    status: item.needsReview
                                        ? SemanticStatus.needsHumanReview
                                        : SemanticStatus.information,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ] else ...<Widget>[
                if (data.services.isEmpty) const Text('Сервисы не добавлены.'),
                for (final item in data.services)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const ComplianceIconTile(Icons.cloud_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.purpose.isEmpty
                                        ? 'Назначение не указано'
                                        : item.purpose,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Страна: ${item.primaryCountry.isEmpty ? 'Нужно уточнить' : item.primaryCountry}',
                                  ),
                                  const SizedBox(height: 12),
                                  const SemanticStatusBadge(
                                    label: 'Нужна проверка',
                                    status: SemanticStatus.needsHumanReview,
                                  ),
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text('Сведения о сервисе'),
                                    children: <Widget>[
                                      Text(humanLocation(item.locationStatus)),
                                      Text(
                                        humanAgreement(
                                          item.processingAgreement,
                                        ),
                                      ),
                                      if (item.dataCategories.isNotEmpty)
                                        Text('Данные: ${item.dataCategories}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
