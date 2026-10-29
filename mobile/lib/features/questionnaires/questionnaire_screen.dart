import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/routing/questionnaire_exit_guard.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../l10n/app_localizations.dart';

final class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

final class _QuestionnaireScreenState
    extends ConsumerState<QuestionnaireScreen> {
  CurrentQuestionnaireDto? _current;
  QuestionnaireResponseDto? _response;
  final Map<String, Object?> _answers = <String, Object?>{};
  bool _dirty = false;
  bool _saving = false;
  bool _loading = false;
  int _index = 0;
  String? _error;
  String? _loadedOrganizationId;
  int? _loadedGeneration;
  int _loadSerial = 0;

  bool get _busy => _saving || _loading;

  bool _sameContext(String id, int generation) =>
      mounted &&
      _loadedOrganizationId == id &&
      _loadedGeneration == generation &&
      isCurrentOrganization(ref, id, generation: generation);

  late final QuestionnaireExitGuard _exitGuard;
  late final Future<bool> Function() _exitCallback;
  Future<bool>? _leaveDecision;
  int _answerRevision = 0;

  @override
  void initState() {
    super.initState();
    _exitGuard = ref.read(questionnaireExitGuardProvider);
    _exitCallback = _confirmLeave;
    _exitGuard.confirm = _exitCallback;
  }

  @override
  void dispose() {
    if (identical(_exitGuard.confirm, _exitCallback)) _exitGuard.confirm = null;
    super.dispose();
  }

  void _activateOrganization(String? id, int generation) {
    _loadedOrganizationId = id;
    _loadedGeneration = generation;
    _loadSerial++;
    _current = null;
    _response = null;
    _answers.clear();
    _dirty = false;
    _saving = false;
    _loading = false;
    _index = 0;
    _error = null;
    if (id != null) {
      Future<void>.microtask(
        () => _load(organizationId: id, generation: generation),
      );
    }
  }

  Future<void> _load({
    bool preserveAnswers = false,
    String? organizationId,
    int? generation,
  }) async {
    final String? id = organizationId ?? _loadedOrganizationId;
    final int? contextGeneration = generation ?? _loadedGeneration;
    if (id == null ||
        contextGeneration == null ||
        !_sameContext(id, contextGeneration)) {
      return;
    }
    final request = ++_loadSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final CurrentQuestionnaireDto value = await ref
          .read(repositoryProvider)
          .currentQuestionnaire(id);
      if (!_sameContext(id, contextGeneration) || request != _loadSerial) {
        return;
      }
      setState(() {
        _current = value;
        _response = value.response;
        if (!preserveAnswers) {
          _answerRevision++;
          _answers
            ..clear()
            ..addEntries(
              value.response?.answers.map(
                    (AnswerDto item) => MapEntry<String, Object?>(
                      item.questionCode,
                      item.value,
                    ),
                  ) ??
                  const Iterable<MapEntry<String, Object?>>.empty(),
            );
          _dirty = false;
        }
        _index = _index.clamp(0, (_visibleQuestions.length - 1).clamp(0, 9999));
      });
    } on Object catch (error) {
      if (_sameContext(id, contextGeneration) && request == _loadSerial) {
        setState(() => _error = safeUiError(error));
      }
    } finally {
      if (_sameContext(id, contextGeneration) && request == _loadSerial) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _start() async {
    final generation = _loadedGeneration;
    final OrganizationSummaryDto? organization = ref.read(
      currentOrganizationProvider,
    );
    if (organization == null ||
        generation == null ||
        !_sameContext(organization.id, generation) ||
        organization.role == 'viewer' ||
        _busy) {
      return;
    }
    setState(() => _saving = true);
    try {
      final QuestionnaireResponseDto response = await ref
          .read(repositoryProvider)
          .startQuestionnaire(organization.id);
      if (_sameContext(organization.id, generation)) {
        setState(() {
          _response = response;
          _current = CurrentQuestionnaireDto(
            response: response,
            version: response.version,
          );
        });
      }
    } on Object catch (error) {
      if (_sameContext(organization.id, generation)) {
        setState(() => _error = safeUiError(error));
      }
    } finally {
      if (_sameContext(organization.id, generation)) {
        setState(() => _saving = false);
      }
    }
  }

  List<QuestionDto> get _visibleQuestions {
    final List<QuestionDto> questions =
        _current?.version?.questions ?? const <QuestionDto>[];
    return questions.where(_isVisible).toList(growable: false);
  }

  bool _isVisible(QuestionDto question) {
    final JsonMap condition = question.condition;
    if (condition.isEmpty) {
      return true;
    }
    final String? code = condition['question'] as String?;
    if (code == null) {
      return false;
    }
    final Object? current = _answers[code];
    if (condition.containsKey('eq')) {
      return current == condition['eq'];
    }
    final Object? allowed = condition['in'];
    if (allowed is List<Object?>) {
      return allowed.contains(current);
    }
    if (condition.containsKey('contains') && current is List<Object?>) {
      return current.contains(condition['contains']);
    }
    return false;
  }

  void _setAnswer(String code, Object? value) {
    if (_busy || ref.read(currentOrganizationProvider)?.role == 'viewer') {
      return;
    }
    setState(() {
      _answers[code] = value;
      _dirty = true;
      final int max = (_visibleQuestions.length - 1).clamp(0, 9999);
      _index = _index.clamp(0, max);
    });
  }

  Future<bool> _save({required bool complete}) async {
    final generation = _loadedGeneration;
    final OrganizationSummaryDto? organization = ref.read(
      currentOrganizationProvider,
    );
    final QuestionnaireResponseDto? response = _response;
    if (organization == null ||
        generation == null ||
        !_sameContext(organization.id, generation) ||
        response == null ||
        organization.role == 'viewer' ||
        _busy) {
      return false;
    }
    bool succeeded = false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final QuestionnaireResponseDto saved = await ref
          .read(repositoryProvider)
          .saveQuestionnaire(
            organizationId: organization.id,
            response: response,
            answers: Map<String, Object?>.from(_answers),
            complete: complete,
          );
      if (mounted && _sameContext(organization.id, generation)) {
        setState(() {
          _response = saved;
          _current = CurrentQuestionnaireDto(
            response: saved,
            version: saved.version,
          );
          _dirty = false;
        });
        succeeded = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(complete ? 'Анкета завершена.' : 'Ответы сохранены.'),
          ),
        );
      }
    } on AppError catch (error) {
      if (error.kind == AppErrorKind.conflict &&
          mounted &&
          _sameContext(organization.id, generation)) {
        final bool refreshVersion =
            await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                scrollable: true,
                title: const Text('Данные изменились'),
                content: const Text(
                  'Обновить версию с сервера, сохранив введённые ответы на экране? '
                  'После этого повторите сохранение вручную.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Не сейчас'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Обновить версию'),
                  ),
                ],
              ),
            ) ??
            false;
        if (refreshVersion && _sameContext(organization.id, generation)) {
          await _load(
            preserveAnswers: true,
            organizationId: organization.id,
            generation: generation,
          );
        }
      } else if (_sameContext(organization.id, generation)) {
        setState(() => _error = error.safeMessage);
      }
    } on Object catch (error) {
      if (_sameContext(organization.id, generation)) {
        setState(() => _error = safeUiError(error));
      }
    } finally {
      if (_sameContext(organization.id, generation)) {
        setState(() => _saving = false);
      }
    }
    return succeeded;
  }

  Future<bool> _confirmLeave() {
    if (!mounted || !_dirty) return Future<bool>.value(!_saving);
    return _leaveDecision ??= _askLeave().whenComplete(
      () => _leaveDecision = null,
    );
  }

  Future<bool> _askLeave() async {
    if (_saving) return false;
    final id = _loadedOrganizationId;
    final generation = _loadedGeneration;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Несохранённые изменения'),
        content: Text(AppLocalizations.of(context).unsavedWarning),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Остаться'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Уйти без сохранения'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Сохранить и перейти'),
          ),
        ],
      ),
    );
    if (id == null ||
        generation == null ||
        !_sameContext(id, generation) ||
        choice == null ||
        choice == 'stay') {
      return false;
    }
    if (choice == 'save') return _save(complete: false);
    return choice == 'discard';
  }

  Future<void> _refresh() async {
    if (_busy) return;
    final id = _loadedOrganizationId;
    final generation = _loadedGeneration;
    if (id != null &&
        generation != null &&
        await _confirmLeave() &&
        !_busy &&
        _sameContext(id, generation)) {
      await _load(organizationId: id, generation: generation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(currentOrganizationProvider);
    final canEdit = organization != null && organization.role != 'viewer';
    final generation = ref.watch(organizationGenerationProvider);
    if (_loadedOrganizationId != organization?.id ||
        _loadedGeneration != generation) {
      _activateOrganization(organization?.id, generation);
    }
    final questions = _visibleQuestions;
    Widget body;
    if (organization == null) {
      body = const EmptyState(
        title: 'Организация не выбрана',
        message: 'Выберите организацию, чтобы продолжить.',
        icon: Icons.business_outlined,
      );
    } else if (_current == null && _error == null) {
      body = const LoadingSkeleton();
    } else if (_current == null) {
      body = ErrorState(message: _error!, onRetry: _refresh);
    } else if (_response == null) {
      body = EmptyState(
        title: 'Анкета ещё не начата',
        message: canEdit
            ? 'Ответы можно сохранять частями и продолжать позже.'
            : 'Анкета появится после начала работы редактором.',
        actionLabel: canEdit ? 'Начать анкету' : null,
        onAction: canEdit && !_busy ? _start : null,
        icon: Icons.fact_check_outlined,
      );
    } else if (questions.isEmpty) {
      body = const EmptyState(
        title: 'Вопросов пока нет',
        message: 'В активной версии нет доступных вопросов.',
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Роль «Просмотр»: ответы можно читать, редактирование недоступно.',
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Вопрос ${_index + 1} из ${questions.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _saving
                        ? 'Сохранение…'
                        : _loading
                        ? 'Обновление…'
                        : _dirty
                        ? 'Есть изменения'
                        : 'Черновик сохранён',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _dirty
                          ? Theme.of(context).complianceColors.warning
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (_index + 1) / questions.length,
              minHeight: 6,
              semanticsLabel: 'Номер вопроса',
              semanticsValue:
                  '${(((_index + 1) / questions.length) * 100).round()}%',
            ),
            const SizedBox(height: 24),
            _QuestionCard(
              key: ValueKey<String>(
                '${questions[_index].code}:$_answerRevision',
              ),
              question: questions[_index],
              value: _answers[questions[_index].code],
              enabled: canEdit && !_busy,
              onChanged: (value) => _setAnswer(questions[_index].code, value),
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    }
    return ComplianceScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).questionnaire),
        leading: _index > 0
            ? IconButton(
                tooltip: 'Назад',
                onPressed: _busy ? null : () => setState(() => _index--),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            onPressed: _busy || organization == null ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
      footer: _response == null || questions.isEmpty
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy || !canEdit
                            ? null
                            : () => _save(complete: false),
                        child: const Text('Сохранить'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                if (_index < questions.length - 1) {
                                  setState(() => _index++);
                                } else if (!canEdit) {
                                  context.go('/obligations');
                                } else {
                                  await _save(complete: true);
                                }
                              },
                        icon: Icon(
                          _index < questions.length - 1
                              ? Icons.arrow_forward
                              : Icons.check,
                        ),
                        label: Text(
                          _index < questions.length - 1
                              ? 'Далее'
                              : canEdit
                              ? 'Завершить'
                              : 'К задачам',
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

final class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final QuestionDto question;
  final Object? value;
  final bool enabled;
  final ValueChanged<Object?> onChanged;

  Widget _choice(BuildContext context, Widget child, bool selected) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        question.section.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      Semantics(
        header: true,
        child: Text(
          question.text,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontSize: 23, fontWeight: FontWeight.w700),
        ),
      ),
      if (question.helpText.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          question.helpText,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
      const SizedBox(height: 24),
      _input(context),
      if (question.questionType == 'tri_state')
        const Text(
          'Ответ «Пока не знаю» помогает отметить вопрос для дальнейшей проверки.',
        ),
    ],
  );

  Widget _input(BuildContext context) {
    if (question.questionType == 'tri_state') {
      return RadioGroup<String>(
        groupValue: value as String?,
        onChanged: (next) {
          if (enabled && next != null) onChanged(next);
        },
        child: Column(
          children: <Widget>[
            for (final option in const <String, String>{
              'yes': 'Да',
              'no': 'Нет',
              'unknown': 'Пока не знаю',
            }.entries)
              _choice(
                context,
                RadioListTile<String>(
                  value: option.key,
                  enabled: enabled,
                  title: Text(option.value),
                ),
                value == option.key,
              ),
          ],
        ),
      );
    }
    if (question.questionType == 'single') {
      return DropdownButtonFormField<String>(
        initialValue: value as String?,
        isExpanded: true,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Выберите вариант'),
        items: question.options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(growable: false),
        onChanged: enabled ? onChanged : null,
      );
    }
    if (question.questionType == 'multi') {
      final selected = value is List<Object?>
          ? (value as List<Object?>).whereType<String>().toSet()
          : <String>{};
      return Column(
        children: <Widget>[
          for (final option in question.options)
            _choice(
              context,
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(option.value),
                title: Text(option.label),
                onChanged: !enabled
                    ? null
                    : (checked) {
                        final next = Set<String>.from(selected);
                        checked == true
                            ? next.add(option.value)
                            : next.remove(option.value);
                        onChanged(next.toList(growable: false));
                      },
              ),
              selected.contains(option.value),
            ),
        ],
      );
    }
    final multiline =
        question.questionType == 'long_text' ||
        question.questionType == 'table';
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: question.questionType == 'number'
          ? TextInputType.number
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      minLines: multiline ? 4 : 1,
      maxLines: multiline ? 8 : 2,
      decoration: const InputDecoration(labelText: 'Ответ'),
      enabled: enabled,
      onChanged: (text) => onChanged(
        question.questionType == 'number' ? int.tryParse(text) ?? text : text,
      ),
    );
  }
}
