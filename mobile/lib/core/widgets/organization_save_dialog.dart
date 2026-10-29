import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../auth/auth_state.dart';
import '../errors/app_error.dart';
import '../network/api_models.dart';
import '../presentation/human_labels.dart';

/// Retains a draft until the server acknowledges it. A retry after an uncertain
/// response replays the same immutable request, scoped to this actor and tenant.
final class OrganizationSaveDialog extends ConsumerStatefulWidget {
  const OrganizationSaveDialog({
    required this.organizationId,
    required this.generation,
    required this.title,
    required this.fields,
    required this.canSave,
    required this.payload,
    required this.save,
    this.saveLabel = 'Сохранить',
    this.reloadVersion,
    this.afterSave,
    super.key,
  });

  final String organizationId;
  final int generation;
  final String title;
  final Widget Function(BuildContext, StateSetter, bool enabled) fields;
  final bool Function() canSave;
  final JsonMap Function() payload;
  final Future<void> Function(JsonMap data, String idempotencyKey) save;
  final String saveLabel;
  final Future<void> Function()? reloadVersion;
  final Future<void> Function()? afterSave;

  @override
  ConsumerState<OrganizationSaveDialog> createState() =>
      _OrganizationSaveDialogState();
}

final class _OrganizationSaveDialogState
    extends ConsumerState<OrganizationSaveDialog> {
  String? _actor;
  bool _saving = false;
  bool _uncertain = false;
  bool _expired = false;
  bool _conflict = false;
  bool _saved = false;
  String? _error;
  JsonMap? _requestData;
  String? _requestKey;

  @override
  void initState() {
    super.initState();
    _actor = ref.read(authControllerProvider).user?.id;
  }

  bool get _allowed {
    if (!mounted || _expired) return false;
    final auth = ref.read(authControllerProvider);
    final organization = ref.read(currentOrganizationProvider);
    final allowed =
        _actor != null &&
        auth.phase == AuthPhase.authenticated &&
        auth.user?.id == _actor &&
        organization?.role != 'viewer' &&
        isCurrentOrganization(
          ref,
          widget.organizationId,
          generation: widget.generation,
        );
    if (!allowed) _expired = true;
    return allowed;
  }

  void _changed(VoidCallback change) {
    if (!_allowed || _saving || _uncertain || _saved) return;
    setState(() {
      change();
      _requestData = null;
      _requestKey = null;
      if (!_conflict) _error = null;
    });
  }

  Future<void> _save() async {
    if (!_allowed || _saving || _conflict || !widget.canSave()) return;
    final wasUncertain = _uncertain;
    _requestData ??= Map<String, Object?>.unmodifiable(widget.payload());
    _requestKey ??= const Uuid().v4();
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!_saved) {
        await widget.save(_requestData!, _requestKey!);
        if (!_allowed) return;
        setState(() {
          _saved = true;
          _uncertain = false;
        });
      }
      if (widget.afterSave != null) await widget.afterSave!();
      if (mounted && _allowed) Navigator.pop(context, true);
    } on Object catch (error) {
      if (!_allowed) return;
      if (_saved) {
        setState(
          () => _error = 'Сведения сохранены. Не удалось обновить список. Повторите обновление.',
        );
        return;
      }
      final definite =
          error is AppError &&
              const {
                AppErrorKind.validation,
                AppErrorKind.permission,
                AppErrorKind.authentication,
                AppErrorKind.rateLimit,
              }.contains(error.kind) ||
          error is AppError &&
              error.kind == AppErrorKind.conflict &&
              !wasUncertain;
      setState(() {
        _uncertain = !definite;
        _conflict =
            definite &&
            error.kind == AppErrorKind.conflict &&
            widget.reloadVersion != null;
        _error = _uncertain
            ? 'Не удалось подтвердить сохранение. Повторите тот же запрос: '
                  'дубликат не будет создан.'
            : _conflict
            ? 'Данные изменились на сервере. Обновите версию, сохранив '
                  'введённые сведения на экране, затем повторите сохранение.'
            : safeUiError(error);
        if (definite) {
          _requestData = null;
          _requestKey = null;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadVersion() async {
    if (!_allowed || _saving || !_conflict || widget.reloadVersion == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.reloadVersion!();
      if (!_allowed) return;
      setState(() {
        _conflict = false;
        _error = null;
        _requestKey = null;
        _requestData = null;
      });
    } on Object catch (error) {
      if (_allowed) setState(() => _error = safeUiError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    ref.watch(currentOrganizationProvider);
    ref.watch(organizationGenerationProvider);
    final allowed = _allowed;
    final enabled = allowed && !_saving && !_uncertain && !_saved;
    return PopScope(
      canPop: !_saving || !allowed,
      child: AlertDialog(
        scrollable: true,
        title: Text(allowed ? widget.title : 'Организация изменилась'),
        content: !allowed
            ? const Text('Откройте форму заново для выбранной организации.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.fields(context, _changed, enabled),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          TextButton(
            onPressed: _saving && allowed
                ? null
                : () => Navigator.pop(context, false),
            child: Text(allowed && !_saved ? 'Отмена' : 'Закрыть'),
          ),
          if (allowed && _conflict)
            TextButton(
              onPressed: _saving ? null : _reloadVersion,
              child: const Text('Обновить версию'),
            ),
          if (allowed)
            FilledButton(
              onPressed: _saving || _conflict || !widget.canSave()
                  ? null
                  : _save,
              child: Text(
                _saving
                    ? _saved
                          ? 'Обновление…'
                          : 'Сохранение…'
                    : _saved
                    ? 'Обновить список'
                    : _uncertain
                    ? 'Повторить сохранение'
                    : widget.saveLabel,
              ),
            ),
        ],
      ),
    );
  }
}
