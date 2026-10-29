import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/network/compliance_repository.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';

typedef DashboardKey = ({String organizationId, int generation});

final dashboardProvider = FutureProvider.autoDispose
    .family<DashboardSnapshot, DashboardKey>(
      (Ref ref, DashboardKey key) =>
          ref.read(repositoryProvider).dashboard(key.organizationId),
    );

final class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    if (organization == null) {
      return const ComplianceScaffold(
        body: EmptyState(
          title: 'Организация не выбрана',
          message: 'Выберите доступную организацию, чтобы увидеть задачи.',
          icon: Icons.business_outlined,
        ),
      );
    }
    final key = (
      organizationId: organization.id,
      generation: ref.watch(organizationGenerationProvider),
    );
    final value = ref.watch(dashboardProvider(key));
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => ref.invalidate(dashboardProvider(key)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: value.when(
        loading: () => const LoadingSkeleton(),
        error: (error, _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(dashboardProvider(key)),
        ),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider(key).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: <Widget>[
              _NextStep(snapshot: snapshot),
              const SizedBox(height: 20),
              _Metrics(snapshot: snapshot),
              const SizedBox(height: 24),
              Text(
                'Работа по шагам',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    for (final (index, item)
                        in <(IconData, String, String, String)>[
                          (
                            Icons.fact_check_outlined,
                            'Анкета',
                            '${snapshot.questionnaire.response?.progressPercent ?? 0}% ответов сохранено',
                            '/questionnaire',
                          ),
                          (
                            Icons.assessment_outlined,
                            'Оценки',
                            'Посмотреть результаты и источники',
                            '/assessments',
                          ),
                          (
                            Icons.task_alt_outlined,
                            'Задачи',
                            'Все текущие действия',
                            '/obligations',
                          ),
                          (
                            Icons.radar_outlined,
                            'Проверка сайта',
                            'Состояние сайта и найденные вопросы',
                            '/scanner',
                          ),
                          (
                            Icons.description_outlined,
                            'Документы',
                            'Черновики и созданные документы',
                            '/documents',
                          ),
                        ].indexed) ...<Widget>[
                      if (index > 0) const Divider(height: 1),
                      ListTile(
                        minTileHeight: 76,
                        leading: ComplianceIconTile(item.$1),
                        title: Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(item.$3),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () =>
                            item.$4 == '/questionnaire' ||
                                item.$4 == '/obligations'
                            ? context.go(item.$4)
                            : context.push(item.$4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _NextStep extends StatelessWidget {
  const _NextStep({required this.snapshot});
  final DashboardSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final complete = snapshot.questionnaire.response?.status == 'completed';
    final progress = snapshot.questionnaire.response?.progressPercent ?? 0;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'СЛЕДУЮЩИЙ ШАГ',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            complete ? 'Проверьте результат оценки' : 'Продолжите анкету',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            complete
                ? 'Ответы сохранены. Посмотрите, какие действия требуют внимания.'
                : 'Несколько вопросов о том, как работает организация.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => complete
                ? context.push('/assessments')
                : context.go('/questionnaire'),
            icon: const Icon(Icons.chevron_right),
            label: Text(complete ? 'Перейти к оценкам' : 'Продолжить'),
          ),
          const SizedBox(height: 12),
          ComplianceProgress(
            value: progress / 100,
            label: 'Ответы сохранены',
            valueLabel: '$progress%',
          ),
        ],
      ),
    );
  }
}

final class _Metrics extends StatelessWidget {
  const _Metrics({required this.snapshot});
  final DashboardSnapshot snapshot;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(16) > 24;
      final values = <(String, int, Color)>[
        (
          'Всего задач',
          snapshot.obligations.length,
          Theme.of(context).colorScheme.onSurface,
        ),
        (
          'Нужна проверка',
          snapshot.obligations
              .where((item) => item.status == 'needs_review')
              .length,
          Theme.of(context).complianceColors.needsHumanReview,
        ),
        (
          'Выполнено',
          snapshot.obligations
              .where((item) => item.status == 'completed')
              .length,
          Theme.of(context).complianceColors.success,
        ),
      ];
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final item in values)
            SizedBox(
              width: large
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${item.$2}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: item.$3,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
