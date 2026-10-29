import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/routing/organization_form_exit_guard.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';
import 'fns_extract_dialog.dart';
import 'organization_controller.dart';
import 'registry_lookup_dialog.dart';

final class OrganizationCreateScreen extends ConsumerStatefulWidget {
  const OrganizationCreateScreen({super.key});

  @override
  ConsumerState<OrganizationCreateScreen> createState() =>
      _OrganizationCreateScreenState();
}

final class _OrganizationCreateScreenState
    extends ConsumerState<OrganizationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {
    for (final name in <String>[
      'full_name',
      'short_name',
      'inn',
      'kpp',
      'ogrn',
      'legal_address',
      'actual_address',
      'leader_name',
      'contact_email',
      'contact_phone',
      'tax_regime',
      'okved',
      'privacy_responsible',
      'notes',
    ])
      name: TextEditingController(),
    'employee_count': TextEditingController(text: '0'),
  };
  final _sections = List.generate(4, (_) => ExpansibleController());
  late final OrganizationFormExitGuard _exitGuard;
  late final Future<bool> Function() _exitCallback;
  Future<bool>? _exitInFlight;
  String _kind = 'llc';
  DateTime? _startDate;
  bool _hasApplicants = false;
  bool _dirty = false;
  bool _saving = false;
  bool _importing = false;
  bool _saved = false;
  bool _uncertain = false;
  String? _message;
  JsonMap _errors = {};
  JsonMap? _requestData;
  String? _requestKey;

  @override
  void initState() {
    super.initState();
    _exitGuard = ref.read(organizationFormExitGuardProvider);
    _exitCallback = _confirmLeave;
    _exitGuard.confirm = _exitCallback;
  }

  @override
  void dispose() {
    if (identical(_exitGuard.confirm, _exitCallback)) _exitGuard.confirm = null;
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final controller in _sections) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmLeave() {
    if (_importing) return Future.value(false);
    if (_saved || !_dirty) return Future.value(true);
    if (_saving) return Future.value(false);
    return _exitInFlight ??= _askLeave().whenComplete(
      () => _exitInFlight = null,
    );
  }

  Future<bool> _askLeave() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Закрыть новую организацию?'),
          content: Text(
            _uncertain
                ? 'Ответ на создание ещё не подтверждён. Организация могла сохраниться. Повторная отправка проверит тот же запрос без создания дубликата.'
                : 'Введённые сведения ещё не сохранены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Закрыть форму'),
            ),
          ],
        ),
      ) ??
      false;

  void _changed([String? field]) {
    setState(() {
      _dirty = true;
      _message = null;
      if (field != null) _errors.remove(field);
    });
  }

  void _showInvalidFields() {
    for (final section in _sections) {
      section.expand();
    }
    setState(() => _message ??= 'Проверьте выделенные поля.');
  }

  String? _fieldError(String name) {
    final value = _errors[name];
    if (value is String && value.length <= 250) return value;
    if (value is List &&
        value.isNotEmpty &&
        value.first is String &&
        (value.first as String).length <= 250) {
      return value.first as String;
    }
    return value == null ? null : 'Проверьте это поле.';
  }

  Widget _text(
    String name,
    String label, {
    int limit = 200,
    int lines = 1,
    bool required = false,
    TextInputType? keyboard,
    String? help,
    String? Function(String)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('organization-$name'),
      controller: _fields[name],
      enabled: !_saving && !_uncertain && !_importing,
      maxLength: limit,
      maxLines: lines,
      keyboardType: keyboard,
      textInputAction: lines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: help,
        helperMaxLines: 4,
        counterText: '',
      ),
      validator: (raw) {
        final value = raw?.trim() ?? '';
        if (required && value.isEmpty) return 'Заполните это поле.';
        if (value.length > limit) return 'Не более $limit символов.';
        return validate?.call(value) ?? _fieldError(name);
      },
      onChanged: (_) => _changed(name),
    ),
  );

  String? _digits(String value, int length) {
    if (value.isEmpty) return null;
    return value.length == length && RegExp(r'^[0-9]+$').hasMatch(value)
        ? null
        : 'Укажите $length цифр.';
  }

  JsonMap _payload() => <String, Object?>{
    'kind': _kind,
    for (final name in _fields.keys)
      if (name != 'employee_count' && name != 'kpp')
        name: _fields[name]!.text.trim(),
    'kpp': _kind == 'llc' ? _fields['kpp']!.text.trim() : '',
    'employee_count': int.parse(_fields['employee_count']!.text.trim()),
    'has_applicants': _hasApplicants,
    'activity_start_date': _startDate == null
        ? null
        : '${_startDate!.year.toString().padLeft(4, '0')}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
  };

  bool _sameActor(String actor) {
    if (!mounted) return false;
    final auth = ref.read(authControllerProvider);
    return auth.phase == AuthPhase.authenticated && auth.user?.id == actor;
  }

  Future<void> _save() async {
    if (_saving || _saved || _importing) return;
    final auth = ref.read(authControllerProvider);
    if (auth.phase != AuthPhase.authenticated ||
        !ref.read(canCreateOrganizationProvider)) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _showInvalidFields();
      return;
    }
    final actor = auth.user!.id;
    final payload = _uncertain ? _requestData! : _payload();
    if (_requestData == null ||
        jsonEncode(payload) != jsonEncode(_requestData)) {
      _requestData = Map<String, Object?>.unmodifiable(payload);
      _requestKey = const Uuid().v4();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _message = null;
      _errors = {};
    });
    try {
      final created = await ref
          .read(repositoryProvider)
          .createOrganization(_requestData!, idempotencyKey: _requestKey!);
      if (!_sameActor(actor)) return;
      // The card is now saved. A local selection failure must not create it again.
      _saved = true;
      var selected = false;
      try {
        selected = await ref
            .read(organizationControllerProvider.notifier)
            .acceptCreated(created);
      } on Object {
        // Return to the server-backed list rather than replaying a saved create.
      }
      if (!_sameActor(actor)) return;
      if (!mounted) return;
      context.go(selected ? '/dashboard' : '/organizations');
      if (!selected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Организация создана. Выберите её в списке.'),
          ),
        );
      }
    } on AppError catch (error) {
      if (!_sameActor(actor) || _saved) return;
      final definite = <AppErrorKind>{
        AppErrorKind.validation,
        AppErrorKind.permission,
        AppErrorKind.authentication,
      }.contains(error.kind);
      setState(() {
        _errors = error.fields;
        _uncertain = !definite;
        _message = _uncertain
            ? 'Не удалось подтвердить создание. Повторите отправку: тот же запрос не создаст дубликат.'
            : safeUiError(error);
      });
      if (!_formKey.currentState!.validate()) _showInvalidFields();
    } on Object {
      if (_sameActor(actor) && !_saved) {
        setState(() {
          _uncertain = true;
          _message = 'Ответ не удалось проверить. Повторите тот же запрос без создания дубликата.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importExtract() async {
    if (_saving ||
        _saved ||
        _uncertain ||
        _importing ||
        !ref.read(canCreateOrganizationProvider)) {
      return;
    }
    final actor = ref.read(authControllerProvider).user!.id;
    setState(() => _importing = true);
    try {
      final preview = await showDialog<FnsExtractPreviewDto>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FnsExtractDialog(
          initialInn: _fields['inn']!.text.trim(),
          isAllowed: () =>
              _sameActor(actor) && ref.read(canCreateOrganizationProvider),
        ),
      );
      if (!_sameActor(actor) ||
          !ref.read(canCreateOrganizationProvider) ||
          preview == null) {
        return;
      }
      setState(() {
        _kind = preview.kind;
        final fields = <String, String?>{
          'inn': preview.inn,
          'ogrn': preview.ogrn,
          'full_name': preview.fullName,
          'short_name': preview.shortName,
          'kpp': preview.kpp,
          'legal_address': preview.legalAddress,
          'okved': preview.okved,
          'leader_name': null,
        };
        for (final entry in fields.entries) {
          _fields[entry.key]!.text = entry.value ?? '';
        }
        _dirty = true;
        _message = null;
        _errors = {};
        _requestData = null;
        _requestKey = null;
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _lookupInn() async {
    if (_saving ||
        _saved ||
        _uncertain ||
        _importing ||
        !ref.read(canCreateOrganizationProvider)) {
      return;
    }
    final inn = _fields['inn']!.text.trim();
    if (!validRegistryInn(inn)) {
      setState(
        () => _message =
            'Проверьте ИНН: нужны 10 или 12 цифр с верной контрольной суммой.',
      );
      return;
    }
    final actor = ref.read(authControllerProvider).user!.id;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _importing = true;
      _message = null;
    });
    try {
      final preview = await showDialog<RegistryPreviewDto>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RegistryLookupDialog(
          inn: inn,
          isAllowed: () =>
              _sameActor(actor) && ref.read(canCreateOrganizationProvider),
        ),
      );
      if (!_sameActor(actor) ||
          !ref.read(canCreateOrganizationProvider) ||
          preview == null ||
          _fields['inn']!.text.trim() != inn) {
        return;
      }
      setState(() {
        _kind = preview.kind;
        for (final entry in <String, String?>{
          'inn': preview.inn,
          'ogrn': preview.ogrn,
          'full_name': preview.fullName,
          'short_name': preview.shortName,
          'kpp': preview.kpp,
          'legal_address': preview.legalAddress,
          'leader_name': preview.leaderName,
          'okved': preview.okved,
        }.entries) {
          _fields[entry.key]!.text = entry.value ?? '';
        }
        _dirty = true;
        _errors = {};
        _message = null;
        _requestData = null;
        _requestKey = null;
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      _startDate = date;
      _changed();
    }
  }

  Widget _section(int index, String title, List<Widget> children) =>
      ExpansionTile(
        controller: _sections[index],
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        title: Text(title),
        children: children,
      );

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canCreateOrganizationProvider);
    final enabled = !_saving && !_uncertain && !_importing;
    return ComplianceScaffold(
      showOrganization: false,
      appBar: AppBar(title: const Text('Новая организация')),
      // Selection temporarily removes the active context after a successful
      // create. Keep the already authorized, disabled form until it finishes.
      body: !canCreate && !_saving && !_importing
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Создание недоступно',
              message: 'Организации добавляет владелец или администратор пилота. Попросите предоставить вам нужный доступ.',
            )
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Основные сведения',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Введите ИНН и заполните реквизиты автоматически или укажите сведения вручную.',
                    ),
                    const SizedBox(height: 20),
                    _text(
                      'inn',
                      'ИНН',
                      limit: 12,
                      keyboard: TextInputType.number,
                      validate: (v) => _digits(v, _kind == 'ie' ? 12 : 10),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('organization-lookup-inn'),
                      onPressed: enabled ? _lookupInn : null,
                      icon: const Icon(Icons.search),
                      label: const Text('Заполнить по ИНН'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'При нажатии ИНН передаётся в DaData для поиска открытых реквизитов. Перед сохранением вы сможете их проверить.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('organization-fns-import'),
                      onPressed: enabled ? _importExtract : null,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Заполнить из выписки ФНС'),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('organization-kind'),
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Форма организации *',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'llc', child: Text('ООО')),
                        DropdownMenuItem(value: 'ie', child: Text('ИП')),
                      ],
                      onChanged: enabled
                          ? (value) {
                              _kind = value ?? 'llc';
                              _changed();
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _text(
                      'short_name',
                      'Краткое название',
                      required: true,
                      limit: 160,
                    ),
                    _text(
                      'full_name',
                      'Полное наименование',
                      required: true,
                      limit: 300,
                      lines: 2,
                    ),
                    _section(0, 'Реквизиты', [
                      if (_kind == 'llc')
                        _text(
                          'kpp',
                          'КПП',
                          limit: 9,
                          keyboard: TextInputType.number,
                          validate: (v) => _digits(v, 9),
                        ),
                      _text(
                        'ogrn',
                        _kind == 'ie' ? 'ОГРНИП' : 'ОГРН',
                        limit: 15,
                        keyboard: TextInputType.number,
                        validate: (v) => _digits(v, _kind == 'ie' ? 15 : 13),
                      ),
                      _text(
                        'leader_name',
                        _kind == 'ie' ? 'ФИО ИП' : 'Руководитель',
                        help:
                            'ФИО сохраняется в карточке и не передаётся в AI.',
                      ),
                      _text('tax_regime', 'Налоговый режим', limit: 80),
                      _text('okved', 'Основные ОКВЭД', limit: 300),
                    ]),
                    _section(1, 'Адреса и контакты', [
                      _text(
                        'legal_address',
                        'Юридический адрес',
                        limit: 2000,
                        lines: 2,
                        help: 'Адрес из регистрационных сведений.',
                      ),
                      _text(
                        'actual_address',
                        'Фактический адрес',
                        limit: 2000,
                        lines: 2,
                      ),
                      _text(
                        'contact_email',
                        'Контактный email',
                        limit: 254,
                        keyboard: TextInputType.emailAddress,
                        validate: (v) =>
                            v.isEmpty ||
                                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(v)
                            ? null
                            : 'Проверьте адрес почты.',
                      ),
                      _text(
                        'contact_phone',
                        'Контактный телефон',
                        limit: 40,
                        keyboard: TextInputType.phone,
                      ),
                    ]),
                    _section(2, 'Деятельность', [
                      _text(
                        'employee_count',
                        'Количество сотрудников',
                        required: true,
                        limit: 10,
                        keyboard: TextInputType.number,
                        validate: (v) {
                          final n = int.tryParse(v);
                          return n != null && n >= 0 && n <= 2147483647
                              ? null
                              : 'Укажите целое число от 0 до 2147483647.';
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Есть соискатели'),
                        value: _hasApplicants,
                        onChanged: enabled
                            ? (v) {
                                _hasApplicants = v;
                                _changed();
                              }
                            : null,
                      ),
                      _text(
                        'privacy_responsible',
                        'Ответственный за персональные данные',
                        help: 'ФИО или статус назначения; в AI не передаётся.',
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Дата начала деятельности'),
                        subtitle: Text(
                          _startDate == null
                              ? 'Не указана'
                              : '${_startDate!.day.toString().padLeft(2, '0')}.${_startDate!.month.toString().padLeft(2, '0')}.${_startDate!.year}',
                        ),
                        onTap: enabled ? _pickDate : null,
                        trailing: _startDate == null
                            ? null
                            : IconButton(
                                tooltip: 'Очистить дату',
                                icon: const Icon(Icons.close),
                                onPressed: enabled
                                    ? () {
                                        _startDate = null;
                                        _changed();
                                      }
                                    : null,
                              ),
                      ),
                    ]),
                    _section(3, 'Заметки', [
                      _text(
                        'notes',
                        'Дополнительные сведения',
                        limit: 4000,
                        lines: 4,
                        help: 'Только необходимые сведения, которые вы вправе обрабатывать.',
                      ),
                    ]),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
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
                                _message!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('organization-create-submit'),
                      onPressed: _saving || _saved || _importing ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _uncertain
                                  ? Icons.refresh
                                  : Icons.add_business_outlined,
                            ),
                      label: Text(
                        _saving
                            ? 'Создаём организацию…'
                            : _uncertain
                            ? 'Повторить отправку'
                            : 'Создать организацию',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saving ? null : () => context.pop(),
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
