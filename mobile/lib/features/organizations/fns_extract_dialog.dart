import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';

final fnsRegistryOpenerProvider = Provider<Future<bool> Function(String)>(
  (ref) => (inn) async {
    if (inn.isNotEmpty) await Clipboard.setData(ClipboardData(text: inn));
    return launchUrl(
      Uri.https('egrul.nalog.ru', '/index.html'),
      mode: LaunchMode.externalApplication,
    );
  },
);

class FnsExtractDialog extends ConsumerStatefulWidget {
  const FnsExtractDialog({
    required this.initialInn,
    required this.isAllowed,
    super.key,
  });

  final String initialInn;
  final bool Function() isAllowed;

  @override
  ConsumerState<FnsExtractDialog> createState() => _FnsExtractDialogState();
}

class _FnsExtractDialogState extends ConsumerState<FnsExtractDialog> {
  late final _inn = TextEditingController(text: widget.initialInn);
  FnsExtractPreviewDto? _preview;
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;
  CancelToken? _cancel;

  void _showMessage(String value, {bool error = true}) {
    if (mounted) {
      setState(() {
        _message = value;
        _messageIsError = error;
      });
    }
  }

  @override
  void dispose() {
    _cancel?.cancel('fns_dialog_closed');
    _inn.dispose();
    super.dispose();
  }

  bool _validateInn() {
    final inn = _inn.text.trim();
    if (inn.isNotEmpty && !RegExp(r'^(?:[0-9]{10}|[0-9]{12})$').hasMatch(inn)) {
      _showMessage('Укажите 10 цифр ИНН ООО или 12 цифр ИНН ИП.');
      return false;
    }
    return true;
  }

  Future<void> _openRegistry() async {
    if (!_validateInn() || !widget.isAllowed()) return;
    try {
      if (!await ref.read(fnsRegistryOpenerProvider)(_inn.text.trim()) &&
          mounted) {
        _showMessage('Не удалось открыть браузер. Сайт ФНС: egrul.nalog.ru.');
      } else if (mounted && _inn.text.trim().isNotEmpty) {
        _showMessage(
          'ИНН скопирован. Вставьте его в поиске ФНС, скачайте выписку и вернитесь сюда.',
          error: false,
        );
      }
    } on Object {
      if (mounted) {
        _showMessage('Не удалось открыть сайт ФНС в браузере.');
      }
    }
  }

  Future<void> _readExtract() async {
    if (_busy || !_validateInn() || !widget.isAllowed()) return;
    final inn = _inn.text.trim();
    final token = CancelToken();
    _cancel = token;
    setState(() {
      _busy = true;
      _message = null;
    });
    Uint8List? bytes;
    try {
      bytes = await ref.read(fnsExtractFileReaderProvider).pickBytes();
      if (!mounted || !widget.isAllowed() || bytes == null) return;
      final preview = await ref
          .read(repositoryProvider)
          .previewFnsExtract(bytes, expectedInn: inn, cancelToken: token);
      if (!mounted || !widget.isAllowed()) return;
      setState(() => _preview = preview);
    } on AppError catch (error) {
      if (mounted) {
        final field = error.fields['file'] ?? error.fields['expected_inn'];
        final text = field is List && field.isNotEmpty ? field.first : null;
        _showMessage(
          text is String && text.length <= 300 ? text : safeUiError(error),
        );
      }
    } on FormatException catch (error) {
      _showMessage(error.message);
    } on Object {
      if (mounted) {
        _showMessage(
          'Не удалось прочитать выписку. Можно повторить или заполнить реквизиты вручную.',
        );
      }
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      scrollable: true,
      title: Text(
        preview == null ? 'Заполнить из выписки ФНС' : 'Проверьте реквизиты',
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (preview == null) ...[
            const Text(
              'Получите бесплатную выписку по ИНН на сайте ФНС. Если PDF уже скачан, сразу выберите его ниже.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('fns-expected-inn'),
              controller: _inn,
              enabled: !_busy,
              maxLength: 12,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _message = null),
              decoration: const InputDecoration(
                labelText: 'ИНН для проверки (необязательно)',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openRegistry,
              icon: const Icon(Icons.open_in_new),
              label: Text(
                _inn.text.trim().isEmpty
                    ? 'Открыть ФНС'
                    : 'Скопировать ИНН и открыть ФНС',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'PDF до 5 МБ и 40 страниц обрабатывается на сервере в памяти. Файл не сохраняется в документах и не передаётся в AI. ФИО и личные контакты не импортируются.',
            ),
          ] else ...[
            const Text(
              'Сверьте сведения с ФНС: подпись файла и актуальность автоматически не подтверждаются. Реквизиты заменят соответствующие поля формы, отсутствующие будут очищены. Сохранение произойдёт только после создания организации.',
            ),
            const SizedBox(height: 12),
            for (final entry in <String, String?>{
              'Форма': preview.kind == 'ie' ? 'ИП' : 'ООО',
              'Полное наименование': preview.fullName,
              'Краткое наименование': preview.shortName,
              'ИНН': preview.inn,
              'ОГРН / ОГРНИП': preview.ogrn,
              'КПП': preview.kpp,
              'Юридический адрес': preview.legalAddress,
              'Основной ОКВЭД': preview.okved,
            }.entries)
              if (entry.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
            if (preview.kind == 'ie')
              const Text(
                'Названия ИП заполните вручную. ФИО и адрес проживания из выписки не подставляются.',
              ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _messageIsError
                          ? Icons.error_outline
                          : Icons.info_outline,
                      color: _messageIsError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_message!)),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('fns-extract-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (preview == null)
          FilledButton(
            onPressed: _busy ? null : _readExtract,
            child: const Text('Выбрать PDF'),
          )
        else
          FilledButton(
            onPressed: widget.isAllowed()
                ? () => Navigator.pop(context, preview)
                : null,
            child: const Text('Заполнить форму'),
          ),
      ],
    );
  }
}
