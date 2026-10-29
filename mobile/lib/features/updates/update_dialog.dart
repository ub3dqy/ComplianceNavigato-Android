import 'dart:async';

import 'package:flutter/material.dart';

import 'app_updates.dart';

typedef UpdateCheck = ({
  UpdateOffer? offer,
  UpdateDownload? download,
  Object? error,
});

Future<UpdateCheck> _prepareCheck(
  AppUpdates service,
  UpdateOffer? offered,
) async {
  try {
    final offer = offered ?? await service.check();
    final download = offer == null ? null : await service.downloadState(offer);
    return (offer: offer, download: download, error: null);
  } on Object catch (error) {
    return (offer: null, download: null, error: error);
  }
}

Future<void> showAppUpdates(
  BuildContext context,
  AppUpdates service, {
  UpdateOffer? offer,
  Future<bool> Function()? beforeInstall,
}) async {
  if (service.presenting) return;
  service.presenting = true;
  try {
    final check = _prepareCheck(service, offer);
    await showDialog<void>(
      context: context,
      builder: (_) => AppUpdateDialog(
        service: service,
        initialCheck: check,
        beforeInstall: beforeInstall,
      ),
    );
  } finally {
    service.presenting = false;
  }
}

final class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.service,
    required this.initialCheck,
    this.beforeInstall,
  });
  final AppUpdates service;
  final Future<UpdateCheck> initialCheck;
  final Future<bool> Function()? beforeInstall;
  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

final class _AppUpdateDialogState extends State<AppUpdateDialog> {
  UpdateOffer? _offer;
  bool _checking = true,
      _busy = false,
      _transferring = false,
      _ready = false,
      _paused = false;
  double _progress = 0;
  bool _hasError = false;
  String? _message;
  Timer? _timer;
  Completer<void>? _tick;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize(widget.initialCheck));
  }

  void _wake() {
    _timer?.cancel();
    if (_tick != null && !_tick!.isCompleted) _tick!.complete();
  }

  @override
  void dispose() {
    _operation++;
    _wake();
    unawaited(widget.service.cancelInstallation());
    super.dispose();
  }

  String _error(Object error) => error is UpdateFailure
      ? error.message
      : 'Не удалось обновить приложение. Проверьте интернет и свободное место.';

  Future<void> _initialize([Future<UpdateCheck>? initial]) async {
    final operation = ++_operation;
    setState(() {
      _checking = true;
      _message = null;
      _hasError = false;
    });
    try {
      final checked = await (initial ?? _prepareCheck(widget.service, null));
      if (checked.error != null) throw checked.error!;
      final offer = checked.offer;
      if (!mounted || operation != _operation) return;
      setState(() {
        _offer = offer;
        _checking = false;
      });
      if (offer == null) return;
      widget.service.lastPresentedVersion = offer.versionCode;
      final download = checked.download!;
      setState(() {
        _ready = download.ready;
        _progress = download.progress;
        _message = download.message;
        _hasError = download.state == 'failed';
      });
      if (download.active) await _observe(operation, start: false);
    } on Object catch (error) {
      if (mounted && operation == _operation) {
        setState(() {
          _checking = false;
          _busy = false;
          _transferring = false;
          _message = _error(error);
          _hasError = true;
        });
      }
    }
  }

  Future<void> _observe(int operation, {required bool start}) async {
    var state = await widget.service.downloadState(_offer!, start: start);
    while (mounted && operation == _operation) {
      setState(() {
        _progress = state.progress;
        _ready = state.ready;
        _transferring = state.active;
        _busy = state.active;
        _paused = state.state == 'paused';
        _hasError = state.state == 'failed';
        _message = state.ready
            ? 'Обновление скачано и проверено. Нажмите «Установить».'
            : state.message;
      });
      if (!state.active) return;
      final tick = _tick = Completer<void>();
      _timer = Timer(const Duration(seconds: 1), tick.complete);
      await tick.future;
      if (!mounted || operation != _operation) return;
      state = await widget.service.downloadState(_offer!);
    }
  }

  Future<void> _update() async {
    if (_busy || _offer == null) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _message = null;
      _hasError = false;
    });
    try {
      if (!_ready) {
        await _observe(operation, start: true);
        return;
      }
      if (widget.beforeInstall != null && !await widget.beforeInstall!()) {
        if (mounted && operation == _operation) {
          setState(
            () => _message = 'Установка отложена. Завершите работу с анкетой.',
          );
        }
        return;
      }
      if (!mounted || operation != _operation) return;
      final state = await widget.service.install(_offer!);
      if (!mounted || operation != _operation) return;
      setState(
        () => _message = switch (state) {
          'permission_required' => 'Разрешите установку из Комплаенс-Навигатора, вернитесь сюда и нажмите «Установить».',
          'installer_opened' => 'Подтвердите обновление в окне Android. Данные и настройки приложения сохранятся.',
          _ => 'Вернитесь в приложение и нажмите «Установить», когда телефон разблокирован.',
        },
      );
    } on Object catch (error) {
      if (mounted && operation == _operation) {
        // A damaged or missing cache must make downloading available again.
        UpdateDownload? state;
        try {
          state = await widget.service.downloadState(_offer!);
        } on Object {
          /* Retry downloads safely. */
        }
        if (mounted && operation == _operation) {
          setState(() {
            _ready = state?.ready ?? false;
            _message = _error(error);
            _hasError = true;
          });
        }
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _transferring = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    final operation = ++_operation;
    _wake();
    setState(() {
      _busy = true;
      _hasError = false;
    });
    try {
      await widget.service.cancelDownload(_offer!);
      if (mounted && operation == _operation) {
        setState(() {
          _ready = false;
          _progress = 0;
          _message = 'Загрузка отменена.';
        });
      }
    } on Object catch (error) {
      if (mounted && operation == _operation) {
        setState(() {
          _message = _error(error);
          _hasError = true;
        });
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _transferring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    return AlertDialog(
      scrollable: true,
      title: Row(
        children: <Widget>[
          Icon(
            _hasError
                ? Icons.error_outline
                : _checking
                ? Icons.sync
                : _ready || offer == null
                ? Icons.check_circle_outline
                : Icons.system_update_outlined,
            color: _hasError ? Theme.of(context).colorScheme.error : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _checking
                  ? 'Проверка обновлений'
                  : offer == null
                  ? (_message == null
                        ? 'Обновлений нет'
                        : 'Не удалось проверить обновления')
                  : (_ready ? 'Обновление готово' : 'Доступно обновление'),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_checking) const LinearProgressIndicator(),
          if (offer != null) ...<Widget>[
            Text(
              'Версия ${offer.version} · ${(offer.bytes / 1000000).toStringAsFixed(1)} МБ',
            ),
            const SizedBox(height: 12),
            Text(offer.notes),
          ] else
            Text(
              _checking
                  ? 'Проверяем актуальность версии…'
                  : _message ??
                        'Установлена последняя доступная версия приложения.',
            ),
          if (_busy) ...<Widget>[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _transferring ? _progress : null),
            if (_transferring) ...<Widget>[
              Text('${(_progress * 100).round()} %'),
              Text(
                _paused
                    ? 'Android ожидает подключения для продолжения загрузки.'
                    : 'Окно можно закрыть или заблокировать телефон. Загрузка продолжится.',
              ),
            ],
          ],
          if (offer != null && _message != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_message!),
          ],
        ],
      ),
      actions: <Widget>[
        if (_transferring)
          TextButton(
            onPressed: _cancel,
            child: const Text('Отменить загрузку'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            _transferring
                ? 'Скрыть'
                : offer == null
                ? 'Закрыть'
                : 'Позже',
          ),
        ),
        if (!_checking && offer == null && _message != null)
          FilledButton(
            onPressed: () => _initialize(),
            child: const Text('Повторить'),
          ),
        if (offer != null)
          FilledButton(
            onPressed: _busy ? null : _update,
            child: Text(_ready ? 'Установить' : 'Скачать обновление'),
          ),
      ],
    );
  }
}
