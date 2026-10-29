import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';

bool validRegistryInn(String value) {
  if (!RegExp(r'^(?:[0-9]{10}|[0-9]{12})$').hasMatch(value) ||
      value.split('').toSet().length == 1) {
    return false;
  }
  final digits = value.split('').map(int.parse).toList();
  bool check(List<int> weights, int index) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += digits[i] * weights[i];
    }
    return sum % 11 % 10 == digits[index];
  }

  return digits.length == 10
      ? check([2, 4, 10, 3, 5, 9, 4, 6, 8], 9)
      : check([7, 2, 4, 10, 3, 5, 9, 4, 6, 8], 10) &&
            check([3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8], 11);
}

final class RegistryLookupDialog extends ConsumerStatefulWidget {
  const RegistryLookupDialog({
    required this.inn,
    required this.isAllowed,
    super.key,
  });
  final String inn;
  final bool Function() isAllowed;

  @override
  ConsumerState<RegistryLookupDialog> createState() =>
      _RegistryLookupDialogState();
}

final class _RegistryLookupDialogState
    extends ConsumerState<RegistryLookupDialog> {
  final _cancel = CancelToken();
  RegistryPreviewDto? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_lookup);
  }

  @override
  void dispose() {
    _cancel.cancel('registry_dialog_closed');
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!mounted || !widget.isAllowed()) return;
    try {
      final preview = await ref
          .read(repositoryProvider)
          .lookupOrganization(widget.inn, _cancel);
      if (mounted && widget.isAllowed()) setState(() => _preview = preview);
    } on AppError catch (error) {
      if (mounted && widget.isAllowed()) {
        setState(() => _error = safeUiError(error));
      }
    } on Object {
      if (mounted && widget.isAllowed()) {
        setState(
          () => _error =
              'Не удалось проверить ответ справочника. Сведения не изменены.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      scrollable: true,
      title: Text(preview == null ? 'Поиск по ИНН' : 'Проверьте реквизиты'),
      content: _error != null
          ? Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : preview == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Ищем организацию в DaData…'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Источник: DaData, сведения ЕГРЮЛ/ЕГРИП. Проверьте данные перед созданием организации.',
                ),
                const SizedBox(height: 16),
                for (final entry in <String, String?>{
                  'Форма': preview.kind == 'ie' ? 'ИП' : 'ООО',
                  'ИНН': preview.inn,
                  'Полное наименование': preview.fullName,
                  'Краткое название': preview.shortName,
                  'КПП': preview.kpp,
                  'ОГРН / ОГРНИП': preview.ogrn,
                  'Юридический адрес': preview.legalAddress,
                  'Руководитель / ФИО ИП': preview.leaderName,
                  'Основной ОКВЭД': preview.okved,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(entry.value ?? 'Нет сведений'),
                      ],
                    ),
                  ),
                const Text(
                  'Будут заменены только реквизиты из справочника. Ваши контакты, фактический адрес и другие сведения сохранятся. Поля можно отредактировать перед сохранением.',
                ),
              ],
            ),
      actions: [
        TextButton(
          key: const ValueKey('registry-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (preview != null)
          FilledButton(
            key: const ValueKey('registry-apply'),
            onPressed: () {
              if (widget.isAllowed()) Navigator.pop(context, preview);
            },
            child: const Text('Заполнить поля'),
          ),
      ],
    );
  }
}
