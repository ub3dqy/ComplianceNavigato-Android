import '../errors/app_error.dart';

String safeUiError(Object error, {String? fallback}) => error is AppError
    ? error.safeMessage
    : fallback ?? 'Не удалось выполнить действие. Повторите попытку.';

String humanStatus(Object? value) => switch (value?.toString()) {
  'active' => 'Активно',
  'cancelled' => 'Отменено',
  'completed' => 'Выполнено',
  'draft' => 'Черновик',
  'expired' => 'Срок истёк',
  'failed' => 'Ошибка',
  'generated' => 'Сформировано',
  'in_progress' => 'Выполняется',
  'needs_review' => 'Требует проверки',
  'open' => 'Открыто',
  'pending' => 'Ожидает действия',
  'queued' => 'В очереди',
  'ready' => 'Готово',
  'running' => 'Выполняется',
  'uploaded' => 'Загружено',
  null || '' => 'Статус не указан',
  _ => 'Требует проверки',
};

String humanSeverity(Object? value) => switch (value?.toString()) {
  'critical' => 'Критический риск',
  'high' => 'Высокий риск',
  'medium' => 'Средний риск',
  'low' => 'Низкий риск',
  'info' => 'Информация',
  null || '' => 'Риск не указан',
  _ => 'Риск требует проверки',
};

String humanProgressMessage(Object? value) {
  final String text = value?.toString().trim() ?? '';
  final String normalized = text.toLowerCase();
  final String? known = switch (normalized) {
    'queued' => 'Проверка ожидает запуска',
    'running' || 'in_progress' => 'Идёт проверка',
    'completed' => 'Проверка завершена',
    'cancelled' => 'Проверка отменена',
    'failed' => 'Проверка завершилась ошибкой',
    _ => null,
  };
  if (known != null) {
    return known;
  }
  if (text.isEmpty) {
    return '';
  }
  return RegExp(r'[А-Яа-яЁё]').hasMatch(text) ? text : 'Статус обновлён';
}

String humanConfidence(Object? value) => switch (value?.toString()) {
  'high' => 'Высокая',
  'medium' => 'Средняя',
  'low' => 'Низкая',
  _ => 'Требует проверки',
};

String humanDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, '
      '${two(local.hour)}:${two(local.minute)}';
}

String humanRole(Object? value) => switch (value?.toString()) {
  'owner' => 'Владелец',
  'editor' => 'Редактор',
  'viewer' => 'Просмотр',
  _ => 'Роль не указана',
};

String humanOrganizationKind(Object? value) => switch (value?.toString()) {
  'llc' => 'ООО',
  'individual_entrepreneur' || 'ie' => 'ИП',
  'self_employed' => 'Самозанятый',
  _ => 'Организация',
};

String humanLocation(Object? value) => switch (value?.toString()) {
  'russian' => 'Российская инфраструктура',
  'foreign' => 'Иностранная инфраструктура',
  'unknown' => 'Расположение нужно уточнить',
  _ => humanStatus(value),
};
String humanAgreement(Object? value) => switch (value?.toString()) {
  'yes' => 'Договор есть',
  'no' => 'Договора нет',
  'unknown' => 'Договор нужно уточнить',
  _ => humanStatus(value),
};
