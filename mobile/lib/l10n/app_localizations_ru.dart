// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Комплаенс-Навигатор Pilot';

  @override
  String get loginTitle => 'Вход в закрытый пилот';

  @override
  String get email => 'Электронная почта';

  @override
  String get password => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get mfaTitle => 'Проверка входа';

  @override
  String get mfaCode => 'Код из приложения';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get download => 'Скачать';

  @override
  String get share => 'Поделиться';

  @override
  String get open => 'Открыть';

  @override
  String get refresh => 'Обновить';

  @override
  String get logout => 'Выйти';

  @override
  String get dashboard => 'Главная';

  @override
  String get questionnaire => 'Анкета';

  @override
  String get tasks => 'Задачи';

  @override
  String get assistant => 'Помощник';

  @override
  String get more => 'Ещё';

  @override
  String get organizations => 'Выбор организации';

  @override
  String get websites => 'Сайты';

  @override
  String get externalServices => 'Сервисы и страны';

  @override
  String get assessments => 'Оценки';

  @override
  String get scanner => 'Проверка сайтов';

  @override
  String get documents => 'Документы';

  @override
  String get evidence => 'Подтверждения';

  @override
  String get reports => 'Отчёты';

  @override
  String get audit => 'Журнал действий';

  @override
  String get settings => 'Настройки';

  @override
  String get about => 'О приложении';

  @override
  String get offline => 'Нет соединения. Данные текущей сессии не удалены.';

  @override
  String get emptyState => 'Пока ничего нет';

  @override
  String get loading => 'Загрузка…';

  @override
  String get needsReview => 'Требует проверки';

  @override
  String get completed => 'Выполнено';

  @override
  String get actionRequired => 'Требует действия';

  @override
  String get deterministicPriority =>
      'Детерминированный результат имеет приоритет над AI-объяснением.';

  @override
  String get aiNoticeTitle => 'Перед началом разговора';

  @override
  String get aiNoticeConfirm =>
      'Я не буду указывать персональные данные физических лиц';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get reject => 'Отклонить';

  @override
  String get helpful => 'Полезно';

  @override
  String get notHelpful => 'Не полезно';

  @override
  String get errorFeedback => 'Ошибка';

  @override
  String get reviewFeedback => 'Требует проверки';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get biometricUnlock => 'Локальная биометрическая блокировка';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get sessionExpired => 'Сессия завершена. Войдите снова.';

  @override
  String get unsavedWarning =>
      'Есть несохранённые изменения. Уйти со страницы?';

  @override
  String get conflictMessage =>
      'Данные изменились на сервере. Обновите их и повторите действие вручную.';

  @override
  String get permissionDenied => 'Недостаточно прав для этого действия.';

  @override
  String get serverUnavailable =>
      'Сервис временно недоступен. Повторите позже.';
}
