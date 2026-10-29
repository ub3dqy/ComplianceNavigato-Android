import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';

typedef AssessmentsKey = ({String organizationId, int generation});

final assessmentsProvider = FutureProvider.autoDispose
    .family<List<AssessmentDto>, AssessmentsKey>(
      (Ref ref, AssessmentsKey key) =>
          ref.read(repositoryProvider).assessments(key.organizationId),
    );

final class AssessmentsScreen extends ConsumerWidget {
  const AssessmentsScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    AssessmentsKey key,
  ) async {
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            title: const Text('Выполнить оценку?'),
            content: const Text(
              'Результат рассчитает детерминированный движок правил, а не AI.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выполнить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) {
      return;
    }
    try {
      await ref.read(repositoryProvider).runAssessment(organization.id, null);
      ref.invalidate(assessmentsProvider(key));
    } on Object catch (error) {
      if (context.mounted) {
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
    final value = ref.watch(assessmentsProvider(key));
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Оценки'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.invalidate(assessmentsProvider(key)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      floatingActionButton: organization.role == 'viewer'
          ? null
          : FloatingActionButton.extended(
              tooltip: 'Новая оценка',
              onPressed: () => _run(context, ref, organization, key),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Новая оценка'),
            ),
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(assessmentsProvider(key)),
        ),
        data: (List<AssessmentDto> items) => items.isEmpty
            ? const Center(
                child: Text('Оценок пока нет. Сначала заполните анкету.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  final item = items[index];
                  return Padding(
                    padding: EdgeInsets.zero,
                    child: ComplianceDetailCard(
                      leading: const Icon(Icons.rule_outlined),
                      title: Text(
                        'Оценка от ${item.assessmentAsOf?.toLocal().toString().split(' ').first ?? item.createdAt.toLocal().toString().split(' ').first}',
                      ),
                      subtitle: Text(
                        'Версия правил ${item.baselineVersion} · ${humanStatus(item.baselineStatus)} · ${item.results.length} результатов',
                      ),
                      children: <Widget>[
                        const ListTile(
                          leading: Icon(Icons.verified_outlined),
                          title: Text(
                            'Юридический результат сформирован движком правил',
                          ),
                          subtitle: Text(
                            'AI может только объяснять и предлагать изменения.',
                          ),
                        ),
                        ...item.results.expand(
                          (AssessmentResultDto result) => <Widget>[
                            ListTile(
                              leading: Icon(
                                result.severity == 'high'
                                    ? Icons.error_outline
                                    : Icons.info_outline,
                              ),
                              title: Text(result.title),
                              subtitle: Text(
                                '${humanSeverity(result.severity)} · ${humanStatus(result.outcome)}\n${result.explanation}\nИсточников: ${result.sourceSnapshot.length}',
                              ),
                              isThreeLine: true,
                            ),
                            if (result.usedFacts.isNotEmpty)
                              ListTile(
                                leading: const Icon(Icons.checklist_outlined),
                                title: const Text('Использованные факты'),
                                subtitle: Text(
                                  'Движок правил проверил фактов: ${result.usedFacts.length}. Внутренние поля скрыты.',
                                ),
                              ),
                            if (result.sourceSnapshot.isNotEmpty)
                              ListTile(
                                leading: const Icon(Icons.source_outlined),
                                title: const Text('Коды источников'),
                                subtitle: Text(
                                  result.sourceSnapshot
                                      .map(
                                        (Object? source) => source is JsonMap
                                            ? source['code'] ??
                                                  source['source_code'] ??
                                                  'источник'
                                            : source,
                                      )
                                      .join(', '),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
