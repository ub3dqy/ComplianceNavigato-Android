import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Комплаенс-Навигатор Pilot'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в закрытый пилот'**
  String get loginTitle;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Электронная почта'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @mfaTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка входа'**
  String get mfaTitle;

  /// No description provided for @mfaCode.
  ///
  /// In ru, this message translates to:
  /// **'Код из приложения'**
  String get mfaCode;

  /// No description provided for @continueAction.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get continueAction;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @download.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get download;

  /// No description provided for @share.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get share;

  /// No description provided for @open.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get open;

  /// No description provided for @refresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get refresh;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @dashboard.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get dashboard;

  /// No description provided for @questionnaire.
  ///
  /// In ru, this message translates to:
  /// **'Анкета'**
  String get questionnaire;

  /// No description provided for @tasks.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get tasks;

  /// No description provided for @assistant.
  ///
  /// In ru, this message translates to:
  /// **'Помощник'**
  String get assistant;

  /// No description provided for @more.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// No description provided for @organizations.
  ///
  /// In ru, this message translates to:
  /// **'Выбор организации'**
  String get organizations;

  /// No description provided for @websites.
  ///
  /// In ru, this message translates to:
  /// **'Сайты'**
  String get websites;

  /// No description provided for @externalServices.
  ///
  /// In ru, this message translates to:
  /// **'Сервисы и страны'**
  String get externalServices;

  /// No description provided for @assessments.
  ///
  /// In ru, this message translates to:
  /// **'Оценки'**
  String get assessments;

  /// No description provided for @scanner.
  ///
  /// In ru, this message translates to:
  /// **'Проверка сайтов'**
  String get scanner;

  /// No description provided for @documents.
  ///
  /// In ru, this message translates to:
  /// **'Документы'**
  String get documents;

  /// No description provided for @evidence.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждения'**
  String get evidence;

  /// No description provided for @reports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get reports;

  /// No description provided for @audit.
  ///
  /// In ru, this message translates to:
  /// **'Журнал действий'**
  String get audit;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get about;

  /// No description provided for @offline.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения. Данные текущей сессии не удалены.'**
  String get offline;

  /// No description provided for @emptyState.
  ///
  /// In ru, this message translates to:
  /// **'Пока ничего нет'**
  String get emptyState;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get loading;

  /// No description provided for @needsReview.
  ///
  /// In ru, this message translates to:
  /// **'Требует проверки'**
  String get needsReview;

  /// No description provided for @completed.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено'**
  String get completed;

  /// No description provided for @actionRequired.
  ///
  /// In ru, this message translates to:
  /// **'Требует действия'**
  String get actionRequired;

  /// No description provided for @deterministicPriority.
  ///
  /// In ru, this message translates to:
  /// **'Детерминированный результат имеет приоритет над AI-объяснением.'**
  String get deterministicPriority;

  /// No description provided for @aiNoticeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Перед началом разговора'**
  String get aiNoticeTitle;

  /// No description provided for @aiNoticeConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Я не буду указывать персональные данные физических лиц'**
  String get aiNoticeConfirm;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @reject.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get reject;

  /// No description provided for @helpful.
  ///
  /// In ru, this message translates to:
  /// **'Полезно'**
  String get helpful;

  /// No description provided for @notHelpful.
  ///
  /// In ru, this message translates to:
  /// **'Не полезно'**
  String get notHelpful;

  /// No description provided for @errorFeedback.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get errorFeedback;

  /// No description provided for @reviewFeedback.
  ///
  /// In ru, this message translates to:
  /// **'Требует проверки'**
  String get reviewFeedback;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @biometricUnlock.
  ///
  /// In ru, this message translates to:
  /// **'Локальная биометрическая блокировка'**
  String get biometricUnlock;

  /// No description provided for @unlock.
  ///
  /// In ru, this message translates to:
  /// **'Разблокировать'**
  String get unlock;

  /// No description provided for @diagnostics.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get diagnostics;

  /// No description provided for @sessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия завершена. Войдите снова.'**
  String get sessionExpired;

  /// No description provided for @unsavedWarning.
  ///
  /// In ru, this message translates to:
  /// **'Есть несохранённые изменения. Уйти со страницы?'**
  String get unsavedWarning;

  /// No description provided for @conflictMessage.
  ///
  /// In ru, this message translates to:
  /// **'Данные изменились на сервере. Обновите их и повторите действие вручную.'**
  String get conflictMessage;

  /// No description provided for @permissionDenied.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для этого действия.'**
  String get permissionDenied;

  /// No description provided for @serverUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сервис временно недоступен. Повторите позже.'**
  String get serverUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
