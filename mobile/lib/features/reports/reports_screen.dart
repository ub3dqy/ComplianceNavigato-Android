import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';

typedef ReportKey = ({String organizationId, int generation});

final reportProvider = FutureProvider.autoDispose.family<JsonMap, ReportKey>(
  (Ref ref, ReportKey key) =>
      ref.read(repositoryProvider).currentReport(key.organizationId),
);

final class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
    String format, {
    required bool share,
  }) async {
    final repository = ref.read(repositoryProvider);
    final transientFiles = ref.read(transientFileServiceProvider);
    final int generation = currentOrganizationGeneration(ref);
    if (share) {
      final accepted =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: const Text('Передать отчёт?'),
              content: Text(
                'Проверьте содержимое и получателя перед передачей ${format.toUpperCase()}. Получателя вы выберете в системном меню.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Продолжить'),
                ),
              ],
            ),
          ) ??
          false;
      if (!accepted ||
          !context.mounted ||
          !isCurrentOrganization(ref, organizationId, generation: generation)) {
        return;
      }
    }
    try {
      final payload = await repository.download(
        'organizations/$organizationId/reports/current/download/$format/',
      );
      if (!context.mounted ||
          !isCurrentOrganization(ref, organizationId, generation: generation)) {
        return;
      }
      final File file = await transientFiles.save(
        payload,
        scope: organizationId,
        fallbackName: 'compliance-report.$format',
        allowedExtensions: <String>{'.$format'},
      );
      if (!context.mounted ||
          !isCurrentOrganization(ref, organizationId, generation: generation)) {
        await transientFiles.discard(file);
        return;
      }
      if (share) {
        await transientFiles.share(
          file,
          isAllowed: () =>
              context.mounted &&
              isCurrentOrganization(
                ref,
                organizationId,
                generation: generation,
              ),
        );
      } else {
        await transientFiles.open(
          file,
          isAllowed: () =>
              context.mounted &&
              isCurrentOrganization(
                ref,
                organizationId,
                generation: generation,
              ),
        );
      }
    } on Object catch (error) {
      if (context.mounted &&
          isCurrentOrganization(ref, organizationId, generation: generation)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final value = ref.watch(reportProvider(key));
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Отчёты'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.invalidate(reportProvider(key)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(reportProvider(key)),
        ),
        data: (report) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const ComplianceIconTile(Icons.assessment_outlined),
                        const Spacer(),
                        SemanticStatusBadge(
                          label: humanStatus(
                            report['status'] ??
                                report['baseline_status'] ??
                                'needs_review',
                          ),
                          status: SemanticStatus.needsHumanReview,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Сводка по организации',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Текущее состояние задач, документов и проверок.',
                    ),
                    for (final entry in const <(String, String)>[
                      ('Задачи', 'obligations'),
                      ('Документы', 'documents'),
                      ('Проверки сайтов', 'scans'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text(entry.$1)),
                            Text(
                              report[entry.$2] is List<Object?>
                                  ? '${(report[entry.$2] as List<Object?>).length}'
                                  : '—',
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      'Нормативная база: ${report['baseline_version'] ?? 'не указана'}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Открыть или передать',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Выберите формат для просмотра. Перед передачей проверьте содержимое.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _download(
                context,
                ref,
                organization.id,
                'html',
                share: false,
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Посмотреть отчёт'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  scrollable: true,
                  title: const Text('Формат отчёта'),
                  content: SizedBox(
                    width: 430,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final format in const <String>[
                          'html',
                          'docx',
                          'json',
                        ])
                          ListTile(
                            title: Text(format.toUpperCase()),
                            trailing: Wrap(
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Открыть ${format.toUpperCase()}',
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _download(
                                      context,
                                      ref,
                                      organization.id,
                                      format,
                                      share: false,
                                    );
                                  },
                                  icon: const Icon(Icons.visibility_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Поделиться ${format.toUpperCase()}',
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _download(
                                      context,
                                      ref,
                                      organization.id,
                                      format,
                                      share: true,
                                    );
                                  },
                                  icon: const Icon(Icons.share_outlined),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Выбрать формат'),
            ),
          ],
        ),
      ),
    );
  }
}
