import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../core/widgets/organization_save_dialog.dart';
import '../../l10n/app_localizations.dart';

typedef ObligationsKey = ({String organizationId, int generation});
typedef _TaskMutationKey = ({
  String organizationId,
  int generation,
  String taskId,
});

final obligationsProvider = FutureProvider.autoDispose
    .family<
      ({List<ObligationDto> obligations, List<ChecklistItemDto> tasks}),
      ObligationsKey
    >((Ref ref, ObligationsKey key) async {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        ref.read(repositoryProvider).obligations(key.organizationId),
        ref.read(repositoryProvider).checklist(key.organizationId),
      ]);
      return (
        obligations: results[0] as List<ObligationDto>,
        tasks: results[1] as List<ChecklistItemDto>,
      );
    });

final class ObligationsScreen extends ConsumerStatefulWidget {
  const ObligationsScreen({super.key});

  @override
  ConsumerState<ObligationsScreen> createState() => _ObligationsScreenState();
}

final class _ObligationsScreenState extends ConsumerState<ObligationsScreen> {
  String _filter = 'all';
  final _pendingTasks = <_TaskMutationKey>{};

  _TaskMutationKey _taskKey(ObligationsKey key, ChecklistItemDto task) => (
    organizationId: key.organizationId,
    generation: key.generation,
    taskId: task.id,
  );

  bool _canWrite(ObligationsKey key, {String? actor}) {
    if (!mounted) return false;
    final auth = ref.read(authControllerProvider);
    return auth.phase == AuthPhase.authenticated &&
        auth.user != null &&
        (actor == null || auth.user!.id == actor) &&
        ref.read(currentOrganizationProvider)?.role != 'viewer' &&
        isCurrentOrganization(
          ref,
          key.organizationId,
          generation: key.generation,
        );
  }

  bool _matches(String status, String severity) =>
      _filter == 'all' ||
      (_filter == 'important'
          ? status != 'completed' &&
                const <String>{'critical', 'high'}.contains(severity)
          : status == _filter);

  Future<void> _completeObligation(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    ObligationDto obligation,
    ObligationsKey key,
  ) async {
    if (!_canWrite(key)) return;
    final actor = ref.read(authControllerProvider).user!.id;
    final repository = ref.read(repositoryProvider);
    final confirmLabel = AppLocalizations.of(context).confirm;
    if (ModalRoute.of(context)?.isCurrent == false) Navigator.of(context).pop();
    String comment = '';
    bool noEvidence = false;
    ObligationDto current = obligation;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrganizationSaveDialog(
        organizationId: organization.id,
        generation: key.generation,
        title: 'Подтвердить выполнение',
        saveLabel: confirmLabel,
        canSave: () => true,
        fields: (context, setDialogState, enabled) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              enabled: enabled,
              initialValue: comment,
              onChanged: (value) => comment = value,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: noEvidence,
              onChanged: enabled
                  ? (value) => setDialogState(() => noEvidence = value ?? false)
                  : null,
              title: const Text(
                'Подтверждающий файл не требуется или отсутствует',
              ),
            ),
          ],
        ),
        payload: () => {
          'status': 'completed',
          'completion_date': DateUtils.dateOnly(DateTime.now())
              .toIso8601String()
              .substring(0, 10),
          'completion_comment': comment,
          'evidence_absent_confirmed': noEvidence,
        },
        save: (data, requestKey) async {
          await repository.updateObligation(
            organization.id,
            current,
            data,
            idempotencyKey: requestKey,
          );
        },
        reloadVersion: () async {
          final latest = await repository.obligations(organization.id);
          current = latest.singleWhere((item) => item.id == obligation.id);
        },
        afterSave: () async {
          if (!_canWrite(key, actor: actor)) return;
          ref.invalidate(obligationsProvider(key));
          await ref.read(obligationsProvider(key).future);
        },
      ),
    );
  }

  Future<void> _toggleTask(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    ChecklistItemDto task,
    ObligationsKey key,
  ) async {
    final mutationKey = _taskKey(key, task);
    if (!_canWrite(key) || _pendingTasks.contains(mutationKey)) return;
    final actor = ref.read(authControllerProvider).user!.id;
    final repository = ref.read(repositoryProvider);
    setState(() => _pendingTasks.add(mutationKey));
    bool saved = false;
    try {
      await repository.updateTask(organization.id, task, {
        'status': task.status == 'completed' ? 'open' : 'completed',
      });
      saved = true;
      if (_canWrite(key, actor: actor)) {
        ref.invalidate(obligationsProvider(key));
        await ref.read(obligationsProvider(key).future);
      }
    } on Object catch (error) {
      if (context.mounted && _canWrite(key, actor: actor)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Задача сохранена. Не удалось обновить список. Обновите экран.'
                  : safeUiError(error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingTasks.remove(mutationKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrganizationSummaryDto? organization = ref.watch(
      currentOrganizationProvider,
    );
    if (organization == null) {
      return const Center(child: Text('Выберите организацию.'));
    }
    final ObligationsKey key = (
      organizationId: organization.id,
      generation: ref.watch(organizationGenerationProvider),
    );
    final value = ref.watch(obligationsProvider(key));
    final bool canEdit = organization.role != 'viewer';
    return ComplianceScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tasks),
        actions: <Widget>[
          IconButton(
            tooltip: AppLocalizations.of(context).refresh,
            onPressed: () => ref.invalidate(obligationsProvider(key)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(obligationsProvider(key)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(obligationsProvider(key).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: <Widget>[
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  for (final filter in const <(String, String)>[
                    ('all', 'Все'),
                    ('important', 'Важные'),
                    ('needs_review', 'На проверке'),
                    ('completed', 'Выполнены'),
                  ])
                    ChoiceChip(
                      label: Text(filter.$2),
                      selected: _filter == filter.$1,
                      onSelected: (_) => setState(() => _filter = filter.$1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.obligations.isEmpty)
                const _EmptyCard(text: 'Обязанности появятся после оценки.')
              else
                ...data.obligations
                    .where((item) => _matches(item.status, item.severity))
                    .map(
                      (ObligationDto item) => Padding(
                        padding: EdgeInsets.zero,
                        child: ComplianceDetailCard(
                          leading: Icon(
                            item.status == 'completed'
                                ? Icons.check_circle
                                : Icons.pending_actions,
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            '${humanStatus(item.status)} · ${humanSeverity(item.severity)}'
                            '${item.dueDate == null ? '' : ' · до ${item.dueDate}'}',
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(item.description),
                            ),
                            if (item.completionComment.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Комментарий: ${item.completionComment}',
                                ),
                              ),
                            ],
                            if (canEdit &&
                                item.status != 'completed') ...<Widget>[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: () => _completeObligation(
                                    context,
                                    ref,
                                    organization,
                                    item,
                                    key,
                                  ),
                                  icon: const Icon(Icons.done),
                                  label: const Text('Подтвердить выполнение'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              Text('Задачи', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (data.tasks.isEmpty)
                const _EmptyCard(text: 'Задач пока нет.')
              else
                ...data.tasks
                    .where(
                      (task) => _matches(
                        task.status,
                        data.obligations
                                .where((item) => item.id == task.obligationId)
                                .firstOrNull
                                ?.severity ??
                            '',
                      ),
                    )
                    .map(
                      (ChecklistItemDto task) => Card(
                        child: CheckboxListTile(
                          value: task.status == 'completed',
                          onChanged:
                              canEdit &&
                                  !_pendingTasks.contains(_taskKey(key, task))
                              ? (_) => _toggleTask(
                                  context,
                                  ref,
                                  organization,
                                  task,
                                  key,
                                )
                              : null,
                          title: Text(task.title),
                          subtitle: Text(
                            _pendingTasks.contains(_taskKey(key, task))
                                ? 'Сохранение…'
                                : task.dueDate == null
                                ? humanStatus(task.status)
                                : '${humanStatus(task.status)} · до ${task.dueDate}',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
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

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Text(text)),
  );
}
