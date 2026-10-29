import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_models.dart';
import '../../core/network/sse_parser.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import 'ai_stream_state.dart';

String _safeAiError(Object error) => error is AppError
    ? error.safeMessage
    : 'AI-помощник временно недоступен. Повторите попытку позже.';

final class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

final class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<AiConversationDto> _conversations = <AiConversationDto>[];
  AiConversationDto? _conversation;
  AiRequestDto? _request;
  StreamSubscription<AiStreamEvent>? _subscription;
  String _streamedText = '';
  AiStreamPresentationState _streamState = const AiStreamPresentationState();
  String? _organizationId;
  String? _error;
  bool _busy = false;
  int? _lastEventId;
  int _activationSerial = 0;

  @override
  void dispose() {
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _activateOrganization(String? id) {
    final int activationSerial = ++_activationSerial;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _organizationId = id;
    _conversations = <AiConversationDto>[];
    _conversation = null;
    _request = null;
    _streamedText = '';
    _streamState = const AiStreamPresentationState();
    _lastEventId = null;
    _error = null;
    _busy = id != null;
    _input.clear();
    if (id != null) {
      Future<void>.microtask(() => _loadConversations(id, activationSerial));
    }
  }

  bool _isActive(String organizationId, int activationSerial) =>
      mounted &&
      _organizationId == organizationId &&
      _activationSerial == activationSerial &&
      isCurrentOrganization(ref, organizationId);

  Future<void> _loadConversations(String id, int activationSerial) async {
    if (!_isActive(id, activationSerial)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await ref.read(repositoryProvider).conversations(id);
      if (_isActive(id, activationSerial)) {
        setState(() => _conversations = items);
      }
    } on Object catch (error) {
      if (_isActive(id, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
    } finally {
      if (_isActive(id, activationSerial)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _select(AiConversationDto item) async {
    final String? organizationId = _organizationId;
    final int activationSerial = _activationSerial;
    if (organizationId == null) {
      return;
    }
    await _subscription?.cancel();
    if (!_isActive(organizationId, activationSerial)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _request = null;
      _streamedText = '';
      _streamState = const AiStreamPresentationState();
    });
    try {
      final detail = await ref
          .read(repositoryProvider)
          .conversation(organizationId, item.id);
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _conversation = detail);
      }
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
    } finally {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<AiConversationDto?> _createConversationWithNotice({
    String suggestedTitle = 'Консультация',
  }) async {
    final String? organizationId = _organizationId;
    final int activationSerial = _activationSerial;
    if (organizationId == null) {
      return null;
    }
    String title = suggestedTitle;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            title: const Text('Новый разговор'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Не указывайте ФИО, личные контакты, паспортные и другие '
                  'персональные данные. Название организации, реквизиты ИП и '
                  'иные идентификаторы будут исключены из AI-контекста.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: title,
                  onChanged: (String value) => title = value,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Создать'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted ||
        title.trim().isEmpty ||
        !_isActive(organizationId, activationSerial)) {
      return null;
    }
    try {
      final AiConversationDto created = await ref
          .read(repositoryProvider)
          .createConversation(organizationId, title.trim());
      if (!_isActive(organizationId, activationSerial)) {
        return null;
      }
      await _loadConversations(organizationId, activationSerial);
      if (!_isActive(organizationId, activationSerial)) {
        return null;
      }
      await _select(created);
      return _isActive(organizationId, activationSerial) ? _conversation : null;
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
      return null;
    }
  }

  Future<void> _newConversation() async {
    await _createConversationWithNotice();
  }

  Future<void> _send() async {
    final String message = _input.text.trim();
    final String? organizationId = _organizationId;
    final int activationSerial = _activationSerial;
    AiConversationDto? conversation = _conversation;
    if (message.isEmpty || organizationId == null || _busy) {
      return;
    }
    if (conversation == null) {
      conversation = await _createConversationWithNotice(
        suggestedTitle: message.length > 48
            ? '${message.substring(0, 48)}…'
            : message,
      );
      if (conversation == null ||
          !_isActive(organizationId, activationSerial)) {
        return;
      }
    }
    _input.clear();
    setState(() {
      _busy = true;
      _error = null;
      _streamedText = '';
      _lastEventId = null;
      _streamState = const AiStreamPresentationState();
    });
    try {
      final request = await ref
          .read(repositoryProvider)
          .sendAiMessage(
            organizationId: organizationId,
            conversationId: conversation.id,
            message: message,
          );
      if (!_isActive(organizationId, activationSerial)) {
        return;
      }
      final detail = await ref
          .read(repositoryProvider)
          .conversation(organizationId, conversation.id);
      if (!_isActive(organizationId, activationSerial)) {
        return;
      }
      setState(() {
        _conversation = detail;
        _request = request;
        _streamState = _streamState.applyRequest(request);
        _busy = false;
      });
      await _listen(
        request,
        organizationId: organizationId,
        activationSerial: activationSerial,
      );
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() {
          _busy = false;
          _error = _safeAiError(error);
        });
      }
    }
  }

  Future<void> _listen(
    AiRequestDto request, {
    required String organizationId,
    required int activationSerial,
  }) async {
    await _subscription?.cancel();
    if (!_isActive(organizationId, activationSerial)) {
      return;
    }
    final String conversationId = request.conversationId;
    _subscription = ref
        .read(repositoryProvider)
        .streamAiEvents(
          organizationId: organizationId,
          conversationId: conversationId,
          requestId: request.id,
          after: _lastEventId,
        )
        .listen(
          (AiStreamEvent event) {
            if (!_isActive(organizationId, activationSerial)) {
              return;
            }
            final String? previousTerminal = _streamState.terminalStatus;
            final AiStreamPresentationState nextStreamState = _streamState
                .applyEvent(event);
            setState(() {
              _lastEventId = event.id ?? _lastEventId;
              _streamState = nextStreamState;
              if (event.type == 'delta') {
                _streamedText += event.payload['text'] as String? ?? '';
              }
            });
            if (nextStreamState.terminalStatus != null &&
                nextStreamState.terminalStatus != previousTerminal) {
              unawaited(
                _refreshRequest(
                  organizationId,
                  conversationId,
                  request.id,
                  activationSerial,
                ),
              );
            }
          },
          onError: (Object error, StackTrace _) {
            if (_isActive(organizationId, activationSerial)) {
              setState(() => _error = _safeAiError(error));
            }
          },
        );
  }

  Future<void> _refreshRequest(
    String organizationId,
    String conversationId,
    String requestId,
    int activationSerial,
  ) async {
    try {
      final updated = await ref
          .read(repositoryProvider)
          .aiRequest(organizationId, conversationId, requestId);
      if (!_isActive(organizationId, activationSerial)) {
        return;
      }
      final detail = await ref
          .read(repositoryProvider)
          .conversation(organizationId, conversationId);
      if (_isActive(organizationId, activationSerial)) {
        setState(() {
          _request = updated;
          _conversation = detail;
          _streamState = _streamState.applyRequest(updated);
          if (_streamState.terminalStatus == 'completed') {
            _error = null;
          }
          _busy = false;
        });
      }
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
    }
  }

  Future<void> _cancelOrRetry({required bool retry}) async {
    final request = _request;
    final organizationId = _organizationId;
    final conversation = _conversation;
    final int activationSerial = _activationSerial;
    if (request == null || organizationId == null || conversation == null) {
      return;
    }
    try {
      final updated = retry
          ? await ref
                .read(repositoryProvider)
                .retryAi(organizationId, conversation.id, request)
          : await ref
                .read(repositoryProvider)
                .cancelAi(organizationId, conversation.id, request);
      if (!_isActive(organizationId, activationSerial)) {
        return;
      }
      setState(() {
        _request = updated;
        _streamedText = '';
        _lastEventId = null;
        _streamState = retry
            ? const AiStreamPresentationState()
            : _streamState.applyRequest(updated);
      });
      if (retry) {
        await _listen(
          updated,
          organizationId: organizationId,
          activationSerial: activationSerial,
        );
      }
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
    }
  }

  Future<void> _decideProposal(JsonMap proposal, bool apply) async {
    final request = _request;
    final organizationId = _organizationId;
    final conversation = _conversation;
    final int activationSerial = _activationSerial;
    final String? proposalId = proposal['id'] as String?;
    if (request == null ||
        organizationId == null ||
        conversation == null ||
        proposalId == null) {
      return;
    }
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            title: Text(
              apply ? 'Применить предложение?' : 'Отклонить предложение?',
            ),
            content: Text(
              '${proposal['field']}\n${proposal['value']}\n\n${proposal['reason']}',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(apply ? 'Применить' : 'Отклонить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !_isActive(organizationId, activationSerial)) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .decideProposal(
            organizationId: organizationId,
            conversationId: conversation.id,
            requestId: request.id,
            proposalId: proposalId,
            apply: apply,
            etag: request.etag,
          );
      if (!_isActive(organizationId, activationSerial)) {
        return;
      }
      await _refreshRequest(
        organizationId,
        conversation.id,
        request.id,
        activationSerial,
      );
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
    }
  }

  Future<void> _submitFeedback(String rating) async {
    final AiRequestDto? request = _request;
    final String? organizationId = _organizationId;
    final AiConversationDto? conversation = _conversation;
    final int activationSerial = _activationSerial;
    if (request == null || organizationId == null || conversation == null) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .submitFeedback(
            organizationId: organizationId,
            conversationId: conversation.id,
            requestId: request.id,
            rating: rating,
          );
      if (mounted && _isActive(organizationId, activationSerial)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Отзыв сохранён.')));
      }
    } on Object catch (error) {
      if (_isActive(organizationId, activationSerial)) {
        setState(() => _error = _safeAiError(error));
      }
    }
  }

  List<Object?> _resultList(String key) =>
      _request?.result?[key] as List<Object?>? ?? const <Object?>[];

  List<JsonMap> _proposals() {
    final Object? raw = _request?.result?['proposals'];
    if (raw is! List<Object?>) {
      return const <JsonMap>[];
    }
    return raw.whereType<Map<String, Object?>>().toList(growable: false);
  }

  Widget _conversationList({bool closeOnSelect = false}) => ListView(
    children: <Widget>[
      ListTile(
        leading: const Icon(Icons.add_comment_outlined),
        title: const Text('Новый разговор'),
        onTap: () {
          if (closeOnSelect) Navigator.pop(context);
          _newConversation();
        },
      ),
      ..._conversations.map(
        (AiConversationDto item) => ListTile(
          selected: item.id == _conversation?.id,
          title: Text(item.title),
          subtitle: Text(humanStatus(item.status)),
          onTap: () {
            if (closeOnSelect) Navigator.pop(context);
            _select(item);
          },
        ),
      ),
    ],
  );

  Widget _chat({required bool canApplyProposals}) {
    final messages = _conversation?.messages ?? const <JsonMap>[];
    final result = _request?.result;
    final String completedAnswer = result?['answer'] as String? ?? '';
    final String visibleAnswer = completedAnswer.isNotEmpty
        ? completedAnswer
        : _streamedText;
    final String? visibleBanner = _error ?? _streamState.banner;
    return Column(
      children: <Widget>[
        if (visibleBanner != null)
          MaterialBanner(
            content: Text(visibleBanner),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() {
                  _error = null;
                  _streamState = AiStreamPresentationState(
                    terminalStatus: _streamState.terminalStatus,
                    rateLimitState: _streamState.rateLimitState,
                  );
                }),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: <Widget>[
              if (_conversation == null) ...<Widget>[
                const EmptyState(
                  title: 'Разберёмся с результатом',
                  message: 'Помощник объяснит оценку и предложит следующий шаг. Решение остаётся за вами.',
                  icon: Icons.auto_awesome_outlined,
                ),
                for (final question in const <String>[
                  'Почему нужна проверка политики?',
                  'С чего начать работу с задачами?',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              _input.text = question;
                              _send();
                            },
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(question)),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ),
              ],
              ...messages.map(
                (JsonMap message) => _AiMessageBubble(
                  text: message['content'] as String? ?? '',
                  user: message['role'] == 'user',
                ),
              ),
              if (visibleAnswer.isNotEmpty)
                _AiMessageBubble(text: visibleAnswer, user: false),
              if (_request != null)
                _AiDiagnosticCard(
                  request: _request!,
                  displayStatus:
                      _streamState.terminalStatus ?? _request!.status,
                  rateLimitState: _streamState.rateLimitState.isEmpty
                      ? _request!.rateLimitState
                      : _streamState.rateLimitState,
                  onCancel: () => _cancelOrRetry(retry: false),
                  onRetry: () => _cancelOrRetry(retry: true),
                ),
              if (result != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const SemanticStatusBadge(
                  label: 'Проверьте перед применением',
                  status: SemanticStatus.needsHumanReview,
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Источники и основания'),
                  children: <Widget>[
                    _DeterministicResultCard(
                      requiresHumanReview:
                          result['requires_human_review'] == true,
                      sources: _resultList('cited_source_codes'),
                      rules: _resultList('used_rule_codes'),
                      uncertainties: _resultList('uncertainties'),
                      safetyFlags: _resultList('safety_flags'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._proposals().map(
                  (JsonMap proposal) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _AiProposalCard(
                      proposal: proposal,
                      canDecide: canApplyProposals,
                      onAccept: () => _decideProposal(proposal, true),
                      onReject: () => _decideProposal(proposal, false),
                    ),
                  ),
                ),
                ComplianceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Оцените ответ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          for (final (String rating, String label)
                              in const <(String, String)>[
                                ('helpful', 'Полезно'),
                                ('not_helpful', 'Не полезно'),
                                ('error', 'Ошибка'),
                                ('needs_review', 'Требует проверки'),
                              ])
                            OutlinedButton(
                              onPressed: () => _submitFeedback(rating),
                              child: Text(label),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Вопрос AI-помощнику',
                      hintText: 'Введите только обезличенный вопрос.',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.send),
                  tooltip: 'Отправить',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(currentOrganizationProvider);
    if (organization == null) {
      if (_organizationId != null) {
        _activateOrganization(null);
      }
      return const ComplianceScaffold(
        body: Center(child: Text('Выберите организацию.')),
      );
    }
    if (_organizationId != organization.id) {
      _activateOrganization(organization.id);
    }
    final bool canApplyProposals = organization.role != 'viewer';
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Помощник'),
        actions: <Widget>[
          IconButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .7,
                  child: _conversationList(closeOnSelect: true),
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Разговоры',
          ),
        ],
      ),
      body: _chat(canApplyProposals: canApplyProposals),
    );
  }
}

final class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({required this.text, required this.user});

  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: '${user ? 'Сообщение пользователя' : 'Ответ AI'}: $text',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: user ? colors.primaryContainer : colors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadii.card),
              topRight: const Radius.circular(AppRadii.card),
              bottomLeft: Radius.circular(user ? AppRadii.card : 4),
              bottomRight: Radius.circular(user ? 4 : AppRadii.card),
            ),
            border: Border.all(
              color: user
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    user ? Icons.person_outline : Icons.auto_awesome,
                    size: 17,
                    color: user ? colors.primary : colors.tertiary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    user ? 'Вы' : 'Помощник',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: user ? colors.primary : colors.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(text),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AiDiagnosticCard extends StatelessWidget {
  const _AiDiagnosticCard({
    required this.request,
    required this.displayStatus,
    required this.rateLimitState,
    required this.onCancel,
    required this.onRetry,
  });

  final AiRequestDto request;
  final String displayStatus;
  final JsonMap rateLimitState;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool canCancel = const <String>{
      'queued',
      'running',
    }.contains(displayStatus);
    final bool canRetry = const <String>{
      'failed',
      'cancelled',
      'expired',
    }.contains(displayStatus);
    final bool exceeded = aiRateLimitExceeded(rateLimitState);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              SemanticStatusBadge(
                label: _requestStatusLabel(displayStatus),
                status: _requestStatus(displayStatus),
              ),
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop),
                  label: const Text('Отменить'),
                ),
              if (canRetry)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.replay),
                  label: const Text('Повторить'),
                ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Сведения об ответе'),
            children: <Widget>[
              ListTile(
                title: const Text('Диагностика ответа'),
                subtitle: Text(
                  'Запрошенная модель: ${request.requestedModel}\nВыбранная модель: ${request.selectedModel ?? 'ожидается'}\nФактическая модель: ${request.actualModel ?? 'ожидается'}\nИспользовано токенов: ${request.telemetry['total_tokens'] ?? 'нет данных'}',
                ),
              ),
              if (request.fallbackUsed || request.reroute['to'] != null)
                const Text('Разрешённое перенаправление'),
              if (rateLimitState.isNotEmpty)
                ListTile(
                  leading: Icon(
                    exceeded ? Icons.hourglass_top : Icons.info_outline,
                  ),
                  title: Text(aiRateLimitLabel(rateLimitState)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _DeterministicResultCard extends StatelessWidget {
  const _DeterministicResultCard({
    required this.requiresHumanReview,
    required this.sources,
    required this.rules,
    required this.uncertainties,
    required this.safetyFlags,
  });

  final bool requiresHumanReview;
  final List<Object?> sources;
  final List<Object?> rules;
  final List<Object?> uncertainties;
  final List<Object?> safetyFlags;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic = Theme.of(context).complianceColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: semantic.informationContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: semantic.information.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.gavel_outlined,
                color: semantic.onInformationContainer,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Детерминированный результат имеет приоритет над AI-объяснением.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: semantic.onInformationContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (requiresHumanReview) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const SemanticStatusBadge(
              label: 'Требуется проверка человеком',
              status: SemanticStatus.needsHumanReview,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _EvidenceLine(
            icon: Icons.source_outlined,
            label: 'Источники',
            values: sources,
          ),
          _EvidenceLine(
            icon: Icons.rule_outlined,
            label: 'Применённые правила',
            values: rules,
          ),
          if (uncertainties.isNotEmpty)
            _EvidenceLine(
              icon: Icons.help_outline,
              label: 'Неопределённости',
              values: uncertainties,
              status: SemanticStatus.warning,
            ),
          if (safetyFlags.isNotEmpty)
            _EvidenceLine(
              icon: Icons.shield_outlined,
              label: 'Ограничения безопасности',
              values: safetyFlags,
              status: SemanticStatus.error,
            ),
        ],
      ),
    );
  }
}

final class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.icon,
    required this.label,
    required this.values,
    this.status = SemanticStatus.information,
  });

  final IconData icon;
  final String label;
  final List<Object?> values;
  final SemanticStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 19),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '$label: ${values.isEmpty ? 'не указаны' : values.join(', ')}',
          ),
        ),
        if (status != SemanticStatus.information)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Icon(
              status == SemanticStatus.error
                  ? Icons.error_outline
                  : Icons.warning_amber_rounded,
              size: 19,
            ),
          ),
      ],
    ),
  );
}

final class _AiProposalCard extends StatelessWidget {
  const _AiProposalCard({
    required this.proposal,
    required this.canDecide,
    required this.onAccept,
    required this.onReject,
  });

  final JsonMap proposal;
  final bool canDecide;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final bool pending = proposal['status'] == 'pending';
    final fieldLabel = switch (proposal['field']) {
      'draft_wording' => 'Формулировка черновика',
      'clarification_note' => 'Уточнение',
      final value => _humanValue(value),
    };
    return ComplianceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.rate_review_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Предложенное изменение: $fieldLabel',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SemanticStatusBadge(
                label: pending ? 'Ожидает решения' : 'Решение сохранено',
                status: pending
                    ? SemanticStatus.needsHumanReview
                    : SemanticStatus.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _ValuePreview(
                label: 'До',
                value: _humanValue(proposal['previous_value']),
              ),
              _ValuePreview(
                label: 'После',
                value: _humanValue(proposal['value']),
                highlighted: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Почему: ${_humanValue(proposal['reason'])}'),
          if (pending && canDecide) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check),
                  label: const Text('Применить после просмотра'),
                ),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Отклонить'),
                ),
              ],
            ),
          ],
          if (pending && !canDecide) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Text('Для решения по предложению нужна роль редактора.'),
          ],
        ],
      ),
    );
  }
}

final class _ValuePreview extends StatelessWidget {
  const _ValuePreview({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 420),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.input),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Text('$label: $value'),
  );
}

String _humanValue(Object? value) => switch (value) {
  null => 'не задано',
  final bool flag => flag ? 'да' : 'нет',
  final String text => text,
  final num number => '$number',
  _ => 'структурированное значение скрыто',
};

String _requestStatusLabel(String status) => switch (status) {
  'queued' => 'В очереди',
  'running' => 'Формируется',
  'completed' => 'Ответ готов',
  'failed' => 'Ошибка',
  'rejected' => 'Отклонено',
  'cancelled' => 'Отменено',
  'expired' => 'Время истекло',
  _ => 'Требует проверки',
};

SemanticStatus _requestStatus(String status) => switch (status) {
  'completed' => SemanticStatus.success,
  'queued' || 'running' => SemanticStatus.information,
  'failed' || 'rejected' || 'cancelled' || 'expired' => SemanticStatus.error,
  _ => SemanticStatus.needsHumanReview,
};
