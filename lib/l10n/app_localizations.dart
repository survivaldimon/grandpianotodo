import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'Kabinet'**
  String get appName;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get error;

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

  /// No description provided for @archive.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать'**
  String get archive;

  /// No description provided for @restore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get restore;

  /// No description provided for @edit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get add;

  /// No description provided for @create.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

  /// No description provided for @search.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get search;

  /// No description provided for @noData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noData;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get no;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// No description provided for @next.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get next;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @apply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get apply;

  /// No description provided for @reset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get reset;

  /// No description provided for @all.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get all;

  /// No description provided for @select.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get select;

  /// No description provided for @copy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get share;

  /// No description provided for @more.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// No description provided for @less.
  ///
  /// In ru, this message translates to:
  /// **'Меньше'**
  String get less;

  /// No description provided for @show.
  ///
  /// In ru, this message translates to:
  /// **'Показать'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть'**
  String get hide;

  /// No description provided for @optional.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно'**
  String get optional;

  /// No description provided for @required.
  ///
  /// In ru, this message translates to:
  /// **'Обязательно'**
  String get required;

  /// No description provided for @or.
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get or;

  /// No description provided for @and.
  ///
  /// In ru, this message translates to:
  /// **'и'**
  String get and;

  /// No description provided for @from.
  ///
  /// In ru, this message translates to:
  /// **'от'**
  String get from;

  /// No description provided for @to.
  ///
  /// In ru, this message translates to:
  /// **'до'**
  String get to;

  /// No description provided for @tenge.
  ///
  /// In ru, this message translates to:
  /// **'тг'**
  String get tenge;

  /// No description provided for @login.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите пароль'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In ru, this message translates to:
  /// **'Полное имя'**
  String get fullName;

  /// No description provided for @forgotPassword.
  ///
  /// In ru, this message translates to:
  /// **'Забыли пароль?'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить пароль'**
  String get resetPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление пароля'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordMessage.
  ///
  /// In ru, this message translates to:
  /// **'Введите email, указанный при регистрации. Мы отправим вам ссылку для сброса пароля.'**
  String get resetPasswordMessage;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Письмо отправлено! Проверьте свою почту.'**
  String get resetPasswordSuccess;

  /// No description provided for @noAccount.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта?'**
  String get noAccount;

  /// No description provided for @hasAccount.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт?'**
  String get hasAccount;

  /// No description provided for @loginWithGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithApple.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Apple'**
  String get loginWithApple;

  /// No description provided for @newPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get newPassword;

  /// No description provided for @setNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Задать новый пароль'**
  String get setNewPassword;

  /// No description provided for @setNewPasswordDescription.
  ///
  /// In ru, this message translates to:
  /// **'Установите новый пароль'**
  String get setNewPasswordDescription;

  /// No description provided for @savePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить пароль'**
  String get savePassword;

  /// No description provided for @passwordChangeError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка смены пароля: {error}'**
  String passwordChangeError(String error);

  /// No description provided for @passwordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль успешно изменён'**
  String get passwordChanged;

  /// No description provided for @registrationSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация успешна!'**
  String get registrationSuccess;

  /// No description provided for @passwordRequirements.
  ///
  /// In ru, this message translates to:
  /// **'Мин. 8 символов, заглавная буква, спецсимвол'**
  String get passwordRequirements;

  /// No description provided for @institutions.
  ///
  /// In ru, this message translates to:
  /// **'Заведения'**
  String get institutions;

  /// No description provided for @createInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Создать заведение'**
  String get createInstitution;

  /// No description provided for @joinInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться'**
  String get joinInstitution;

  /// No description provided for @institutionName.
  ///
  /// In ru, this message translates to:
  /// **'Название заведения'**
  String get institutionName;

  /// No description provided for @inviteCode.
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения'**
  String get inviteCode;

  /// No description provided for @institutionNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Музыкальная школа №1'**
  String get institutionNameHint;

  /// No description provided for @inviteCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: ABC12345'**
  String get inviteCodeHint;

  /// No description provided for @inviteCodeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Введите код приглашения, который вам прислал администратор заведения'**
  String get inviteCodeDescription;

  /// No description provided for @joinedInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Вы присоединились к \"{name}\"'**
  String joinedInstitution(String name);

  /// No description provided for @owner.
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get owner;

  /// No description provided for @member.
  ///
  /// In ru, this message translates to:
  /// **'Участник'**
  String get member;

  /// No description provided for @admin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get admin;

  /// No description provided for @teacher.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель'**
  String get teacher;

  /// No description provided for @noInstitutions.
  ///
  /// In ru, this message translates to:
  /// **'Нет заведений'**
  String get noInstitutions;

  /// No description provided for @createOrJoin.
  ///
  /// In ru, this message translates to:
  /// **'Создайте новое или присоединитесь'**
  String get createOrJoin;

  /// No description provided for @dashboard.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get dashboard;

  /// No description provided for @rooms.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты'**
  String get rooms;

  /// No description provided for @students.
  ///
  /// In ru, this message translates to:
  /// **'Ученики'**
  String get students;

  /// No description provided for @payments.
  ///
  /// In ru, this message translates to:
  /// **'Оплаты'**
  String get payments;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @statistics.
  ///
  /// In ru, this message translates to:
  /// **'Статистика'**
  String get statistics;

  /// No description provided for @groups.
  ///
  /// In ru, this message translates to:
  /// **'Группы'**
  String get groups;

  /// No description provided for @schedule.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get schedule;

  /// No description provided for @room.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get room;

  /// No description provided for @roomName.
  ///
  /// In ru, this message translates to:
  /// **'Название кабинета'**
  String get roomName;

  /// No description provided for @roomNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер кабинета'**
  String get roomNumber;

  /// No description provided for @addRoom.
  ///
  /// In ru, this message translates to:
  /// **'Добавить кабинет'**
  String get addRoom;

  /// No description provided for @editRoom.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать кабинет'**
  String get editRoom;

  /// No description provided for @deleteRoom.
  ///
  /// In ru, this message translates to:
  /// **'Удалить кабинет'**
  String get deleteRoom;

  /// No description provided for @noRooms.
  ///
  /// In ru, this message translates to:
  /// **'Нет кабинетов'**
  String get noRooms;

  /// No description provided for @addRoomFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте кабинет'**
  String get addRoomFirst;

  /// No description provided for @roomDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет удалён'**
  String get roomDeleted;

  /// No description provided for @roomUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет обновлён'**
  String get roomUpdated;

  /// No description provided for @roomCreated.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет создан'**
  String get roomCreated;

  /// No description provided for @roomColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет кабинета'**
  String get roomColor;

  /// No description provided for @roomOccupied.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет занят в это время'**
  String get roomOccupied;

  /// No description provided for @today.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get tomorrow;

  /// No description provided for @lesson.
  ///
  /// In ru, this message translates to:
  /// **'Занятие'**
  String get lesson;

  /// No description provided for @lessons.
  ///
  /// In ru, this message translates to:
  /// **'Занятия'**
  String get lessons;

  /// No description provided for @newLesson.
  ///
  /// In ru, this message translates to:
  /// **'Новое занятие'**
  String get newLesson;

  /// No description provided for @editLesson.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать занятие'**
  String get editLesson;

  /// No description provided for @deleteLesson.
  ///
  /// In ru, this message translates to:
  /// **'Удалить занятие'**
  String get deleteLesson;

  /// No description provided for @lessonType.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия'**
  String get lessonType;

  /// No description provided for @subject.
  ///
  /// In ru, this message translates to:
  /// **'Предмет'**
  String get subject;

  /// No description provided for @date.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get date;

  /// No description provided for @time.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get time;

  /// No description provided for @startTime.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In ru, this message translates to:
  /// **'Окончание'**
  String get endTime;

  /// No description provided for @duration.
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get duration;

  /// No description provided for @minutes.
  ///
  /// In ru, this message translates to:
  /// **'мин'**
  String get minutes;

  /// No description provided for @comment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get comment;

  /// No description provided for @noLessons.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий'**
  String get noLessons;

  /// No description provided for @noLessonsToday.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий сегодня'**
  String get noLessonsToday;

  /// No description provided for @lessonsToday.
  ///
  /// In ru, this message translates to:
  /// **'Занятия сегодня'**
  String get lessonsToday;

  /// No description provided for @nextLesson.
  ///
  /// In ru, this message translates to:
  /// **'Ближайшее занятие'**
  String get nextLesson;

  /// No description provided for @selectDate.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дату'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время'**
  String get selectTime;

  /// No description provided for @selectRoom.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинет'**
  String get selectRoom;

  /// No description provided for @selectStudent.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика'**
  String get selectStudent;

  /// No description provided for @selectSubject.
  ///
  /// In ru, this message translates to:
  /// **'Выберите предмет'**
  String get selectSubject;

  /// No description provided for @selectTeacher.
  ///
  /// In ru, this message translates to:
  /// **'Выберите преподавателя'**
  String get selectTeacher;

  /// No description provided for @selectLessonType.
  ///
  /// In ru, this message translates to:
  /// **'Выберите тип занятия'**
  String get selectLessonType;

  /// No description provided for @repeatLesson.
  ///
  /// In ru, this message translates to:
  /// **'Повторять занятие'**
  String get repeatLesson;

  /// No description provided for @repeatWeekly.
  ///
  /// In ru, this message translates to:
  /// **'Каждую неделю'**
  String get repeatWeekly;

  /// No description provided for @repeatCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество повторений'**
  String get repeatCount;

  /// No description provided for @quickAdd.
  ///
  /// In ru, this message translates to:
  /// **'Быстрое добавление'**
  String get quickAdd;

  /// No description provided for @scheduled.
  ///
  /// In ru, this message translates to:
  /// **'Запланировано'**
  String get scheduled;

  /// No description provided for @completed.
  ///
  /// In ru, this message translates to:
  /// **'Проведено'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменено'**
  String get cancelled;

  /// No description provided for @rescheduled.
  ///
  /// In ru, this message translates to:
  /// **'Перенесено'**
  String get rescheduled;

  /// No description provided for @markCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Отметить проведённым'**
  String get markCompleted;

  /// No description provided for @markCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменить занятие'**
  String get markCancelled;

  /// No description provided for @unmarkedLessons.
  ///
  /// In ru, this message translates to:
  /// **'Неотмеченные занятия'**
  String get unmarkedLessons;

  /// No description provided for @noUnmarkedLessons.
  ///
  /// In ru, this message translates to:
  /// **'Нет неотмеченных занятий'**
  String get noUnmarkedLessons;

  /// No description provided for @lessonCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Занятие проведено'**
  String get lessonCompleted;

  /// No description provided for @lessonCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Занятие отменено'**
  String get lessonCancelled;

  /// No description provided for @lessonDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Занятие удалено'**
  String get lessonDeleted;

  /// No description provided for @lessonCreated.
  ///
  /// In ru, this message translates to:
  /// **'Занятие создано'**
  String get lessonCreated;

  /// No description provided for @lessonUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Занятие обновлено'**
  String get lessonUpdated;

  /// No description provided for @student.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get student;

  /// No description provided for @studentName.
  ///
  /// In ru, this message translates to:
  /// **'Имя ученика'**
  String get studentName;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phone;

  /// No description provided for @addStudent.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ученика'**
  String get addStudent;

  /// No description provided for @editStudent.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать ученика'**
  String get editStudent;

  /// No description provided for @deleteStudent.
  ///
  /// In ru, this message translates to:
  /// **'Удалить ученика'**
  String get deleteStudent;

  /// No description provided for @archiveStudent.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать ученика'**
  String get archiveStudent;

  /// No description provided for @unarchiveStudent.
  ///
  /// In ru, this message translates to:
  /// **'Разархивировать'**
  String get unarchiveStudent;

  /// No description provided for @prepaidLessons.
  ///
  /// In ru, this message translates to:
  /// **'Предоплаченных занятий'**
  String get prepaidLessons;

  /// No description provided for @debt.
  ///
  /// In ru, this message translates to:
  /// **'Долг'**
  String get debt;

  /// No description provided for @individualLesson.
  ///
  /// In ru, this message translates to:
  /// **'Индивидуальное'**
  String get individualLesson;

  /// No description provided for @groupLesson.
  ///
  /// In ru, this message translates to:
  /// **'Групповое'**
  String get groupLesson;

  /// No description provided for @noStudents.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников'**
  String get noStudents;

  /// No description provided for @addStudentFirst.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первого ученика'**
  String get addStudentFirst;

  /// No description provided for @studentDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Ученик удалён'**
  String get studentDeleted;

  /// No description provided for @studentArchived.
  ///
  /// In ru, this message translates to:
  /// **'Ученик архивирован'**
  String get studentArchived;

  /// No description provided for @studentUnarchived.
  ///
  /// In ru, this message translates to:
  /// **'Ученик разархивирован'**
  String get studentUnarchived;

  /// No description provided for @studentUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Ученик обновлён'**
  String get studentUpdated;

  /// No description provided for @studentCreated.
  ///
  /// In ru, this message translates to:
  /// **'Ученик добавлен'**
  String get studentCreated;

  /// No description provided for @showArchived.
  ///
  /// In ru, this message translates to:
  /// **'Показать архив'**
  String get showArchived;

  /// No description provided for @hideArchived.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть архив'**
  String get hideArchived;

  /// No description provided for @mergeStudents.
  ///
  /// In ru, this message translates to:
  /// **'Объединить учеников'**
  String get mergeStudents;

  /// No description provided for @mergeWith.
  ///
  /// In ru, this message translates to:
  /// **'Объединить с...'**
  String get mergeWith;

  /// No description provided for @parentName.
  ///
  /// In ru, this message translates to:
  /// **'Имя родителя'**
  String get parentName;

  /// No description provided for @parentPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон родителя'**
  String get parentPhone;

  /// No description provided for @notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get notes;

  /// No description provided for @debtors.
  ///
  /// In ru, this message translates to:
  /// **'Должники'**
  String get debtors;

  /// No description provided for @noDebtors.
  ///
  /// In ru, this message translates to:
  /// **'Должников нет'**
  String get noDebtors;

  /// No description provided for @group.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get group;

  /// No description provided for @groupName.
  ///
  /// In ru, this message translates to:
  /// **'Название группы'**
  String get groupName;

  /// No description provided for @addGroup.
  ///
  /// In ru, this message translates to:
  /// **'Добавить группу'**
  String get addGroup;

  /// No description provided for @editGroup.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать группу'**
  String get editGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In ru, this message translates to:
  /// **'Удалить группу'**
  String get deleteGroup;

  /// No description provided for @archiveGroup.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать группу'**
  String get archiveGroup;

  /// No description provided for @members.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get members;

  /// No description provided for @addMember.
  ///
  /// In ru, this message translates to:
  /// **'Добавить участника'**
  String get addMember;

  /// No description provided for @noGroups.
  ///
  /// In ru, this message translates to:
  /// **'Нет групп'**
  String get noGroups;

  /// No description provided for @groupDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Группа удалена'**
  String get groupDeleted;

  /// No description provided for @groupArchived.
  ///
  /// In ru, this message translates to:
  /// **'Группа архивирована'**
  String get groupArchived;

  /// No description provided for @groupUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Группа обновлена'**
  String get groupUpdated;

  /// No description provided for @groupCreated.
  ///
  /// In ru, this message translates to:
  /// **'Группа создана'**
  String get groupCreated;

  /// No description provided for @selectStudents.
  ///
  /// In ru, this message translates to:
  /// **'Выберите учеников'**
  String get selectStudents;

  /// No description provided for @minTwoStudents.
  ///
  /// In ru, this message translates to:
  /// **'Выберите минимум 2 ученика'**
  String get minTwoStudents;

  /// No description provided for @participants.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get participants;

  /// No description provided for @participantsCount.
  ///
  /// In ru, this message translates to:
  /// **'УЧАСТНИКИ ({count})'**
  String participantsCount(int count);

  /// No description provided for @addParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Добавить участников'**
  String get addParticipants;

  /// No description provided for @selectStudentsForGroup.
  ///
  /// In ru, this message translates to:
  /// **'Выберите учеников для группы'**
  String get selectStudentsForGroup;

  /// No description provided for @searchStudent.
  ///
  /// In ru, this message translates to:
  /// **'Поиск ученика...'**
  String get searchStudent;

  /// No description provided for @createNewStudent.
  ///
  /// In ru, this message translates to:
  /// **'Создать нового ученика'**
  String get createNewStudent;

  /// No description provided for @allStudentsInGroup.
  ///
  /// In ru, this message translates to:
  /// **'Все ученики уже в группе'**
  String get allStudentsInGroup;

  /// No description provided for @noAvailableStudents.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных учеников'**
  String get noAvailableStudents;

  /// No description provided for @resetSearch.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить поиск'**
  String get resetSearch;

  /// No description provided for @balanceColon.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {count}'**
  String balanceColon(int count);

  /// No description provided for @removeFromGroup.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из группы'**
  String get removeFromGroup;

  /// No description provided for @removeStudentFromGroupQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из группы?'**
  String get removeStudentFromGroupQuestion;

  /// No description provided for @removeStudentFromGroupMessage.
  ///
  /// In ru, this message translates to:
  /// **'Удалить {name} из группы?'**
  String removeStudentFromGroupMessage(String name);

  /// No description provided for @studentAddedToGroup.
  ///
  /// In ru, this message translates to:
  /// **'Ученик добавлен в группу'**
  String get studentAddedToGroup;

  /// No description provided for @studentsAddedCount.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено учеников: {count}'**
  String studentsAddedCount(int count);

  /// No description provided for @newStudent.
  ///
  /// In ru, this message translates to:
  /// **'Новый ученик'**
  String get newStudent;

  /// No description provided for @studentCreatedAndSelected.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" создан и выбран'**
  String studentCreatedAndSelected(String name);

  /// No description provided for @archiveGroupConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать группу?'**
  String get archiveGroupConfirmation;

  /// No description provided for @archiveGroupMessage.
  ///
  /// In ru, this message translates to:
  /// **'Группа \"{name}\" будет перемещена в архив. Вы сможете восстановить её позже.'**
  String archiveGroupMessage(String name);

  /// No description provided for @noParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Нет участников'**
  String get noParticipants;

  /// No description provided for @addStudentsToGroup.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте учеников в группу'**
  String get addStudentsToGroup;

  /// No description provided for @createFirstGroup.
  ///
  /// In ru, this message translates to:
  /// **'Создайте первую группу учеников'**
  String get createFirstGroup;

  /// No description provided for @createGroup.
  ///
  /// In ru, this message translates to:
  /// **'Создать группу'**
  String get createGroup;

  /// No description provided for @newGroup.
  ///
  /// In ru, this message translates to:
  /// **'Новая группа'**
  String get newGroup;

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get nothingFound;

  /// No description provided for @lessonsCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий:'**
  String lessonsCountLabel(int count);

  /// No description provided for @selectedColon.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count}'**
  String selectedColon(int count);

  /// No description provided for @addCount.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ({count})'**
  String addCount(int count);

  /// No description provided for @payment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get payment;

  /// No description provided for @addPayment.
  ///
  /// In ru, this message translates to:
  /// **'Добавить оплату'**
  String get addPayment;

  /// No description provided for @editPayment.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать оплату'**
  String get editPayment;

  /// No description provided for @deletePayment.
  ///
  /// In ru, this message translates to:
  /// **'Удалить оплату'**
  String get deletePayment;

  /// No description provided for @amount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get amount;

  /// No description provided for @lessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий'**
  String get lessonsCount;

  /// No description provided for @paymentPlan.
  ///
  /// In ru, this message translates to:
  /// **'Тариф'**
  String get paymentPlan;

  /// No description provided for @paidAt.
  ///
  /// In ru, this message translates to:
  /// **'Дата оплаты'**
  String get paidAt;

  /// No description provided for @correction.
  ///
  /// In ru, this message translates to:
  /// **'Корректировка'**
  String get correction;

  /// No description provided for @correctionReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина корректировки'**
  String get correctionReason;

  /// No description provided for @noPayments.
  ///
  /// In ru, this message translates to:
  /// **'Нет оплат'**
  String get noPayments;

  /// No description provided for @paymentDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Оплата удалена'**
  String get paymentDeleted;

  /// No description provided for @paymentUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Оплата обновлена'**
  String get paymentUpdated;

  /// No description provided for @paymentCreated.
  ///
  /// In ru, this message translates to:
  /// **'Оплата добавлена'**
  String get paymentCreated;

  /// No description provided for @paymentMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get paymentMethod;

  /// No description provided for @cash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get card;

  /// No description provided for @transfer.
  ///
  /// In ru, this message translates to:
  /// **'Передать'**
  String get transfer;

  /// No description provided for @todayPayments.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня оплачено'**
  String get todayPayments;

  /// No description provided for @paymentHistory.
  ///
  /// In ru, this message translates to:
  /// **'История оплат'**
  String get paymentHistory;

  /// No description provided for @balanceTransfer.
  ///
  /// In ru, this message translates to:
  /// **'Перенос остатка'**
  String get balanceTransfer;

  /// No description provided for @balanceTransferComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий к переносу'**
  String get balanceTransferComment;

  /// No description provided for @filterStudents.
  ///
  /// In ru, this message translates to:
  /// **'Ученики'**
  String get filterStudents;

  /// No description provided for @filterSubjects.
  ///
  /// In ru, this message translates to:
  /// **'Предметы'**
  String get filterSubjects;

  /// No description provided for @filterTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get filterTeachers;

  /// No description provided for @filterPlans.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы'**
  String get filterPlans;

  /// No description provided for @filterMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ'**
  String get filterMethod;

  /// No description provided for @resetFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get resetFilters;

  /// No description provided for @periodWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get periodMonth;

  /// No description provided for @periodQuarter.
  ///
  /// In ru, this message translates to:
  /// **'Квартал'**
  String get periodQuarter;

  /// No description provided for @periodYear.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get periodYear;

  /// No description provided for @periodCustom.
  ///
  /// In ru, this message translates to:
  /// **'Свой'**
  String get periodCustom;

  /// No description provided for @total.
  ///
  /// In ru, this message translates to:
  /// **'Итого:'**
  String get total;

  /// No description provided for @totalOwnStudents.
  ///
  /// In ru, this message translates to:
  /// **'Итого (ваши ученики):'**
  String get totalOwnStudents;

  /// No description provided for @noAccessToPayments.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к просмотру оплат'**
  String get noAccessToPayments;

  /// No description provided for @noPaymentsForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Нет оплат за этот период'**
  String get noPaymentsForPeriod;

  /// No description provided for @noPaymentsOwnForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Нет оплат ваших учеников за этот период'**
  String get noPaymentsOwnForPeriod;

  /// No description provided for @noPaymentsWithFilters.
  ///
  /// In ru, this message translates to:
  /// **'Нет оплат по заданным фильтрам'**
  String get noPaymentsWithFilters;

  /// No description provided for @familySubscriptionOption.
  ///
  /// In ru, this message translates to:
  /// **'Групповой абонемент'**
  String get familySubscriptionOption;

  /// No description provided for @familySubscriptionDescription.
  ///
  /// In ru, this message translates to:
  /// **'Один абонемент на несколько учеников'**
  String get familySubscriptionDescription;

  /// No description provided for @selectParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Выберите участников'**
  String get selectParticipants;

  /// No description provided for @participantsOf.
  ///
  /// In ru, this message translates to:
  /// **'{count} из {total}'**
  String participantsOf(int count, int total);

  /// No description provided for @minTwoParticipants.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 2 участника'**
  String get minTwoParticipants;

  /// No description provided for @minTwoParticipantsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите минимум 2 участника для группового абонемента'**
  String get minTwoParticipantsRequired;

  /// No description provided for @mergeIntoCard.
  ///
  /// In ru, this message translates to:
  /// **'Объединить в одну карточку'**
  String get mergeIntoCard;

  /// No description provided for @mergeIntoCardDescription.
  ///
  /// In ru, this message translates to:
  /// **'Создаст групповую карточку учеников'**
  String get mergeIntoCardDescription;

  /// No description provided for @groupCardName.
  ///
  /// In ru, this message translates to:
  /// **'Имя групповой карточки'**
  String get groupCardName;

  /// No description provided for @groupCardNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Семья Петровых'**
  String get groupCardNameHint;

  /// No description provided for @selectStudentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика'**
  String get selectStudentRequired;

  /// No description provided for @selectStudentAndPlan.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика и тариф'**
  String get selectStudentAndPlan;

  /// No description provided for @addStudentsFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавьте учеников'**
  String get addStudentsFirst;

  /// No description provided for @customOption.
  ///
  /// In ru, this message translates to:
  /// **'Свой вариант'**
  String get customOption;

  /// No description provided for @discount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get discount;

  /// No description provided for @discountSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер скидки'**
  String get discountSize;

  /// No description provided for @wasPrice.
  ///
  /// In ru, this message translates to:
  /// **'Было: {price} ₸'**
  String wasPrice(String price);

  /// No description provided for @totalPrice.
  ///
  /// In ru, this message translates to:
  /// **'Итого: {price} ₸'**
  String totalPrice(String price);

  /// No description provided for @enterAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get enterAmount;

  /// No description provided for @invalidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Неверная сумма'**
  String get invalidAmount;

  /// No description provided for @lessonsCountField.
  ///
  /// In ru, this message translates to:
  /// **'Занятий'**
  String get lessonsCountField;

  /// No description provided for @enterValue.
  ///
  /// In ru, this message translates to:
  /// **'Введите'**
  String get enterValue;

  /// No description provided for @invalidNumber.
  ///
  /// In ru, this message translates to:
  /// **'Число'**
  String get invalidNumber;

  /// No description provided for @validityDays.
  ///
  /// In ru, this message translates to:
  /// **'Срок (дн.)'**
  String get validityDays;

  /// No description provided for @invalidValue.
  ///
  /// In ru, this message translates to:
  /// **'Некорректное значение'**
  String get invalidValue;

  /// No description provided for @commentOptional.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get commentOptional;

  /// No description provided for @addPaymentWithAmount.
  ///
  /// In ru, this message translates to:
  /// **'Добавить оплату {amount} ₸'**
  String addPaymentWithAmount(String amount);

  /// No description provided for @cardMergedAndPaymentAdded.
  ///
  /// In ru, this message translates to:
  /// **'Карточка объединена и оплата добавлена'**
  String get cardMergedAndPaymentAdded;

  /// No description provided for @groupSubscriptionAdded.
  ///
  /// In ru, this message translates to:
  /// **'Групповой абонемент добавлен'**
  String get groupSubscriptionAdded;

  /// No description provided for @paymentAdded.
  ///
  /// In ru, this message translates to:
  /// **'Оплата добавлена'**
  String get paymentAdded;

  /// No description provided for @deletePaymentConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'Оплата на сумму {amount} ₸ будет удалена. Баланс ученика уменьшится на {lessons} занятий.'**
  String deletePaymentConfirmation(int amount, int lessons);

  /// No description provided for @noEditPermission.
  ///
  /// In ru, this message translates to:
  /// **'Нет прав на редактирование'**
  String get noEditPermission;

  /// No description provided for @canEditOwnStudentsOnly.
  ///
  /// In ru, this message translates to:
  /// **'Вы можете редактировать только оплаты своих учеников'**
  String get canEditOwnStudentsOnly;

  /// No description provided for @paymentFrom.
  ///
  /// In ru, this message translates to:
  /// **'Оплата от {date}'**
  String paymentFrom(String date);

  /// No description provided for @saveChanges.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get saveChanges;

  /// No description provided for @deletePaymentButton.
  ///
  /// In ru, this message translates to:
  /// **'Удалить оплату'**
  String get deletePaymentButton;

  /// No description provided for @subscriptionMembers.
  ///
  /// In ru, this message translates to:
  /// **'Участники абонемента'**
  String get subscriptionMembers;

  /// No description provided for @selectedCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count}'**
  String selectedCount(int count);

  /// No description provided for @loadingError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {error}'**
  String loadingError(String error);

  /// No description provided for @noStudentsYet.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников'**
  String get noStudentsYet;

  /// No description provided for @discountNote.
  ///
  /// In ru, this message translates to:
  /// **'Скидка: {amount} ₸'**
  String discountNote(String amount);

  /// No description provided for @subscription.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент'**
  String get subscription;

  /// No description provided for @subscriptions.
  ///
  /// In ru, this message translates to:
  /// **'Абонементы'**
  String get subscriptions;

  /// No description provided for @expiringSubscriptions.
  ///
  /// In ru, this message translates to:
  /// **'Истекающие абонементы'**
  String get expiringSubscriptions;

  /// No description provided for @noSubscriptions.
  ///
  /// In ru, this message translates to:
  /// **'Нет абонементов'**
  String get noSubscriptions;

  /// No description provided for @lessonsRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Осталось занятий'**
  String get lessonsRemaining;

  /// No description provided for @validUntil.
  ///
  /// In ru, this message translates to:
  /// **'Действует до'**
  String get validUntil;

  /// No description provided for @expired.
  ///
  /// In ru, this message translates to:
  /// **'Истёк'**
  String get expired;

  /// No description provided for @active.
  ///
  /// In ru, this message translates to:
  /// **'Активный'**
  String get active;

  /// No description provided for @familySubscription.
  ///
  /// In ru, this message translates to:
  /// **'Семейный абонемент'**
  String get familySubscription;

  /// No description provided for @statusActive.
  ///
  /// In ru, this message translates to:
  /// **'Активен'**
  String get statusActive;

  /// No description provided for @statusFrozen.
  ///
  /// In ru, this message translates to:
  /// **'Заморожен'**
  String get statusFrozen;

  /// No description provided for @statusExpired.
  ///
  /// In ru, this message translates to:
  /// **'Истёк'**
  String get statusExpired;

  /// No description provided for @statusExhausted.
  ///
  /// In ru, this message translates to:
  /// **'Исчерпан'**
  String get statusExhausted;

  /// No description provided for @minutesShort.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String minutesShort(int minutes);

  /// No description provided for @hourOne.
  ///
  /// In ru, this message translates to:
  /// **'1 час'**
  String get hourOne;

  /// No description provided for @hourOneHalf.
  ///
  /// In ru, this message translates to:
  /// **'1.5 часа'**
  String get hourOneHalf;

  /// No description provided for @hoursShort.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String hoursShort(int hours);

  /// No description provided for @hoursMinutesShort.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String hoursMinutesShort(int hours, int minutes);

  /// No description provided for @currencyName.
  ///
  /// In ru, this message translates to:
  /// **'тенге'**
  String get currencyName;

  /// No description provided for @networkErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети. Проверьте подключение к интернету.'**
  String get networkErrorMessage;

  /// No description provided for @timeoutErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Превышено время ожидания. Попробуйте ещё раз.'**
  String get timeoutErrorMessage;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите заново.'**
  String get sessionExpiredMessage;

  /// No description provided for @errorOccurredMessage.
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка'**
  String get errorOccurredMessage;

  /// No description provided for @errorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {message}'**
  String errorMessage(String message);

  /// No description provided for @profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profile;

  /// No description provided for @name.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get name;

  /// No description provided for @registrationDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата регистрации'**
  String get registrationDate;

  /// No description provided for @editName.
  ///
  /// In ru, this message translates to:
  /// **'Изменить имя'**
  String get editName;

  /// No description provided for @personName.
  ///
  /// In ru, this message translates to:
  /// **'ФИО'**
  String get personName;

  /// No description provided for @personNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Иванов Иван Иванович'**
  String get personNameHint;

  /// No description provided for @enterPersonName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get enterPersonName;

  /// No description provided for @personNameUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Имя обновлено'**
  String get personNameUpdated;

  /// No description provided for @subjects.
  ///
  /// In ru, this message translates to:
  /// **'Направления'**
  String get subjects;

  /// No description provided for @lessonTypes.
  ///
  /// In ru, this message translates to:
  /// **'Типы занятий'**
  String get lessonTypes;

  /// No description provided for @paymentPlans.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы оплаты'**
  String get paymentPlans;

  /// No description provided for @teamMembers.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get teamMembers;

  /// No description provided for @inviteMembers.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить участника'**
  String get inviteMembers;

  /// No description provided for @theme.
  ///
  /// In ru, this message translates to:
  /// **'Тема оформления'**
  String get theme;

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

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get languageSystem;

  /// No description provided for @languageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @languageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @account.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get account;

  /// No description provided for @general.
  ///
  /// In ru, this message translates to:
  /// **'Основные'**
  String get general;

  /// No description provided for @data.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get data;

  /// No description provided for @workingHours.
  ///
  /// In ru, this message translates to:
  /// **'Рабочие часы'**
  String get workingHours;

  /// No description provided for @workStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало работы'**
  String get workStart;

  /// No description provided for @workEnd.
  ///
  /// In ru, this message translates to:
  /// **'Конец работы'**
  String get workEnd;

  /// No description provided for @phoneCountry.
  ///
  /// In ru, this message translates to:
  /// **'Код страны для телефонов'**
  String get phoneCountry;

  /// No description provided for @changesSaved.
  ///
  /// In ru, this message translates to:
  /// **'Изменения сохранены'**
  String get changesSaved;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения скопирован'**
  String get inviteCodeCopied;

  /// No description provided for @shareInviteCode.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться кодом'**
  String get shareInviteCode;

  /// No description provided for @generateNewCode.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать новый код'**
  String get generateNewCode;

  /// No description provided for @permissions.
  ///
  /// In ru, this message translates to:
  /// **'Права доступа'**
  String get permissions;

  /// No description provided for @editPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать права'**
  String get editPermissions;

  /// No description provided for @removeMember.
  ///
  /// In ru, this message translates to:
  /// **'Удалить участника'**
  String get removeMember;

  /// No description provided for @leaveInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть заведение'**
  String get leaveInstitution;

  /// No description provided for @booking.
  ///
  /// In ru, this message translates to:
  /// **'Бронь'**
  String get booking;

  /// No description provided for @bookings.
  ///
  /// In ru, this message translates to:
  /// **'Бронирования'**
  String get bookings;

  /// No description provided for @addBooking.
  ///
  /// In ru, this message translates to:
  /// **'Добавить бронь'**
  String get addBooking;

  /// No description provided for @deleteBooking.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бронь'**
  String get deleteBooking;

  /// No description provided for @bookingDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Бронь удалена'**
  String get bookingDeleted;

  /// No description provided for @bookingCreated.
  ///
  /// In ru, this message translates to:
  /// **'Бронь создана'**
  String get bookingCreated;

  /// No description provided for @permanentSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное расписание'**
  String get permanentSchedule;

  /// No description provided for @oneTimeBooking.
  ///
  /// In ru, this message translates to:
  /// **'Разовое бронирование'**
  String get oneTimeBooking;

  /// No description provided for @slot.
  ///
  /// In ru, this message translates to:
  /// **'Слот'**
  String get slot;

  /// No description provided for @slots.
  ///
  /// In ru, this message translates to:
  /// **'Слоты'**
  String get slots;

  /// No description provided for @freeSlot.
  ///
  /// In ru, this message translates to:
  /// **'Свободный слот'**
  String get freeSlot;

  /// No description provided for @occupiedSlot.
  ///
  /// In ru, this message translates to:
  /// **'Занятый слот'**
  String get occupiedSlot;

  /// No description provided for @lessonSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное занятие'**
  String get lessonSchedule;

  /// No description provided for @lessonSchedules.
  ///
  /// In ru, this message translates to:
  /// **'Постоянные занятия'**
  String get lessonSchedules;

  /// No description provided for @addLessonSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Добавить постоянное занятие'**
  String get addLessonSchedule;

  /// No description provided for @editLessonSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать постоянное занятие'**
  String get editLessonSchedule;

  /// No description provided for @deleteLessonSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Удалить постоянное занятие'**
  String get deleteLessonSchedule;

  /// No description provided for @pauseLessonSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pauseLessonSchedule;

  /// No description provided for @resumeLessonSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Возобновить'**
  String get resumeLessonSchedule;

  /// No description provided for @pauseUntil.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить до'**
  String get pauseUntil;

  /// No description provided for @paused.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено'**
  String get paused;

  /// No description provided for @dayOfWeek.
  ///
  /// In ru, this message translates to:
  /// **'День недели'**
  String get dayOfWeek;

  /// No description provided for @validFrom.
  ///
  /// In ru, this message translates to:
  /// **'Действует с'**
  String get validFrom;

  /// No description provided for @replaceRoom.
  ///
  /// In ru, this message translates to:
  /// **'Временная замена кабинета'**
  String get replaceRoom;

  /// No description provided for @replaceUntil.
  ///
  /// In ru, this message translates to:
  /// **'Замена до'**
  String get replaceUntil;

  /// No description provided for @totalLessons.
  ///
  /// In ru, this message translates to:
  /// **'Всего занятий'**
  String get totalLessons;

  /// No description provided for @totalPayments.
  ///
  /// In ru, this message translates to:
  /// **'Всего оплат'**
  String get totalPayments;

  /// No description provided for @totalStudents.
  ///
  /// In ru, this message translates to:
  /// **'Всего учеников'**
  String get totalStudents;

  /// No description provided for @period.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get period;

  /// No description provided for @thisWeek.
  ///
  /// In ru, this message translates to:
  /// **'Эта неделя'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In ru, this message translates to:
  /// **'Этот месяц'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In ru, this message translates to:
  /// **'Прошлый месяц'**
  String get lastMonth;

  /// No description provided for @customPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Свой период'**
  String get customPeriod;

  /// No description provided for @income.
  ///
  /// In ru, this message translates to:
  /// **'Доход'**
  String get income;

  /// No description provided for @lessonsCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Проведено'**
  String get lessonsCompleted;

  /// No description provided for @lessonsCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменено'**
  String get lessonsCancelled;

  /// No description provided for @bySubject.
  ///
  /// In ru, this message translates to:
  /// **'По предметам'**
  String get bySubject;

  /// No description provided for @byTeacher.
  ///
  /// In ru, this message translates to:
  /// **'По преподавателям'**
  String get byTeacher;

  /// No description provided for @byStudent.
  ///
  /// In ru, this message translates to:
  /// **'По ученикам'**
  String get byStudent;

  /// No description provided for @filters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filters;

  /// No description provided for @filterBy.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр по'**
  String get filterBy;

  /// No description provided for @sortBy.
  ///
  /// In ru, this message translates to:
  /// **'Сортировать по'**
  String get sortBy;

  /// No description provided for @dateRange.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get dateRange;

  /// No description provided for @status.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get status;

  /// No description provided for @clearFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get clearFilters;

  /// No description provided for @applyFilters.
  ///
  /// In ru, this message translates to:
  /// **'Применить фильтры'**
  String get applyFilters;

  /// No description provided for @noResults.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get noResults;

  /// No description provided for @teachers.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get teachers;

  /// No description provided for @monday.
  ///
  /// In ru, this message translates to:
  /// **'Понедельник'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In ru, this message translates to:
  /// **'Вторник'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In ru, this message translates to:
  /// **'Среда'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In ru, this message translates to:
  /// **'Четверг'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In ru, this message translates to:
  /// **'Пятница'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In ru, this message translates to:
  /// **'Суббота'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In ru, this message translates to:
  /// **'Воскресенье'**
  String get sunday;

  /// No description provided for @mondayShort.
  ///
  /// In ru, this message translates to:
  /// **'Пн'**
  String get mondayShort;

  /// No description provided for @tuesdayShort.
  ///
  /// In ru, this message translates to:
  /// **'Вт'**
  String get tuesdayShort;

  /// No description provided for @wednesdayShort.
  ///
  /// In ru, this message translates to:
  /// **'Ср'**
  String get wednesdayShort;

  /// No description provided for @thursdayShort.
  ///
  /// In ru, this message translates to:
  /// **'Чт'**
  String get thursdayShort;

  /// No description provided for @fridayShort.
  ///
  /// In ru, this message translates to:
  /// **'Пт'**
  String get fridayShort;

  /// No description provided for @saturdayShort.
  ///
  /// In ru, this message translates to:
  /// **'Сб'**
  String get saturdayShort;

  /// No description provided for @sundayShort.
  ///
  /// In ru, this message translates to:
  /// **'Вс'**
  String get sundayShort;

  /// No description provided for @errorOccurred.
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка'**
  String get errorOccurred;

  /// No description provided for @networkError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети. Проверьте подключение.'**
  String get networkError;

  /// No description provided for @unknownError.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестная ошибка'**
  String get unknownError;

  /// No description provided for @invalidEmail.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный email'**
  String get invalidEmail;

  /// No description provided for @weakPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль слишком простой'**
  String get weakPassword;

  /// No description provided for @emailInUse.
  ///
  /// In ru, this message translates to:
  /// **'Email уже используется'**
  String get emailInUse;

  /// No description provided for @invalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get invalidCredentials;

  /// No description provided for @fieldRequired.
  ///
  /// In ru, this message translates to:
  /// **'Это поле обязательно'**
  String get fieldRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get passwordsDoNotMatch;

  /// No description provided for @minPasswordLength.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 8 символов'**
  String get minPasswordLength;

  /// No description provided for @passwordNeedsUppercase.
  ///
  /// In ru, this message translates to:
  /// **'Нужна хотя бы одна заглавная буква'**
  String get passwordNeedsUppercase;

  /// No description provided for @passwordNeedsSpecialChar.
  ///
  /// In ru, this message translates to:
  /// **'Нужен хотя бы один спецсимвол (!@#\$%^&*)'**
  String get passwordNeedsSpecialChar;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный номер телефона'**
  String get invalidPhoneNumber;

  /// No description provided for @enterPositiveNumber.
  ///
  /// In ru, this message translates to:
  /// **'Введите положительное число'**
  String get enterPositiveNumber;

  /// No description provided for @enterPositiveInteger.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое положительное число'**
  String get enterPositiveInteger;

  /// No description provided for @sessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите заново.'**
  String get sessionExpired;

  /// No description provided for @noServerConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером'**
  String get noServerConnection;

  /// No description provided for @errorOccurredTitle.
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка'**
  String get errorOccurredTitle;

  /// No description provided for @timeoutError.
  ///
  /// In ru, this message translates to:
  /// **'Превышено время ожидания. Попробуйте ещё раз.'**
  String get timeoutError;

  /// No description provided for @noConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером'**
  String get noConnection;

  /// No description provided for @timeout.
  ///
  /// In ru, this message translates to:
  /// **'Превышено время ожидания. Попробуйте ещё раз.'**
  String get timeout;

  /// No description provided for @notFound.
  ///
  /// In ru, this message translates to:
  /// **'Не найдено'**
  String get notFound;

  /// No description provided for @accessDenied.
  ///
  /// In ru, this message translates to:
  /// **'Доступ запрещён'**
  String get accessDenied;

  /// No description provided for @errorWithMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @confirmDelete.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите удаление'**
  String get confirmDelete;

  /// No description provided for @confirmArchive.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите архивацию'**
  String get confirmArchive;

  /// No description provided for @confirmCancel.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите отмену'**
  String get confirmCancel;

  /// No description provided for @confirmLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get confirmLogout;

  /// No description provided for @confirmLeave.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть заведение?'**
  String get confirmLeave;

  /// No description provided for @deleteConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить?'**
  String get deleteConfirmation;

  /// No description provided for @archiveConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите архивировать?'**
  String get archiveConfirmation;

  /// No description provided for @actionCannotBeUndone.
  ///
  /// In ru, this message translates to:
  /// **'Это действие нельзя отменить'**
  String get actionCannotBeUndone;

  /// No description provided for @deleteQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить {item}?'**
  String deleteQuestion(String item);

  /// No description provided for @archiveQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать {item}?'**
  String archiveQuestion(String item);

  /// No description provided for @lessonsCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{нет занятий} =1{1 занятие} few{{count} занятия} many{{count} занятий} other{{count} занятий}}'**
  String lessonsCountPlural(int count);

  /// No description provided for @studentsCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{нет учеников} =1{1 ученик} few{{count} ученика} many{{count} учеников} other{{count} учеников}}'**
  String studentsCountPlural(int count);

  /// No description provided for @paymentsCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{нет оплат} =1{1 оплата} few{{count} оплаты} many{{count} оплат} other{{count} оплат}}'**
  String paymentsCountPlural(int count);

  /// No description provided for @daysCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{0 дней} =1{1 день} few{{count} дня} many{{count} дней} other{{count} дней}}'**
  String daysCountPlural(int count);

  /// No description provided for @minutesCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{0 минут} =1{1 минута} few{{count} минуты} many{{count} минут} other{{count} минут}}'**
  String minutesCountPlural(int count);

  /// No description provided for @membersCountPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{нет участников} =1{1 участник} few{{count} участника} many{{count} участников} other{{count} участников}}'**
  String membersCountPlural(int count);

  /// No description provided for @prepaidLessonsBalance.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Нет предоплаченных занятий} =1{Предоплачено 1 занятие} few{Предоплачено {count} занятия} many{Предоплачено {count} занятий} other{Предоплачено {count} занятий}}'**
  String prepaidLessonsBalance(int count);

  /// No description provided for @lessonsRemainingPlural.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Занятий не осталось} =1{Осталось 1 занятие} few{Осталось {count} занятия} many{Осталось {count} занятий} other{Осталось {count} занятий}}'**
  String lessonsRemainingPlural(int count);

  /// No description provided for @colorPicker.
  ///
  /// In ru, this message translates to:
  /// **'Выберите цвет'**
  String get colorPicker;

  /// No description provided for @selectColor.
  ///
  /// In ru, this message translates to:
  /// **'Выберите цвет'**
  String get selectColor;

  /// No description provided for @defaultColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет по умолчанию'**
  String get defaultColor;

  /// No description provided for @dateMissed.
  ///
  /// In ru, this message translates to:
  /// **'Дата пропущена'**
  String get dateMissed;

  /// No description provided for @slotPaused.
  ///
  /// In ru, this message translates to:
  /// **'Слот приостановлен'**
  String get slotPaused;

  /// No description provided for @exclusionAdded.
  ///
  /// In ru, this message translates to:
  /// **'Исключение добавлено'**
  String get exclusionAdded;

  /// No description provided for @history.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get history;

  /// No description provided for @deleteFromHistory.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из истории'**
  String get deleteFromHistory;

  /// No description provided for @noHistory.
  ///
  /// In ru, this message translates to:
  /// **'Нет истории'**
  String get noHistory;

  /// No description provided for @sendLink.
  ///
  /// In ru, this message translates to:
  /// **'Отправить ссылку'**
  String get sendLink;

  /// No description provided for @linkSent.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка отправлена'**
  String get linkSent;

  /// No description provided for @dangerZone.
  ///
  /// In ru, this message translates to:
  /// **'Опасная зона'**
  String get dangerZone;

  /// No description provided for @archiveInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать заведение'**
  String get archiveInstitution;

  /// No description provided for @leaveInstitutionAction.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть заведение'**
  String get leaveInstitutionAction;

  /// No description provided for @institutionCanBeRestored.
  ///
  /// In ru, this message translates to:
  /// **'Заведение можно будет восстановить'**
  String get institutionCanBeRestored;

  /// No description provided for @youWillNoLongerBeMember.
  ///
  /// In ru, this message translates to:
  /// **'Вы больше не будете участником'**
  String get youWillNoLongerBeMember;

  /// No description provided for @archiveInstitutionQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать заведение?'**
  String get archiveInstitutionQuestion;

  /// No description provided for @leaveInstitutionQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть заведение?'**
  String get leaveInstitutionQuestion;

  /// No description provided for @archiveInstitutionMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заведение \"{name}\" будет перемещено в архив. Вы сможете восстановить его позже из списка заведений.'**
  String archiveInstitutionMessage(String name);

  /// No description provided for @leaveInstitutionMessage.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите покинуть \"{name}\"? Чтобы вернуться, вам понадобится новый код приглашения.'**
  String leaveInstitutionMessage(String name);

  /// No description provided for @institutionArchived.
  ///
  /// In ru, this message translates to:
  /// **'Заведение архивировано'**
  String get institutionArchived;

  /// No description provided for @institutionDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Заведение удалено'**
  String get institutionDeleted;

  /// No description provided for @institutionDeletedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Это заведение было удалено владельцем. Вы будете перенаправлены на главный экран.'**
  String get institutionDeletedMessage;

  /// No description provided for @ok.
  ///
  /// In ru, this message translates to:
  /// **'ОК'**
  String get ok;

  /// No description provided for @youLeftInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Вы покинули заведение'**
  String get youLeftInstitution;

  /// No description provided for @generateNewCodeQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать новый код?'**
  String get generateNewCodeQuestion;

  /// No description provided for @generateNewCodeMessage.
  ///
  /// In ru, this message translates to:
  /// **'Старый код перестанет работать. Все, кто ещё не присоединился по старому коду, не смогут это сделать.'**
  String get generateNewCodeMessage;

  /// No description provided for @generate.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать'**
  String get generate;

  /// No description provided for @newCodeGenerated.
  ///
  /// In ru, this message translates to:
  /// **'Новый код: {code}'**
  String newCodeGenerated(String code);

  /// No description provided for @nameUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Название обновлено'**
  String get nameUpdated;

  /// No description provided for @enterName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get enterName;

  /// No description provided for @workingHoursUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Рабочее время обновлено'**
  String get workingHoursUpdated;

  /// No description provided for @workingHoursDescription.
  ///
  /// In ru, this message translates to:
  /// **'Это время будет отображаться в сетке расписания'**
  String get workingHoursDescription;

  /// No description provided for @start.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get start;

  /// No description provided for @end.
  ///
  /// In ru, this message translates to:
  /// **'Конец'**
  String get end;

  /// No description provided for @byLocale.
  ///
  /// In ru, this message translates to:
  /// **'По локали устройства'**
  String get byLocale;

  /// No description provided for @todayWithDate.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня, {date}'**
  String todayWithDate(String date);

  /// No description provided for @noScheduledLessons.
  ///
  /// In ru, this message translates to:
  /// **'Нет запланированных занятий'**
  String get noScheduledLessons;

  /// No description provided for @urgent.
  ///
  /// In ru, this message translates to:
  /// **'Срочно'**
  String get urgent;

  /// No description provided for @daysShort.
  ///
  /// In ru, this message translates to:
  /// **'дн.'**
  String get daysShort;

  /// No description provided for @lessonPayment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата занятия'**
  String get lessonPayment;

  /// No description provided for @saveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: {error}'**
  String saveError(String error);

  /// No description provided for @completeProfileSetup.
  ///
  /// In ru, this message translates to:
  /// **'Завершите настройку профиля'**
  String get completeProfileSetup;

  /// No description provided for @selectColorAndSubjects.
  ///
  /// In ru, this message translates to:
  /// **'Выберите цвет и направления'**
  String get selectColorAndSubjects;

  /// No description provided for @fillIn.
  ///
  /// In ru, this message translates to:
  /// **'Заполнить'**
  String get fillIn;

  /// No description provided for @paid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено'**
  String get paid;

  /// No description provided for @archivedInstitutions.
  ///
  /// In ru, this message translates to:
  /// **'Архив заведений'**
  String get archivedInstitutions;

  /// No description provided for @archiveEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Архив пуст'**
  String get archiveEmpty;

  /// No description provided for @restoreInstitutionQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить заведение?'**
  String get restoreInstitutionQuestion;

  /// No description provided for @restoreInstitutionMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заведение \"{name}\" будет восстановлено и появится в основном списке.'**
  String restoreInstitutionMessage(String name);

  /// No description provided for @institutionRestored.
  ///
  /// In ru, this message translates to:
  /// **'Заведение восстановлено'**
  String get institutionRestored;

  /// No description provided for @archivedOn.
  ///
  /// In ru, this message translates to:
  /// **'Архивировано {date}'**
  String archivedOn(String date);

  /// No description provided for @noMembers.
  ///
  /// In ru, this message translates to:
  /// **'Нет участников'**
  String get noMembers;

  /// No description provided for @noName.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get noName;

  /// No description provided for @you.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get you;

  /// No description provided for @adminBadge.
  ///
  /// In ru, this message translates to:
  /// **'Админ'**
  String get adminBadge;

  /// No description provided for @changeColor.
  ///
  /// In ru, this message translates to:
  /// **'Изменить цвет'**
  String get changeColor;

  /// No description provided for @colorUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Цвет обновлён'**
  String get colorUpdated;

  /// No description provided for @colorReset.
  ///
  /// In ru, this message translates to:
  /// **'Цвет сброшен'**
  String get colorReset;

  /// No description provided for @directions.
  ///
  /// In ru, this message translates to:
  /// **'Направления'**
  String get directions;

  /// No description provided for @changeRole.
  ///
  /// In ru, this message translates to:
  /// **'Изменить роль'**
  String get changeRole;

  /// No description provided for @roleName.
  ///
  /// In ru, this message translates to:
  /// **'Название роли'**
  String get roleName;

  /// No description provided for @roleNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Преподаватель, Администратор'**
  String get roleNameHint;

  /// No description provided for @accessRights.
  ///
  /// In ru, this message translates to:
  /// **'Права доступа'**
  String get accessRights;

  /// No description provided for @manageLessons.
  ///
  /// In ru, this message translates to:
  /// **'Управление занятиями'**
  String get manageLessons;

  /// No description provided for @transferOwnershipQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Передать владение?'**
  String get transferOwnershipQuestion;

  /// No description provided for @transferOwnershipWarning.
  ///
  /// In ru, this message translates to:
  /// **'Вы собираетесь передать права владельца пользователю:'**
  String get transferOwnershipWarning;

  /// No description provided for @transferWarningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Внимание!'**
  String get transferWarningTitle;

  /// No description provided for @transferWarningPoints.
  ///
  /// In ru, this message translates to:
  /// **'• Вы потеряете права владельца\n• Новый владелец сможет удалить заведение\n• Это действие нельзя отменить самостоятельно'**
  String get transferWarningPoints;

  /// No description provided for @ownershipTransferred.
  ///
  /// In ru, this message translates to:
  /// **'Права владельца переданы {name}'**
  String ownershipTransferred(String name);

  /// No description provided for @removeMemberQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить участника?'**
  String get removeMemberQuestion;

  /// No description provided for @removeMemberConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить {name} из заведения?'**
  String removeMemberConfirmation(String name);

  /// No description provided for @futureLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Будущих занятий: {count}'**
  String futureLessonsCount(int count);

  /// No description provided for @noFutureLessonsToManage.
  ///
  /// In ru, this message translates to:
  /// **'Нет будущих занятий для управления'**
  String get noFutureLessonsToManage;

  /// No description provided for @deleteAllFutureLessons.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все будущие занятия'**
  String get deleteAllFutureLessons;

  /// No description provided for @deleteAllFutureLessonsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Занятия будут удалены без изменения баланса учеников'**
  String get deleteAllFutureLessonsDescription;

  /// No description provided for @reassignTeacher.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить преподавателя'**
  String get reassignTeacher;

  /// No description provided for @reassignTeacherDescription.
  ///
  /// In ru, this message translates to:
  /// **'Передать все занятия другому преподавателю'**
  String get reassignTeacherDescription;

  /// No description provided for @deleteLessonsQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить занятия?'**
  String get deleteLessonsQuestion;

  /// No description provided for @deleteLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Будет удалено {count} занятий преподавателя:'**
  String deleteLessonsCount(int count);

  /// No description provided for @deleteLessonsWarning.
  ///
  /// In ru, this message translates to:
  /// **'Баланс абонементов учеников не изменится.\nЭто действие нельзя отменить.'**
  String get deleteLessonsWarning;

  /// No description provided for @lessonsDeletedCount.
  ///
  /// In ru, this message translates to:
  /// **'Удалено занятий: {count}'**
  String lessonsDeletedCount(int count);

  /// No description provided for @reassignLessons.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить занятия'**
  String get reassignLessons;

  /// No description provided for @reassignLessonsFrom.
  ///
  /// In ru, this message translates to:
  /// **'{count} занятий от {name}'**
  String reassignLessonsFrom(int count, String name);

  /// No description provided for @selectNewTeacher.
  ///
  /// In ru, this message translates to:
  /// **'Выберите нового преподавателя:'**
  String get selectNewTeacher;

  /// No description provided for @noOtherTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Нет других преподавателей'**
  String get noOtherTeachers;

  /// No description provided for @checkingConflicts.
  ///
  /// In ru, this message translates to:
  /// **'Проверка конфликтов...'**
  String get checkingConflicts;

  /// No description provided for @conflictsFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено {count} конфликтов'**
  String conflictsFound(int count);

  /// No description provided for @noConflictsFound.
  ///
  /// In ru, this message translates to:
  /// **'Конфликтов не найдено'**
  String get noConflictsFound;

  /// No description provided for @andMoreConflicts.
  ///
  /// In ru, this message translates to:
  /// **'...и ещё {count} конфликтов'**
  String andMoreConflicts(int count);

  /// No description provided for @skipConflicts.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить конфликты'**
  String get skipConflicts;

  /// No description provided for @reassign.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить'**
  String get reassign;

  /// No description provided for @conflictCheckError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка проверки: {error}'**
  String conflictCheckError(String error);

  /// No description provided for @noLessonsToReassign.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий для переназначения'**
  String get noLessonsToReassign;

  /// No description provided for @reassignedCount.
  ///
  /// In ru, this message translates to:
  /// **'Переназначено занятий: {count}'**
  String reassignedCount(int count);

  /// No description provided for @skippedConflicts.
  ///
  /// In ru, this message translates to:
  /// **'пропущено: {count}'**
  String skippedConflicts(int count);

  /// No description provided for @noSubjectsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных направлений'**
  String get noSubjectsAvailable;

  /// No description provided for @subjectsUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Направления обновлены'**
  String get subjectsUpdated;

  /// No description provided for @errorWithDetails.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {details}'**
  String errorWithDetails(String details);

  /// No description provided for @newRoom.
  ///
  /// In ru, this message translates to:
  /// **'Новый кабинет'**
  String get newRoom;

  /// No description provided for @editRoomTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать кабинет'**
  String get editRoomTitle;

  /// No description provided for @roomNumberRequired.
  ///
  /// In ru, this message translates to:
  /// **'Номер кабинета *'**
  String get roomNumberRequired;

  /// No description provided for @roomNumberHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: 101'**
  String get roomNumberHint;

  /// No description provided for @roomNameOptional.
  ///
  /// In ru, this message translates to:
  /// **'Название (опционально)'**
  String get roomNameOptional;

  /// No description provided for @roomNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Фортепианный'**
  String get roomNameHint;

  /// No description provided for @enterRoomNumber.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер кабинета'**
  String get enterRoomNumber;

  /// No description provided for @fillRoomData.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные кабинета'**
  String get fillRoomData;

  /// No description provided for @changeRoomData.
  ///
  /// In ru, this message translates to:
  /// **'Измените данные кабинета'**
  String get changeRoomData;

  /// No description provided for @createRoom.
  ///
  /// In ru, this message translates to:
  /// **'Создать кабинет'**
  String get createRoom;

  /// No description provided for @roomWithNumber.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет {number}'**
  String roomWithNumber(String number);

  /// No description provided for @roomCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет \"{name}\" создан'**
  String roomCreatedMessage(String name);

  /// No description provided for @deleteRoomQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить кабинет?'**
  String get deleteRoomQuestion;

  /// No description provided for @deleteRoomMessage.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет \"{name}\" будет удалён. Это действие нельзя отменить.'**
  String deleteRoomMessage(String name);

  /// No description provided for @myStudents.
  ///
  /// In ru, this message translates to:
  /// **'Мои'**
  String get myStudents;

  /// No description provided for @withDebt.
  ///
  /// In ru, this message translates to:
  /// **'С долгом'**
  String get withDebt;

  /// No description provided for @searchByName.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени...'**
  String get searchByName;

  /// No description provided for @direction.
  ///
  /// In ru, this message translates to:
  /// **'Направление'**
  String get direction;

  /// No description provided for @activity.
  ///
  /// In ru, this message translates to:
  /// **'Активность'**
  String get activity;

  /// No description provided for @noStudentsByFilters.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников по заданным фильтрам'**
  String get noStudentsByFilters;

  /// No description provided for @tryDifferentQuery.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте изменить запрос'**
  String get tryDifferentQuery;

  /// No description provided for @archivedStudentsHere.
  ///
  /// In ru, this message translates to:
  /// **'Здесь будут отображаться архивированные ученики'**
  String get archivedStudentsHere;

  /// No description provided for @noStudentsWithDebt.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников с долгом'**
  String get noStudentsWithDebt;

  /// No description provided for @allStudentsPositiveBalance.
  ///
  /// In ru, this message translates to:
  /// **'У всех учеников положительный баланс'**
  String get allStudentsPositiveBalance;

  /// No description provided for @noLinkedStudents.
  ///
  /// In ru, this message translates to:
  /// **'Нет привязанных учеников'**
  String get noLinkedStudents;

  /// No description provided for @noLinkedStudentsHint.
  ///
  /// In ru, this message translates to:
  /// **'К вам пока не привязаны ученики'**
  String get noLinkedStudentsHint;

  /// No description provided for @addFirstStudent.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первого ученика'**
  String get addFirstStudent;

  /// No description provided for @noLessons7Days.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий 7+ дней'**
  String get noLessons7Days;

  /// No description provided for @noLessons14Days.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий 14+ дней'**
  String get noLessons14Days;

  /// No description provided for @noLessons30Days.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий 30+ дней'**
  String get noLessons30Days;

  /// No description provided for @noLessons60Days.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий 60+ дней'**
  String get noLessons60Days;

  /// No description provided for @groupNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Группа вокала'**
  String get groupNameHint;

  /// No description provided for @studentsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =1{1 ученик} few{{count} ученика} many{{count} учеников} other{{count} учеников}}'**
  String studentsCount(int count);

  /// No description provided for @mergeCount.
  ///
  /// In ru, this message translates to:
  /// **'Объединить ({count})'**
  String mergeCount(int count);

  /// No description provided for @fillStudentData.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные ученика'**
  String get fillStudentData;

  /// No description provided for @fullNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'ФИО *'**
  String get fullNameRequired;

  /// No description provided for @fullNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Иванов Иван Иванович'**
  String get fullNameHint;

  /// No description provided for @enterStudentName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя ученика'**
  String get enterStudentName;

  /// No description provided for @phoneHint.
  ///
  /// In ru, this message translates to:
  /// **'+7 (777) 123-45-67'**
  String get phoneHint;

  /// No description provided for @noAvailableTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных преподавателей'**
  String get noAvailableTeachers;

  /// No description provided for @additionalInfo.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительная информация...'**
  String get additionalInfo;

  /// No description provided for @remainingLessons.
  ///
  /// In ru, this message translates to:
  /// **'Остаток занятий'**
  String get remainingLessons;

  /// No description provided for @fromOtherSchool.
  ///
  /// In ru, this message translates to:
  /// **'При переносе из другой школы'**
  String get fromOtherSchool;

  /// No description provided for @lessonsUnit.
  ///
  /// In ru, this message translates to:
  /// **'занятий'**
  String get lessonsUnit;

  /// No description provided for @remainingLessonsHint.
  ///
  /// In ru, this message translates to:
  /// **'Списывается первым, не влияет на доход'**
  String get remainingLessonsHint;

  /// No description provided for @createStudent.
  ///
  /// In ru, this message translates to:
  /// **'Создать ученика'**
  String get createStudent;

  /// No description provided for @selectRoomForSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинет для расписания'**
  String get selectRoomForSchedule;

  /// No description provided for @scheduleConflictsError.
  ///
  /// In ru, this message translates to:
  /// **'Есть конфликты в расписании. Измените время или кабинет.'**
  String get scheduleConflictsError;

  /// No description provided for @initialBalanceComment.
  ///
  /// In ru, this message translates to:
  /// **'Начальный остаток'**
  String get initialBalanceComment;

  /// No description provided for @studentCreatedWithSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" создан с расписанием'**
  String studentCreatedWithSchedule(String name);

  /// No description provided for @studentCreatedSimple.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" создан'**
  String studentCreatedSimple(String name);

  /// No description provided for @setupPermanentSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Настроить постоянное расписание'**
  String get setupPermanentSchedule;

  /// No description provided for @selectDaysAndTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дни и время занятий'**
  String get selectDaysAndTime;

  /// No description provided for @roomForLessons.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет для занятий'**
  String get roomForLessons;

  /// No description provided for @daysOfWeekLabel.
  ///
  /// In ru, this message translates to:
  /// **'Дни недели'**
  String get daysOfWeekLabel;

  /// No description provided for @lessonTimeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Время занятий'**
  String get lessonTimeLabel;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationHours.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String durationHours(int hours);

  /// No description provided for @durationMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String durationMinutes(int minutes);

  /// No description provided for @incorrect.
  ///
  /// In ru, this message translates to:
  /// **'Некорректно'**
  String get incorrect;

  /// No description provided for @conflictTimeOccupied.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт! Время занято'**
  String get conflictTimeOccupied;

  /// No description provided for @lessonsBalance.
  ///
  /// In ru, this message translates to:
  /// **'{count} занятий'**
  String lessonsBalance(int count);

  /// No description provided for @noLessonTypes.
  ///
  /// In ru, this message translates to:
  /// **'Нет типов занятий'**
  String get noLessonTypes;

  /// No description provided for @addFirstLessonType.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый тип занятия'**
  String get addFirstLessonType;

  /// No description provided for @addType.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тип'**
  String get addType;

  /// No description provided for @deleteLessonTypeQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить тип занятия?'**
  String get deleteLessonTypeQuestion;

  /// No description provided for @lessonTypeWillBeDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Тип \"{name}\" будет удалён'**
  String lessonTypeWillBeDeleted(String name);

  /// No description provided for @lessonTypeDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия удалён'**
  String get lessonTypeDeleted;

  /// No description provided for @newLessonType.
  ///
  /// In ru, this message translates to:
  /// **'Новый тип занятия'**
  String get newLessonType;

  /// No description provided for @fillLessonTypeData.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные типа'**
  String get fillLessonTypeData;

  /// No description provided for @nameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Название *'**
  String get nameRequired;

  /// No description provided for @nameHintExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: Индивидуальное'**
  String get nameHintExample;

  /// No description provided for @enterNameValidation.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get enterNameValidation;

  /// No description provided for @other.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get other;

  /// No description provided for @customDuration.
  ///
  /// In ru, this message translates to:
  /// **'Своя длительность'**
  String get customDuration;

  /// No description provided for @defaultPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена по умолчанию'**
  String get defaultPrice;

  /// No description provided for @groupLessonSwitch.
  ///
  /// In ru, this message translates to:
  /// **'Групповое занятие'**
  String get groupLessonSwitch;

  /// No description provided for @multipleStudents.
  ///
  /// In ru, this message translates to:
  /// **'Несколько учеников одновременно'**
  String get multipleStudents;

  /// No description provided for @oneStudent.
  ///
  /// In ru, this message translates to:
  /// **'Один ученик'**
  String get oneStudent;

  /// No description provided for @createType.
  ///
  /// In ru, this message translates to:
  /// **'Создать тип'**
  String get createType;

  /// No description provided for @lessonTypeCreated.
  ///
  /// In ru, this message translates to:
  /// **'Тип \"{name}\" создан'**
  String lessonTypeCreated(String name);

  /// No description provided for @editLessonType.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать тип'**
  String get editLessonType;

  /// No description provided for @changeLessonTypeData.
  ///
  /// In ru, this message translates to:
  /// **'Измените данные типа занятия'**
  String get changeLessonTypeData;

  /// No description provided for @durationValidationError.
  ///
  /// In ru, this message translates to:
  /// **'Длительность должна быть от 5 до 480 минут'**
  String get durationValidationError;

  /// No description provided for @color.
  ///
  /// In ru, this message translates to:
  /// **'Цвет'**
  String get color;

  /// No description provided for @lessonTypeUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия обновлён'**
  String get lessonTypeUpdated;

  /// No description provided for @scheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get scheduleTitle;

  /// No description provided for @roomWithNumberTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет {number}'**
  String roomWithNumberTitle(String number);

  /// No description provided for @filtersTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filtersTooltip;

  /// No description provided for @addTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get addTooltip;

  /// No description provided for @compactView.
  ///
  /// In ru, this message translates to:
  /// **'Компакт.'**
  String get compactView;

  /// No description provided for @detailedView.
  ///
  /// In ru, this message translates to:
  /// **'Подробн.'**
  String get detailedView;

  /// No description provided for @dayView.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get dayView;

  /// No description provided for @weekView.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get weekView;

  /// No description provided for @lessonDefault.
  ///
  /// In ru, this message translates to:
  /// **'Занятие'**
  String get lessonDefault;

  /// No description provided for @booked.
  ///
  /// In ru, this message translates to:
  /// **'Забронировано'**
  String get booked;

  /// No description provided for @studentDefault.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get studentDefault;

  /// No description provided for @hour.
  ///
  /// In ru, this message translates to:
  /// **'Час'**
  String get hour;

  /// No description provided for @deletedFromHistory.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из истории'**
  String get deletedFromHistory;

  /// No description provided for @modify.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get modify;

  /// No description provided for @cancelLesson.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get cancelLesson;

  /// No description provided for @skipThisDate.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить эту дату'**
  String get skipThisDate;

  /// No description provided for @statusUpdateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить статус'**
  String get statusUpdateFailed;

  /// No description provided for @lessonCompletedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие проведено'**
  String get lessonCompletedMessage;

  /// No description provided for @lessonCancelledMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие отменено'**
  String get lessonCancelledMessage;

  /// No description provided for @skipDateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить дату'**
  String get skipDateTitle;

  /// No description provided for @skipDateMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие не будет отображаться на {date}.\n\nЭто не создаст запись в истории занятий.'**
  String skipDateMessage(String date);

  /// No description provided for @skip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get skip;

  /// No description provided for @dateSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Дата пропущена'**
  String get dateSkipped;

  /// No description provided for @lessonDeducted.
  ///
  /// In ru, this message translates to:
  /// **'Занятие списано'**
  String get lessonDeducted;

  /// No description provided for @lessonReturned.
  ///
  /// In ru, this message translates to:
  /// **'Занятие возвращено'**
  String get lessonReturned;

  /// No description provided for @deleteLessonWithPayment.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет удалено из истории.\nОплата за занятие также будет удалена.'**
  String get deleteLessonWithPayment;

  /// No description provided for @deleteLessonWithBalance.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет удалено из истории.\nСписанное занятие будет возвращено на баланс ученика.'**
  String get deleteLessonWithBalance;

  /// No description provided for @deleteLessonSimple.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет полностью удалено из истории.'**
  String get deleteLessonSimple;

  /// No description provided for @deleteLessonQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить занятие?'**
  String get deleteLessonQuestion;

  /// No description provided for @lessonDeletedFromHistory.
  ///
  /// In ru, this message translates to:
  /// **'Занятие удалено из истории'**
  String get lessonDeletedFromHistory;

  /// No description provided for @lessonPaymentType.
  ///
  /// In ru, this message translates to:
  /// **'Оплата занятия'**
  String get lessonPaymentType;

  /// No description provided for @paymentAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Оплата добавлена'**
  String get paymentAddedMessage;

  /// No description provided for @paymentDeletedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Оплата удалена'**
  String get paymentDeletedMessage;

  /// No description provided for @paymentDeleteError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка удаления оплаты: {error}'**
  String paymentDeleteError(String error);

  /// No description provided for @cancelledLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Отменено {count} занятий'**
  String cancelledLessonsCount(int count);

  /// No description provided for @cancelLessonTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить занятие'**
  String get cancelLessonTitle;

  /// No description provided for @cancelWithoutDeduction.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет отменено и архивировано без списания с баланса'**
  String get cancelWithoutDeduction;

  /// No description provided for @deductionWillBeReturned.
  ///
  /// In ru, this message translates to:
  /// **'Списанное при проведении занятие будет автоматически возвращено на баланс.'**
  String get deductionWillBeReturned;

  /// No description provided for @deductFromBalance.
  ///
  /// In ru, this message translates to:
  /// **'Списать занятие с баланса'**
  String get deductFromBalance;

  /// No description provided for @lessonWillBeDeducted.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет вычтено из предоплаченных'**
  String get lessonWillBeDeducted;

  /// No description provided for @whoToDeduct.
  ///
  /// In ru, this message translates to:
  /// **'Кому списать занятие:'**
  String get whoToDeduct;

  /// No description provided for @balanceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {count}'**
  String balanceLabel(int count);

  /// No description provided for @seriesPartInfo.
  ///
  /// In ru, this message translates to:
  /// **'Это занятие является частью серии ({count} шт.)'**
  String seriesPartInfo(int count);

  /// No description provided for @onlyThis.
  ///
  /// In ru, this message translates to:
  /// **'Только это'**
  String get onlyThis;

  /// No description provided for @thisAndFollowing.
  ///
  /// In ru, this message translates to:
  /// **'Это и последующие'**
  String get thisAndFollowing;

  /// No description provided for @deductOnlyToday.
  ///
  /// In ru, this message translates to:
  /// **'Списание применится только к сегодняшнему занятию'**
  String get deductOnlyToday;

  /// No description provided for @archiveWithoutDeduction.
  ///
  /// In ru, this message translates to:
  /// **'Все занятия серии будут архивированы без списания'**
  String get archiveWithoutDeduction;

  /// No description provided for @cancelLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Отменить {count} занятий'**
  String cancelLessonsCount(int count);

  /// No description provided for @seriesCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Серия занятий отменена'**
  String get seriesCancelled;

  /// No description provided for @cancelledWithDeduction.
  ///
  /// In ru, this message translates to:
  /// **'Занятие отменено и списано с баланса'**
  String get cancelledWithDeduction;

  /// No description provided for @cancelledWithoutDeduction.
  ///
  /// In ru, this message translates to:
  /// **'Занятие отменено'**
  String get cancelledWithoutDeduction;

  /// No description provided for @permanentSchedulePart.
  ///
  /// In ru, this message translates to:
  /// **'Это занятие является частью постоянного расписания'**
  String get permanentSchedulePart;

  /// No description provided for @thisAndAllFollowing.
  ///
  /// In ru, this message translates to:
  /// **'Это и все последующие'**
  String get thisAndAllFollowing;

  /// No description provided for @participantsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get participantsTitle;

  /// No description provided for @noParticipantsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет участников'**
  String get noParticipantsMessage;

  /// No description provided for @addGuestLabel.
  ///
  /// In ru, this message translates to:
  /// **'Добавить гостя'**
  String get addGuestLabel;

  /// No description provided for @payLabel.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить'**
  String get payLabel;

  /// No description provided for @unknownStudent.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный'**
  String get unknownStudent;

  /// No description provided for @paymentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get paymentTitle;

  /// No description provided for @removeFromLessonTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из занятия'**
  String get removeFromLessonTooltip;

  /// No description provided for @paymentRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Оплата записана: {count} {students}'**
  String paymentRecorded(int count, String students);

  /// No description provided for @paymentError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка оплаты: {error}'**
  String paymentError(String error);

  /// No description provided for @studentSingular.
  ///
  /// In ru, this message translates to:
  /// **'ученик'**
  String get studentSingular;

  /// No description provided for @studentFew.
  ///
  /// In ru, this message translates to:
  /// **'ученика'**
  String get studentFew;

  /// No description provided for @studentMany.
  ///
  /// In ru, this message translates to:
  /// **'учеников'**
  String get studentMany;

  /// No description provided for @removeParticipantQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Убрать участника?'**
  String get removeParticipantQuestion;

  /// No description provided for @removeFromLessonMessage.
  ///
  /// In ru, this message translates to:
  /// **'Убрать {name} из этого занятия?'**
  String removeFromLessonMessage(String name);

  /// No description provided for @removeFromLessonGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Убрать участника из этого занятия?'**
  String get removeFromLessonGeneric;

  /// No description provided for @remove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get remove;

  /// No description provided for @addGuestTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить гостя'**
  String get addGuestTitle;

  /// No description provided for @allStudentsAdded.
  ///
  /// In ru, this message translates to:
  /// **'Все ученики уже добавлены'**
  String get allStudentsAdded;

  /// No description provided for @editLessonTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать занятие'**
  String get editLessonTitle;

  /// No description provided for @dateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get timeLabel;

  /// No description provided for @roomLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get roomLabel;

  /// No description provided for @groupLabel.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get groupLabel;

  /// No description provided for @subjectLabel.
  ///
  /// In ru, this message translates to:
  /// **'Предмет'**
  String get subjectLabel;

  /// No description provided for @lessonTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия'**
  String get lessonTypeLabel;

  /// No description provided for @notSelected.
  ///
  /// In ru, this message translates to:
  /// **'Не выбран'**
  String get notSelected;

  /// No description provided for @saveChangesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get saveChangesLabel;

  /// No description provided for @minDurationError.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длительность занятия — 15 минут'**
  String get minDurationError;

  /// No description provided for @lessonUpdatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие обновлено'**
  String get lessonUpdatedMessage;

  /// No description provided for @noRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Без повтора'**
  String get noRepeat;

  /// No description provided for @everyDay.
  ///
  /// In ru, this message translates to:
  /// **'Каждый день'**
  String get everyDay;

  /// No description provided for @everyWeek.
  ///
  /// In ru, this message translates to:
  /// **'Каждую неделю'**
  String get everyWeek;

  /// No description provided for @byWeekdays.
  ///
  /// In ru, this message translates to:
  /// **'По дням недели'**
  String get byWeekdays;

  /// No description provided for @manualDates.
  ///
  /// In ru, this message translates to:
  /// **'Ручной выбор дат'**
  String get manualDates;

  /// No description provided for @onlyThisLesson.
  ///
  /// In ru, this message translates to:
  /// **'Только это занятие'**
  String get onlyThisLesson;

  /// No description provided for @allSeriesLessons.
  ///
  /// In ru, this message translates to:
  /// **'Все занятия серии'**
  String get allSeriesLessons;

  /// No description provided for @selectedLessons.
  ///
  /// In ru, this message translates to:
  /// **'Выбранные'**
  String get selectedLessons;

  /// No description provided for @roomAdded.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет \"{name}\" добавлен'**
  String roomAdded(String name);

  /// No description provided for @newRoomTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый кабинет'**
  String get newRoomTitle;

  /// No description provided for @fillRoomDataMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные кабинета'**
  String get fillRoomDataMessage;

  /// No description provided for @roomNumberLabel.
  ///
  /// In ru, this message translates to:
  /// **'Номер кабинета *'**
  String get roomNumberLabel;

  /// No description provided for @enterRoomNumberValidation.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер кабинета'**
  String get enterRoomNumberValidation;

  /// No description provided for @nameOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название (опционально)'**
  String get nameOptionalLabel;

  /// No description provided for @nameOptionalHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Фортепианный'**
  String get nameOptionalHint;

  /// No description provided for @createRoomLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать кабинет'**
  String get createRoomLabel;

  /// No description provided for @selectStudentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика'**
  String get selectStudentTitle;

  /// No description provided for @noOwnStudents.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет своих учеников'**
  String get noOwnStudents;

  /// No description provided for @showAllCount.
  ///
  /// In ru, this message translates to:
  /// **'Показать всех ({count})'**
  String showAllCount(int count);

  /// No description provided for @otherStudents.
  ///
  /// In ru, this message translates to:
  /// **'Остальные ученики'**
  String get otherStudents;

  /// No description provided for @hideLabel.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть'**
  String get hideLabel;

  /// No description provided for @studentAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" добавлен'**
  String studentAddedMessage(String name);

  /// No description provided for @newStudentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый ученик'**
  String get newStudentTitle;

  /// No description provided for @quickAddLabel.
  ///
  /// In ru, this message translates to:
  /// **'Быстрое добавление'**
  String get quickAddLabel;

  /// No description provided for @fullNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'ФИО'**
  String get fullNameLabel;

  /// No description provided for @enterStudentNameValidation.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя ученика'**
  String get enterStudentNameValidation;

  /// No description provided for @phoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phoneLabel;

  /// No description provided for @createStudentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать ученика'**
  String get createStudentLabel;

  /// No description provided for @subjectAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Предмет \"{name}\" добавлен'**
  String subjectAddedMessage(String name);

  /// No description provided for @newSubjectTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый предмет'**
  String get newSubjectTitle;

  /// No description provided for @addSubjectMessage.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте предмет для занятий'**
  String get addSubjectMessage;

  /// No description provided for @subjectNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название предмета'**
  String get subjectNameLabel;

  /// No description provided for @subjectNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Фортепиано'**
  String get subjectNameHint;

  /// No description provided for @enterSubjectNameValidation.
  ///
  /// In ru, this message translates to:
  /// **'Введите название предмета'**
  String get enterSubjectNameValidation;

  /// No description provided for @createSubjectLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать предмет'**
  String get createSubjectLabel;

  /// No description provided for @durationValidation.
  ///
  /// In ru, this message translates to:
  /// **'Длительность должна быть от 5 до 480 минут'**
  String get durationValidation;

  /// No description provided for @lessonTypeAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия \"{name}\" добавлен'**
  String lessonTypeAddedMessage(String name);

  /// No description provided for @newLessonTypeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый тип занятия'**
  String get newLessonTypeTitle;

  /// No description provided for @configureLessonType.
  ///
  /// In ru, this message translates to:
  /// **'Настройте параметры занятия'**
  String get configureLessonType;

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get nameLabel;

  /// No description provided for @lessonTypeNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Индивидуальное занятие'**
  String get lessonTypeNameHint;

  /// No description provided for @durationLabel.
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get durationLabel;

  /// No description provided for @otherOption.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get otherOption;

  /// No description provided for @customDurationLabel.
  ///
  /// In ru, this message translates to:
  /// **'Своя длительность'**
  String get customDurationLabel;

  /// No description provided for @enterMinutes.
  ///
  /// In ru, this message translates to:
  /// **'Введите минуты'**
  String get enterMinutes;

  /// No description provided for @minutesSuffix.
  ///
  /// In ru, this message translates to:
  /// **'мин'**
  String get minutesSuffix;

  /// No description provided for @priceOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена (необязательно)'**
  String get priceOptionalLabel;

  /// No description provided for @priceHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: 5000'**
  String get priceHint;

  /// No description provided for @groupLessonTitle.
  ///
  /// In ru, this message translates to:
  /// **'Групповое занятие'**
  String get groupLessonTitle;

  /// No description provided for @forMultipleStudents.
  ///
  /// In ru, this message translates to:
  /// **'Для нескольких учеников'**
  String get forMultipleStudents;

  /// No description provided for @createTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать тип'**
  String get createTypeLabel;

  /// No description provided for @filtersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filtersTitle;

  /// No description provided for @resetLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get resetLabel;

  /// No description provided for @teachersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get teachersTitle;

  /// No description provided for @lessonTypesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Типы занятий'**
  String get lessonTypesTitle;

  /// No description provided for @directionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Направления'**
  String get directionsTitle;

  /// No description provided for @applyFiltersLabel.
  ///
  /// In ru, this message translates to:
  /// **'Применить фильтры'**
  String get applyFiltersLabel;

  /// No description provided for @showAllLabel.
  ///
  /// In ru, this message translates to:
  /// **'Показать все'**
  String get showAllLabel;

  /// No description provided for @studentsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ученики'**
  String get studentsTitle;

  /// No description provided for @noStudentsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников'**
  String get noStudentsMessage;

  /// No description provided for @deletedStudent.
  ///
  /// In ru, this message translates to:
  /// **'Удалён'**
  String get deletedStudent;

  /// No description provided for @temporarilyShowAll.
  ///
  /// In ru, this message translates to:
  /// **'Временно показаны все'**
  String get temporarilyShowAll;

  /// No description provided for @notConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Не настроено'**
  String get notConfigured;

  /// No description provided for @allRooms.
  ///
  /// In ru, this message translates to:
  /// **'Все кабинеты'**
  String get allRooms;

  /// No description provided for @defaultRoomsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты по умолчанию'**
  String get defaultRoomsTitle;

  /// No description provided for @restoreRoomFilter.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть фильтр кабинетов'**
  String get restoreRoomFilter;

  /// No description provided for @showAllRooms.
  ///
  /// In ru, this message translates to:
  /// **'Показать все кабинеты'**
  String get showAllRooms;

  /// No description provided for @noDataMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noDataMessage;

  /// No description provided for @selectDates.
  ///
  /// In ru, this message translates to:
  /// **'Выберите даты'**
  String get selectDates;

  /// No description provided for @doneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get doneLabel;

  /// No description provided for @lessonTab.
  ///
  /// In ru, this message translates to:
  /// **'Занятие'**
  String get lessonTab;

  /// No description provided for @bookingTab.
  ///
  /// In ru, this message translates to:
  /// **'Бронь'**
  String get bookingTab;

  /// No description provided for @noRoomsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет кабинетов'**
  String get noRoomsAvailable;

  /// No description provided for @dateRequired.
  ///
  /// In ru, this message translates to:
  /// **'Дата *'**
  String get dateRequired;

  /// No description provided for @timeRequired.
  ///
  /// In ru, this message translates to:
  /// **'Время *'**
  String get timeRequired;

  /// No description provided for @roomsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты'**
  String get roomsTitle;

  /// No description provided for @roomShort.
  ///
  /// In ru, this message translates to:
  /// **'Каб. {number}'**
  String roomShort(String number);

  /// No description provided for @selectAtLeastOneRoom.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы один кабинет'**
  String get selectAtLeastOneRoom;

  /// No description provided for @descriptionOptional.
  ///
  /// In ru, this message translates to:
  /// **'Описание (опционально)'**
  String get descriptionOptional;

  /// No description provided for @descriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Мероприятие, встреча и т.д.'**
  String get descriptionHint;

  /// No description provided for @bookLabel.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать'**
  String get bookLabel;

  /// No description provided for @studentTab.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get studentTab;

  /// No description provided for @groupTab.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get groupTab;

  /// No description provided for @studentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Ученик *'**
  String get studentRequired;

  /// No description provided for @selectStudentPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика'**
  String get selectStudentPlaceholder;

  /// No description provided for @addStudentTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ученика'**
  String get addStudentTooltip;

  /// No description provided for @groupRequired.
  ///
  /// In ru, this message translates to:
  /// **'Группа *'**
  String get groupRequired;

  /// No description provided for @noGroupsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет групп'**
  String get noGroupsAvailable;

  /// No description provided for @createGroupTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Создать группу'**
  String get createGroupTooltip;

  /// No description provided for @teacherLabel.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель'**
  String get teacherLabel;

  /// No description provided for @addSubjectTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить предмет'**
  String get addSubjectTooltip;

  /// No description provided for @addLessonTypeTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тип занятия'**
  String get addLessonTypeTooltip;

  /// No description provided for @repeatLabel.
  ///
  /// In ru, this message translates to:
  /// **'Повтор'**
  String get repeatLabel;

  /// No description provided for @selectDatesInCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать даты в календаре'**
  String get selectDatesInCalendar;

  /// No description provided for @selectedDatesCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count} дат'**
  String selectedDatesCount(int count);

  /// No description provided for @checkingConflictsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Проверка конфликтов...'**
  String get checkingConflictsMessage;

  /// No description provided for @willCreateLessons.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано {count} занятий'**
  String willCreateLessons(int count);

  /// No description provided for @conflictsWillBeSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Конфликты: {count} (будут пропущены)'**
  String conflictsWillBeSkipped(int count);

  /// No description provided for @createSchedulesCount.
  ///
  /// In ru, this message translates to:
  /// **'Создать {count} расписаний'**
  String createSchedulesCount(int count);

  /// No description provided for @createSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Создать расписание'**
  String get createSchedule;

  /// No description provided for @createLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Создать {count} занятий'**
  String createLessonsCount(int count);

  /// No description provided for @createLessonSingle.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятие'**
  String get createLessonSingle;

  /// No description provided for @minBookingDuration.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длительность брони — 15 минут'**
  String get minBookingDuration;

  /// No description provided for @roomsBooked.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты забронированы'**
  String get roomsBooked;

  /// No description provided for @invalidTime.
  ///
  /// In ru, this message translates to:
  /// **'Некорректно'**
  String get invalidTime;

  /// No description provided for @minLessonDuration.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длительность занятия — 15 минут'**
  String get minLessonDuration;

  /// No description provided for @permanentSchedulesCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} постоянных расписаний'**
  String permanentSchedulesCreated(int count);

  /// No description provided for @permanentScheduleCreated.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное расписание создано'**
  String get permanentScheduleCreated;

  /// No description provided for @allDatesOccupied.
  ///
  /// In ru, this message translates to:
  /// **'Все даты заняты'**
  String get allDatesOccupied;

  /// No description provided for @lessonsCreatedWithSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Создано {created} занятий (пропущено: {skipped})'**
  String lessonsCreatedWithSkipped(int created, int skipped);

  /// No description provided for @lessonsCreatedCount.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} занятий'**
  String lessonsCreatedCount(int count);

  /// No description provided for @groupLessonCreated.
  ///
  /// In ru, this message translates to:
  /// **'Групповое занятие создано'**
  String get groupLessonCreated;

  /// No description provided for @lessonCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие создано'**
  String get lessonCreatedMessage;

  /// No description provided for @newGroupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая группа'**
  String get newGroupTitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название группы'**
  String get groupNameLabel;

  /// No description provided for @createLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get createLabel;

  /// No description provided for @unknownUser.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный пользователь'**
  String get unknownUser;

  /// No description provided for @deletingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Удаление...'**
  String get deletingLabel;

  /// No description provided for @deleteBookingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бронь'**
  String get deleteBookingLabel;

  /// No description provided for @deleteBookingQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бронь?'**
  String get deleteBookingQuestion;

  /// No description provided for @bookingWillBeDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Бронирование будет удалено и кабинеты освободятся.'**
  String get bookingWillBeDeleted;

  /// No description provided for @bookingDeletedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Бронь удалена'**
  String get bookingDeletedMessage;

  /// No description provided for @bookingDeleteError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при удалении'**
  String get bookingDeleteError;

  /// No description provided for @bookRoomsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать кабинеты'**
  String get bookRoomsTitle;

  /// No description provided for @selectRoomsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты'**
  String get selectRoomsLabel;

  /// No description provided for @selectAtLeastOneRoomMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы один кабинет'**
  String get selectAtLeastOneRoomMessage;

  /// No description provided for @dateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get dateTitle;

  /// No description provided for @startTitle.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get startTitle;

  /// No description provided for @endTitle.
  ///
  /// In ru, this message translates to:
  /// **'Окончание'**
  String get endTitle;

  /// No description provided for @descriptionOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Описание (необязательно)'**
  String get descriptionOptionalLabel;

  /// No description provided for @descriptionExampleHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Репетиция, Мероприятие'**
  String get descriptionExampleHint;

  /// No description provided for @bookingError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка бронирования'**
  String get bookingError;

  /// No description provided for @permanentScheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное расписание'**
  String get permanentScheduleTitle;

  /// No description provided for @notSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указан'**
  String get notSpecified;

  /// No description provided for @temporaryRoomReplacement.
  ///
  /// In ru, this message translates to:
  /// **'Временно в кабинете {room} до {date}'**
  String temporaryRoomReplacement(String room, String date);

  /// No description provided for @createLessonOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятие на {date}'**
  String createLessonOnDate(String date);

  /// No description provided for @createLessonsForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия на период'**
  String get createLessonsForPeriod;

  /// No description provided for @createMultipleLessons.
  ///
  /// In ru, this message translates to:
  /// **'Создать несколько занятий из этого слота'**
  String get createMultipleLessons;

  /// No description provided for @addException.
  ///
  /// In ru, this message translates to:
  /// **'Добавить исключение'**
  String get addException;

  /// No description provided for @slotWontWorkOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Слот не будет действовать в выбранную дату'**
  String get slotWontWorkOnDate;

  /// No description provided for @pauseSlot.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pauseSlot;

  /// No description provided for @temporarilyDeactivate.
  ///
  /// In ru, this message translates to:
  /// **'Временно деактивировать'**
  String get temporarilyDeactivate;

  /// No description provided for @resumeSlot.
  ///
  /// In ru, this message translates to:
  /// **'Возобновить'**
  String get resumeSlot;

  /// No description provided for @pausedUntilDate.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено до {date}'**
  String pausedUntilDate(String date);

  /// No description provided for @indefinitePause.
  ///
  /// In ru, this message translates to:
  /// **'Бессрочная пауза'**
  String get indefinitePause;

  /// No description provided for @deactivate.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать'**
  String get deactivate;

  /// No description provided for @completelyDisableSlot.
  ///
  /// In ru, this message translates to:
  /// **'Полностью отключить слот'**
  String get completelyDisableSlot;

  /// No description provided for @addExceptionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить исключение'**
  String get addExceptionTitle;

  /// No description provided for @slotWontWorkMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот не будет действовать {date}.\n\nЭто позволит создать другое занятие в это время.'**
  String slotWontWorkMessage(String date);

  /// No description provided for @addLabel.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get addLabel;

  /// No description provided for @exceptionAdded.
  ///
  /// In ru, this message translates to:
  /// **'Исключение добавлено'**
  String get exceptionAdded;

  /// No description provided for @pauseUntilLabel.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить до'**
  String get pauseUntilLabel;

  /// No description provided for @slotPausedUntil.
  ///
  /// In ru, this message translates to:
  /// **'Слот приостановлен до {date}'**
  String slotPausedUntil(String date);

  /// No description provided for @slotResumed.
  ///
  /// In ru, this message translates to:
  /// **'Слот возобновлён'**
  String get slotResumed;

  /// No description provided for @deactivateSlotTitle.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать слот'**
  String get deactivateSlotTitle;

  /// No description provided for @deactivateSlotMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот будет полностью отключён и не будет отображаться в расписании.\n\nВы сможете активировать его снова в карточке ученика.'**
  String get deactivateSlotMessage;

  /// No description provided for @slotDeactivated.
  ///
  /// In ru, this message translates to:
  /// **'Слот деактивирован'**
  String get slotDeactivated;

  /// No description provided for @createLessonsForPeriodTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия на период'**
  String get createLessonsForPeriodTitle;

  /// No description provided for @studentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ученик: {name}'**
  String studentLabel(String name);

  /// No description provided for @fromDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'С даты'**
  String get fromDateLabel;

  /// No description provided for @toDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get toDateLabel;

  /// No description provided for @willBeCreated.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано: {count} занятий'**
  String willBeCreated(int count);

  /// No description provided for @creatingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создание...'**
  String get creatingLabel;

  /// No description provided for @createLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия'**
  String get createLessonsLabel;

  /// No description provided for @noDatesToCreate.
  ///
  /// In ru, this message translates to:
  /// **'Нет дат для создания'**
  String get noDatesToCreate;

  /// No description provided for @roomNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указан кабинет'**
  String get roomNotSpecified;

  /// No description provided for @lessonsCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} занятий'**
  String lessonsCreatedMessage(int count);

  /// No description provided for @seriesLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки серии: {error}'**
  String seriesLoadError(String error);

  /// No description provided for @editSeriesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать серию'**
  String get editSeriesTitle;

  /// No description provided for @savingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение...'**
  String get savingLabel;

  /// No description provided for @applyChangesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Применить изменения'**
  String get applyChangesLabel;

  /// No description provided for @changesScope.
  ///
  /// In ru, this message translates to:
  /// **'Область изменений'**
  String get changesScope;

  /// No description provided for @byWeekdaysLabel.
  ///
  /// In ru, this message translates to:
  /// **'По дням недели'**
  String get byWeekdaysLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий:'**
  String get quantityLabel;

  /// No description provided for @allLabel.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get allLabel;

  /// No description provided for @seriesLessons.
  ///
  /// In ru, this message translates to:
  /// **'Занятия серии ({count})'**
  String seriesLessons(int count);

  /// No description provided for @changesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменения'**
  String get changesTitle;

  /// No description provided for @willBeChanged.
  ///
  /// In ru, this message translates to:
  /// **'Будет изменено: {count} занятий'**
  String willBeChanged(int count);

  /// No description provided for @currentLabel.
  ///
  /// In ru, this message translates to:
  /// **'текущий'**
  String get currentLabel;

  /// No description provided for @noLessonsToUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий для обновления (все имеют конфликты)'**
  String get noLessonsToUpdate;

  /// No description provided for @lessonsUpdatedWithSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {updated} занятий (пропущено: {skipped})'**
  String lessonsUpdatedWithSkipped(int updated, int skipped);

  /// No description provided for @lessonsUpdatedCount.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {count} занятий'**
  String lessonsUpdatedCount(int count);

  /// No description provided for @memberDataError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить данные участника'**
  String get memberDataError;

  /// No description provided for @showingAllRooms.
  ///
  /// In ru, this message translates to:
  /// **'Отображаются все кабинеты'**
  String get showingAllRooms;

  /// No description provided for @roomsSelectedCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано кабинетов: {count}'**
  String roomsSelectedCount(int count);

  /// No description provided for @whichRoomsDoYouUse.
  ///
  /// In ru, this message translates to:
  /// **'Какими кабинетами вы пользуетесь?'**
  String get whichRoomsDoYouUse;

  /// No description provided for @onlySelectedRoomsShown.
  ///
  /// In ru, this message translates to:
  /// **'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.'**
  String get onlySelectedRoomsShown;

  /// No description provided for @selectDefaultRooms.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.'**
  String get selectDefaultRooms;

  /// No description provided for @skipLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get skipLabel;

  /// No description provided for @saveWithCount.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить ({count})'**
  String saveWithCount(int count);

  /// No description provided for @virtualLesson.
  ///
  /// In ru, this message translates to:
  /// **'Виртуальное занятие'**
  String get virtualLesson;

  /// No description provided for @completeOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Провести занятие на {date}'**
  String completeOnDate(String date);

  /// No description provided for @createRealCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Создать реальное занятие со статусом \"Проведено\"'**
  String get createRealCompleted;

  /// No description provided for @cancelOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Отменить занятие на {date}'**
  String cancelOnDate(String date);

  /// No description provided for @createRealCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Создать реальное занятие со статусом \"Отменено\"'**
  String get createRealCancelled;

  /// No description provided for @skipThisDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить эту дату'**
  String get skipThisDateLabel;

  /// No description provided for @addExceptionWithoutLesson.
  ///
  /// In ru, this message translates to:
  /// **'Добавить исключение без создания занятия'**
  String get addExceptionWithoutLesson;

  /// No description provided for @pauseSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить расписание'**
  String get pauseSchedule;

  /// No description provided for @temporarilyDeactivateSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Временно деактивировать'**
  String get temporarilyDeactivateSchedule;

  /// No description provided for @resumeSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Возобновить расписание'**
  String get resumeSchedule;

  /// No description provided for @completelyDisableSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Полностью отключить расписание'**
  String get completelyDisableSchedule;

  /// No description provided for @schedulePaused.
  ///
  /// In ru, this message translates to:
  /// **'Расписание приостановлено'**
  String get schedulePaused;

  /// No description provided for @scheduleResumed.
  ///
  /// In ru, this message translates to:
  /// **'Расписание возобновлено'**
  String get scheduleResumed;

  /// No description provided for @deactivateScheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать расписание'**
  String get deactivateScheduleTitle;

  /// No description provided for @deactivateScheduleMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание будет полностью отключено. Это действие можно отменить.'**
  String get deactivateScheduleMessage;

  /// No description provided for @scheduleDeactivated.
  ///
  /// In ru, this message translates to:
  /// **'Расписание деактивировано'**
  String get scheduleDeactivated;

  /// No description provided for @deductedFromBalance.
  ///
  /// In ru, this message translates to:
  /// **'Списано с баланса'**
  String get deductedFromBalance;

  /// No description provided for @lessonDeductedFromBalance.
  ///
  /// In ru, this message translates to:
  /// **'Занятие списано с баланса ученика'**
  String get lessonDeductedFromBalance;

  /// No description provided for @lessonNotDeducted.
  ///
  /// In ru, this message translates to:
  /// **'Занятие не списано с баланса'**
  String get lessonNotDeducted;

  /// No description provided for @completedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Проведено'**
  String get completedLabel;

  /// No description provided for @paidLabel.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено'**
  String get paidLabel;

  /// No description provided for @costLabel.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get costLabel;

  /// No description provided for @repeatSeriesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Повтор'**
  String get repeatSeriesLabel;

  /// No description provided for @yesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get yesLabel;

  /// No description provided for @typeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get typeLabel;

  /// No description provided for @statusUpdateError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить статус'**
  String get statusUpdateError;

  /// No description provided for @deductFromBalanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Списать занятие с баланса'**
  String get deductFromBalanceTitle;

  /// No description provided for @addGuest.
  ///
  /// In ru, this message translates to:
  /// **'Добавить гостя'**
  String get addGuest;

  /// No description provided for @pay.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить'**
  String get pay;

  /// No description provided for @defaultRooms.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты по умолчанию'**
  String get defaultRooms;

  /// No description provided for @book.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать'**
  String get book;

  /// No description provided for @deleteBookingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Бронирование будет удалено и кабинеты освободятся.'**
  String get deleteBookingMessage;

  /// No description provided for @endLabel.
  ///
  /// In ru, this message translates to:
  /// **'Окончание'**
  String get endLabel;

  /// No description provided for @createMultipleLessonsFromSlot.
  ///
  /// In ru, this message translates to:
  /// **'Создать несколько занятий из этого слота'**
  String get createMultipleLessonsFromSlot;

  /// No description provided for @slotWillNotWorkOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Слот не будет действовать в выбранную дату'**
  String get slotWillNotWorkOnDate;

  /// No description provided for @pause.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pause;

  /// No description provided for @temporarilyDeactivateSlot.
  ///
  /// In ru, this message translates to:
  /// **'Временно деактивировать слот'**
  String get temporarilyDeactivateSlot;

  /// No description provided for @resume.
  ///
  /// In ru, this message translates to:
  /// **'Возобновить'**
  String get resume;

  /// No description provided for @deactivateSlot.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать слот'**
  String get deactivateSlot;

  /// No description provided for @oneMonth.
  ///
  /// In ru, this message translates to:
  /// **'1 месяц'**
  String get oneMonth;

  /// No description provided for @threeMonths.
  ///
  /// In ru, this message translates to:
  /// **'3 месяца'**
  String get threeMonths;

  /// No description provided for @sixMonths.
  ///
  /// In ru, this message translates to:
  /// **'6 месяцев'**
  String get sixMonths;

  /// No description provided for @oneYear.
  ///
  /// In ru, this message translates to:
  /// **'1 год'**
  String get oneYear;

  /// No description provided for @createCompletedLesson.
  ///
  /// In ru, this message translates to:
  /// **'Создать реальное занятие со статусом \"Проведено\"'**
  String get createCompletedLesson;

  /// No description provided for @createCancelledLesson.
  ///
  /// In ru, this message translates to:
  /// **'Создать реальное занятие со статусом \"Отменено\"'**
  String get createCancelledLesson;

  /// No description provided for @deactivateSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать расписание'**
  String get deactivateSchedule;

  /// No description provided for @scheduleWillBeDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Расписание будет полностью отключено. Это действие можно отменить.'**
  String get scheduleWillBeDisabled;

  /// No description provided for @permissionsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Права сохранены'**
  String get permissionsSaved;

  /// No description provided for @permissionSectionInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Управление заведением'**
  String get permissionSectionInstitution;

  /// No description provided for @permissionManageInstitution.
  ///
  /// In ru, this message translates to:
  /// **'Изменение заведения'**
  String get permissionManageInstitution;

  /// No description provided for @permissionManageInstitutionDesc.
  ///
  /// In ru, this message translates to:
  /// **'Изменение названия, настроек'**
  String get permissionManageInstitutionDesc;

  /// No description provided for @permissionManageMembers.
  ///
  /// In ru, this message translates to:
  /// **'Управление участниками'**
  String get permissionManageMembers;

  /// No description provided for @permissionManageMembersDesc.
  ///
  /// In ru, this message translates to:
  /// **'Добавление, удаление, изменение прав'**
  String get permissionManageMembersDesc;

  /// No description provided for @permissionArchiveData.
  ///
  /// In ru, this message translates to:
  /// **'Архивация данных'**
  String get permissionArchiveData;

  /// No description provided for @permissionArchiveDataDesc.
  ///
  /// In ru, this message translates to:
  /// **'Архивация учеников, групп'**
  String get permissionArchiveDataDesc;

  /// No description provided for @permissionSectionReferences.
  ///
  /// In ru, this message translates to:
  /// **'Справочники'**
  String get permissionSectionReferences;

  /// No description provided for @permissionManageRooms.
  ///
  /// In ru, this message translates to:
  /// **'Управление кабинетами'**
  String get permissionManageRooms;

  /// No description provided for @permissionManageRoomsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, редактирование, удаление'**
  String get permissionManageRoomsDesc;

  /// No description provided for @permissionManageSubjects.
  ///
  /// In ru, this message translates to:
  /// **'Управление предметами'**
  String get permissionManageSubjects;

  /// No description provided for @permissionManageSubjectsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, редактирование, удаление'**
  String get permissionManageSubjectsDesc;

  /// No description provided for @permissionManageLessonTypes.
  ///
  /// In ru, this message translates to:
  /// **'Управление типами занятий'**
  String get permissionManageLessonTypes;

  /// No description provided for @permissionManageLessonTypesDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, редактирование, удаление'**
  String get permissionManageLessonTypesDesc;

  /// No description provided for @permissionManagePaymentPlans.
  ///
  /// In ru, this message translates to:
  /// **'Управление тарифами'**
  String get permissionManagePaymentPlans;

  /// No description provided for @permissionManagePaymentPlansDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, редактирование, удаление'**
  String get permissionManagePaymentPlansDesc;

  /// No description provided for @permissionSectionStudents.
  ///
  /// In ru, this message translates to:
  /// **'Ученики и группы'**
  String get permissionSectionStudents;

  /// No description provided for @permissionManageOwnStudents.
  ///
  /// In ru, this message translates to:
  /// **'Управление своими учениками'**
  String get permissionManageOwnStudents;

  /// No description provided for @permissionManageOwnStudentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, редактирование своих учеников'**
  String get permissionManageOwnStudentsDesc;

  /// No description provided for @permissionManageAllStudents.
  ///
  /// In ru, this message translates to:
  /// **'Управление всеми учениками'**
  String get permissionManageAllStudents;

  /// No description provided for @permissionManageAllStudentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Управление учениками других преподавателей'**
  String get permissionManageAllStudentsDesc;

  /// No description provided for @permissionManageGroups.
  ///
  /// In ru, this message translates to:
  /// **'Управление группами'**
  String get permissionManageGroups;

  /// No description provided for @permissionManageGroupsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, редактирование групп'**
  String get permissionManageGroupsDesc;

  /// No description provided for @permissionSectionSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get permissionSectionSchedule;

  /// No description provided for @permissionViewAllSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр всего расписания'**
  String get permissionViewAllSchedule;

  /// No description provided for @permissionViewAllScheduleDesc.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр занятий других преподавателей'**
  String get permissionViewAllScheduleDesc;

  /// No description provided for @permissionCreateLessons.
  ///
  /// In ru, this message translates to:
  /// **'Создание занятий'**
  String get permissionCreateLessons;

  /// No description provided for @permissionCreateLessonsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Добавление новых занятий в расписание'**
  String get permissionCreateLessonsDesc;

  /// No description provided for @permissionEditOwnLessons.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование своих занятий'**
  String get permissionEditOwnLessons;

  /// No description provided for @permissionEditOwnLessonsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Изменение своих занятий'**
  String get permissionEditOwnLessonsDesc;

  /// No description provided for @permissionEditAllLessons.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование всех занятий'**
  String get permissionEditAllLessons;

  /// No description provided for @permissionEditAllLessonsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Изменение занятий других преподавателей'**
  String get permissionEditAllLessonsDesc;

  /// No description provided for @permissionDeleteOwnLessons.
  ///
  /// In ru, this message translates to:
  /// **'Удаление своих занятий'**
  String get permissionDeleteOwnLessons;

  /// No description provided for @permissionDeleteOwnLessonsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Удаление своих занятий из расписания'**
  String get permissionDeleteOwnLessonsDesc;

  /// No description provided for @permissionDeleteAllLessons.
  ///
  /// In ru, this message translates to:
  /// **'Удаление всех занятий'**
  String get permissionDeleteAllLessons;

  /// No description provided for @permissionDeleteAllLessonsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Удаление занятий других преподавателей'**
  String get permissionDeleteAllLessonsDesc;

  /// No description provided for @permissionSectionFinance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get permissionSectionFinance;

  /// No description provided for @permissionViewOwnStudentsPayments.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр оплат своих учеников'**
  String get permissionViewOwnStudentsPayments;

  /// No description provided for @permissionViewOwnStudentsPaymentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр платежей своих учеников'**
  String get permissionViewOwnStudentsPaymentsDesc;

  /// No description provided for @permissionViewAllPayments.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр всех оплат'**
  String get permissionViewAllPayments;

  /// No description provided for @permissionViewAllPaymentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр платежей всех учеников'**
  String get permissionViewAllPaymentsDesc;

  /// No description provided for @permissionAddPaymentsForOwnStudents.
  ///
  /// In ru, this message translates to:
  /// **'Добавление оплат своим ученикам'**
  String get permissionAddPaymentsForOwnStudents;

  /// No description provided for @permissionAddPaymentsForOwnStudentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Принятие оплат от своих учеников'**
  String get permissionAddPaymentsForOwnStudentsDesc;

  /// No description provided for @permissionAddPaymentsForAllStudents.
  ///
  /// In ru, this message translates to:
  /// **'Добавление оплат всем ученикам'**
  String get permissionAddPaymentsForAllStudents;

  /// No description provided for @permissionAddPaymentsForAllStudentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Принятие оплат от любых учеников'**
  String get permissionAddPaymentsForAllStudentsDesc;

  /// No description provided for @permissionManageOwnStudentsPayments.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование оплат своих учеников'**
  String get permissionManageOwnStudentsPayments;

  /// No description provided for @permissionManageOwnStudentsPaymentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Изменение и удаление оплат своих учеников'**
  String get permissionManageOwnStudentsPaymentsDesc;

  /// No description provided for @permissionManageAllPayments.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование всех оплат'**
  String get permissionManageAllPayments;

  /// No description provided for @permissionManageAllPaymentsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Изменение и удаление любых оплат'**
  String get permissionManageAllPaymentsDesc;

  /// No description provided for @permissionViewStatistics.
  ///
  /// In ru, this message translates to:
  /// **'Просмотр статистики'**
  String get permissionViewStatistics;

  /// No description provided for @permissionViewStatisticsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к разделу статистики'**
  String get permissionViewStatisticsDesc;

  /// No description provided for @statusSection.
  ///
  /// In ru, this message translates to:
  /// **'СТАТУС'**
  String get statusSection;

  /// No description provided for @adminHasAllPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get adminHasAllPermissions;

  /// No description provided for @grantFullPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Предоставить все права'**
  String get grantFullPermissions;

  /// No description provided for @allPermissionsEnabledForAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Включено для администратора'**
  String get allPermissionsEnabledForAdmin;

  /// No description provided for @welcome.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать!'**
  String get welcome;

  /// No description provided for @selectColorForLessons.
  ///
  /// In ru, this message translates to:
  /// **'Выберите цвет для отображения\nваших занятий в расписании'**
  String get selectColorForLessons;

  /// No description provided for @yourDirections.
  ///
  /// In ru, this message translates to:
  /// **'Ваши направления'**
  String get yourDirections;

  /// No description provided for @selectSubjectsYouTeach.
  ///
  /// In ru, this message translates to:
  /// **'Выберите предметы, которые вы ведёте'**
  String get selectSubjectsYouTeach;

  /// No description provided for @noSubjectsInInstitution.
  ///
  /// In ru, this message translates to:
  /// **'В заведении пока нет предметов'**
  String get noSubjectsInInstitution;

  /// No description provided for @ownerCanAddInSettings.
  ///
  /// In ru, this message translates to:
  /// **'Владелец может добавить их в настройках'**
  String get ownerCanAddInSettings;

  /// No description provided for @noPaymentPlans.
  ///
  /// In ru, this message translates to:
  /// **'Нет тарифов'**
  String get noPaymentPlans;

  /// No description provided for @addFirstPaymentPlan.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый тариф оплаты'**
  String get addFirstPaymentPlan;

  /// No description provided for @addPlan.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тариф'**
  String get addPlan;

  /// No description provided for @addPaymentPlan.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тариф'**
  String get addPaymentPlan;

  /// No description provided for @paymentPlanNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Абонемент на 8 занятий'**
  String get paymentPlanNameHint;

  /// No description provided for @enterNameField.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get enterNameField;

  /// No description provided for @lessonsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Занятий *'**
  String get lessonsRequired;

  /// No description provided for @invalidValueError.
  ///
  /// In ru, this message translates to:
  /// **'Некорректное значение'**
  String get invalidValueError;

  /// No description provided for @createPaymentPlan.
  ///
  /// In ru, this message translates to:
  /// **'Создать тариф'**
  String get createPaymentPlan;

  /// No description provided for @deletePaymentPlanQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить тариф?'**
  String get deletePaymentPlanQuestion;

  /// No description provided for @paymentPlanWillBeDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Тариф \"{name}\" будет удалён'**
  String paymentPlanWillBeDeleted(String name);

  /// No description provided for @paymentPlanDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Тариф удалён'**
  String get paymentPlanDeleted;

  /// No description provided for @paymentPlanCreated.
  ///
  /// In ru, this message translates to:
  /// **'Тариф \"{name}\" создан'**
  String paymentPlanCreated(String name);

  /// No description provided for @newPaymentPlan.
  ///
  /// In ru, this message translates to:
  /// **'Новый тариф'**
  String get newPaymentPlan;

  /// No description provided for @fillPaymentPlanData.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные тарифа'**
  String get fillPaymentPlanData;

  /// No description provided for @planNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Абонемент на 8 занятий'**
  String get planNameHint;

  /// No description provided for @lessonsCountRequired.
  ///
  /// In ru, this message translates to:
  /// **'Занятий *'**
  String get lessonsCountRequired;

  /// No description provided for @priceRequired.
  ///
  /// In ru, this message translates to:
  /// **'Цена *'**
  String get priceRequired;

  /// No description provided for @validityDaysRequired.
  ///
  /// In ru, this message translates to:
  /// **'Срок действия (дней) *'**
  String get validityDaysRequired;

  /// No description provided for @enterValidityDays.
  ///
  /// In ru, this message translates to:
  /// **'Введите срок'**
  String get enterValidityDays;

  /// No description provided for @createPlan.
  ///
  /// In ru, this message translates to:
  /// **'Создать тариф'**
  String get createPlan;

  /// No description provided for @paymentPlanUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Тариф обновлён'**
  String get paymentPlanUpdated;

  /// No description provided for @editPaymentPlan.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать тариф'**
  String get editPaymentPlan;

  /// No description provided for @changePaymentPlanData.
  ///
  /// In ru, this message translates to:
  /// **'Измените данные тарифа'**
  String get changePaymentPlanData;

  /// No description provided for @pricePerLesson.
  ///
  /// In ru, this message translates to:
  /// **'{price} ₸/занятие'**
  String pricePerLesson(String price);

  /// No description provided for @validityDaysShort.
  ///
  /// In ru, this message translates to:
  /// **'{days} дн.'**
  String validityDaysShort(int days);

  /// No description provided for @noSubjects.
  ///
  /// In ru, this message translates to:
  /// **'Нет предметов'**
  String get noSubjects;

  /// No description provided for @addFirstSubject.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте первый предмет'**
  String get addFirstSubject;

  /// No description provided for @deleteSubjectQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить предмет?'**
  String get deleteSubjectQuestion;

  /// No description provided for @subjectWillBeDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Предмет \"{name}\" будет удалён'**
  String subjectWillBeDeleted(String name);

  /// No description provided for @subjectDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Предмет удалён'**
  String get subjectDeleted;

  /// No description provided for @subjectCreated.
  ///
  /// In ru, this message translates to:
  /// **'Предмет \"{name}\" создан'**
  String subjectCreated(String name);

  /// No description provided for @newSubject.
  ///
  /// In ru, this message translates to:
  /// **'Новый предмет'**
  String get newSubject;

  /// No description provided for @fillSubjectData.
  ///
  /// In ru, this message translates to:
  /// **'Введите название предмета'**
  String get fillSubjectData;

  /// No description provided for @addSubject.
  ///
  /// In ru, this message translates to:
  /// **'Добавить предмет'**
  String get addSubject;

  /// No description provided for @createSubject.
  ///
  /// In ru, this message translates to:
  /// **'Создать предмет'**
  String get createSubject;

  /// No description provided for @enterSubjectName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название предмета'**
  String get enterSubjectName;

  /// No description provided for @subjectNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Название *'**
  String get subjectNameRequired;

  /// No description provided for @subjectUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Предмет обновлён'**
  String get subjectUpdated;

  /// No description provided for @editSubject.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать предмет'**
  String get editSubject;

  /// No description provided for @changeSubjectData.
  ///
  /// In ru, this message translates to:
  /// **'Измените данные предмета'**
  String get changeSubjectData;

  /// No description provided for @noAccessToStatistics.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к статистике'**
  String get noAccessToStatistics;

  /// No description provided for @statisticsNoAccess.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к статистике'**
  String get statisticsNoAccess;

  /// No description provided for @statsTabGeneral.
  ///
  /// In ru, this message translates to:
  /// **'Общая'**
  String get statsTabGeneral;

  /// No description provided for @statsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Занятия'**
  String get statsTotal;

  /// No description provided for @statsFinances.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get statsFinances;

  /// No description provided for @statsAvgLessonApprox.
  ///
  /// In ru, this message translates to:
  /// **'≈'**
  String get statsAvgLessonApprox;

  /// No description provided for @statsAvgLesson.
  ///
  /// In ru, this message translates to:
  /// **'Ср. занятие'**
  String get statsAvgLesson;

  /// No description provided for @statsDiscounts.
  ///
  /// In ru, this message translates to:
  /// **'Скидки'**
  String get statsDiscounts;

  /// No description provided for @statsPaidLessonsOf.
  ///
  /// In ru, this message translates to:
  /// **'{paid} из {total}'**
  String statsPaidLessonsOf(int paid, int total);

  /// No description provided for @statsPaymentsWithDiscount.
  ///
  /// In ru, this message translates to:
  /// **'{count} со скидкой'**
  String statsPaymentsWithDiscount(int count);

  /// No description provided for @statsWorkload.
  ///
  /// In ru, this message translates to:
  /// **'Загруженность'**
  String get statsWorkload;

  /// No description provided for @statsLessonHours.
  ///
  /// In ru, this message translates to:
  /// **'Часов занятий'**
  String get statsLessonHours;

  /// No description provided for @statsActiveStudents.
  ///
  /// In ru, this message translates to:
  /// **'Активных учеников'**
  String get statsActiveStudents;

  /// No description provided for @statsPaymentMethods.
  ///
  /// In ru, this message translates to:
  /// **'Способы оплаты'**
  String get statsPaymentMethods;

  /// No description provided for @statsCardPayments.
  ///
  /// In ru, this message translates to:
  /// **'Карта ({count}) — {percent}%'**
  String statsCardPayments(int count, String percent);

  /// No description provided for @statsCashPayments.
  ///
  /// In ru, this message translates to:
  /// **'Наличные ({count}) — {percent}%'**
  String statsCashPayments(int count, String percent);

  /// No description provided for @statsAvgLessonShort.
  ///
  /// In ru, this message translates to:
  /// **'Ср.:'**
  String get statsAvgLessonShort;

  /// No description provided for @statsLessonStats.
  ///
  /// In ru, this message translates to:
  /// **'Статистика занятий'**
  String get statsLessonStats;

  /// No description provided for @contactOwner.
  ///
  /// In ru, this message translates to:
  /// **'Обратитесь к владельцу заведения'**
  String get contactOwner;

  /// No description provided for @tabGeneral.
  ///
  /// In ru, this message translates to:
  /// **'Общая'**
  String get tabGeneral;

  /// No description provided for @tabSubjects.
  ///
  /// In ru, this message translates to:
  /// **'Предметы'**
  String get tabSubjects;

  /// No description provided for @tabTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get tabTeachers;

  /// No description provided for @tabStudents.
  ///
  /// In ru, this message translates to:
  /// **'Ученики'**
  String get tabStudents;

  /// No description provided for @tabPlans.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы'**
  String get tabPlans;

  /// No description provided for @lessonsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Всего'**
  String get lessonsTotal;

  /// No description provided for @lessonsScheduled.
  ///
  /// In ru, this message translates to:
  /// **'Запланировано'**
  String get lessonsScheduled;

  /// No description provided for @paymentsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Оплаты'**
  String get paymentsLabel;

  /// No description provided for @avgLesson.
  ///
  /// In ru, this message translates to:
  /// **'Ср. занятие'**
  String get avgLesson;

  /// No description provided for @discounts.
  ///
  /// In ru, this message translates to:
  /// **'Скидки'**
  String get discounts;

  /// No description provided for @workload.
  ///
  /// In ru, this message translates to:
  /// **'Загруженность'**
  String get workload;

  /// No description provided for @hoursOfLessons.
  ///
  /// In ru, this message translates to:
  /// **'Часов занятий'**
  String get hoursOfLessons;

  /// No description provided for @activeStudentsCount.
  ///
  /// In ru, this message translates to:
  /// **'Активных учеников'**
  String get activeStudentsCount;

  /// No description provided for @paymentMethodCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get paymentMethodCard;

  /// No description provided for @paymentMethodCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get paymentMethodCash;

  /// No description provided for @noDataForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных за период'**
  String get noDataForPeriod;

  /// No description provided for @lessonStatistics.
  ///
  /// In ru, this message translates to:
  /// **'Статистика занятий'**
  String get lessonStatistics;

  /// No description provided for @cancellationRate.
  ///
  /// In ru, this message translates to:
  /// **'Процент отмен'**
  String get cancellationRate;

  /// No description provided for @topByLessons.
  ///
  /// In ru, this message translates to:
  /// **'Топ по занятиям'**
  String get topByLessons;

  /// No description provided for @lessonsShort.
  ///
  /// In ru, this message translates to:
  /// **'зан.'**
  String get lessonsShort;

  /// No description provided for @byStudents.
  ///
  /// In ru, this message translates to:
  /// **'По ученикам'**
  String get byStudents;

  /// No description provided for @purchases.
  ///
  /// In ru, this message translates to:
  /// **'Покупок'**
  String get purchases;

  /// No description provided for @sumLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get sumLabel;

  /// No description provided for @avgLessonCost.
  ///
  /// In ru, this message translates to:
  /// **'Средняя стоимость занятия'**
  String get avgLessonCost;

  /// No description provided for @paymentsWithDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Оплаты со скидкой'**
  String get paymentsWithDiscount;

  /// No description provided for @discountSum.
  ///
  /// In ru, this message translates to:
  /// **'Сумма скидок'**
  String get discountSum;

  /// No description provided for @byPlans.
  ///
  /// In ru, this message translates to:
  /// **'По тарифам'**
  String get byPlans;

  /// No description provided for @purchasesShort.
  ///
  /// In ru, this message translates to:
  /// **'покуп.'**
  String get purchasesShort;

  /// No description provided for @cancellationRatePercent.
  ///
  /// In ru, this message translates to:
  /// **'Процент отмен: {rate}%'**
  String cancellationRatePercent(String rate);

  /// No description provided for @paymentMethods.
  ///
  /// In ru, this message translates to:
  /// **'Способы оплаты'**
  String get paymentMethods;

  /// No description provided for @cardPaymentsCount.
  ///
  /// In ru, this message translates to:
  /// **'Карта ({count})'**
  String cardPaymentsCount(int count);

  /// No description provided for @cashPaymentsCount.
  ///
  /// In ru, this message translates to:
  /// **'Наличные ({count})'**
  String cashPaymentsCount(int count);

  /// No description provided for @lessonsCountShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} зан.'**
  String lessonsCountShort(int count);

  /// No description provided for @mergeStudentsCount.
  ///
  /// In ru, this message translates to:
  /// **'Объединить {count} учеников'**
  String mergeStudentsCount(int count);

  /// No description provided for @mergeStudentsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объединить {count} учеников'**
  String mergeStudentsTitle(int count);

  /// No description provided for @mergeStudentsWarning.
  ///
  /// In ru, this message translates to:
  /// **'Будет создана новая карточка. Исходные карточки будут архивированы.'**
  String get mergeStudentsWarning;

  /// No description provided for @fromLegacyBalance.
  ///
  /// In ru, this message translates to:
  /// **'Из остатка'**
  String get fromLegacyBalance;

  /// No description provided for @cardCreatedWithName.
  ///
  /// In ru, this message translates to:
  /// **'Создана карточка \"{name}\"'**
  String cardCreatedWithName(String name);

  /// No description provided for @mergeWarning.
  ///
  /// In ru, this message translates to:
  /// **'Будет создана новая карточка. Исходные карточки будут архивированы.'**
  String get mergeWarning;

  /// No description provided for @studentsToMerge.
  ///
  /// In ru, this message translates to:
  /// **'Объединяемые ученики'**
  String get studentsToMerge;

  /// No description provided for @totalBalance.
  ///
  /// In ru, this message translates to:
  /// **'Общий баланс'**
  String get totalBalance;

  /// No description provided for @fromLegacy.
  ///
  /// In ru, this message translates to:
  /// **'Из остатка'**
  String get fromLegacy;

  /// No description provided for @newCardData.
  ///
  /// In ru, this message translates to:
  /// **'Данные новой карточки'**
  String get newCardData;

  /// No description provided for @merge.
  ///
  /// In ru, this message translates to:
  /// **'Объединить'**
  String get merge;

  /// No description provided for @cardCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создана карточка \"{name}\"'**
  String cardCreated(String name);

  /// No description provided for @mergeError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при объединении'**
  String get mergeError;

  /// No description provided for @lessonTime.
  ///
  /// In ru, this message translates to:
  /// **'Время занятия'**
  String get lessonTime;

  /// No description provided for @invalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректно'**
  String get invalid;

  /// No description provided for @durationFormat.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {mins} мин'**
  String durationFormat(int hours, int mins);

  /// No description provided for @hoursOnly.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String hoursOnly(int hours);

  /// No description provided for @minutesOnly.
  ///
  /// In ru, this message translates to:
  /// **'{mins} мин'**
  String minutesOnly(int mins);

  /// No description provided for @quickSelect.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый выбор'**
  String get quickSelect;

  /// No description provided for @palette.
  ///
  /// In ru, this message translates to:
  /// **'Палитра'**
  String get palette;

  /// No description provided for @unarchive.
  ///
  /// In ru, this message translates to:
  /// **'Разархивировать'**
  String get unarchive;

  /// No description provided for @deleteForever.
  ///
  /// In ru, this message translates to:
  /// **'Удалить навсегда'**
  String get deleteForever;

  /// No description provided for @studentInArchive.
  ///
  /// In ru, this message translates to:
  /// **'Ученик в архиве'**
  String get studentInArchive;

  /// No description provided for @unarchiveToCreateLessons.
  ///
  /// In ru, this message translates to:
  /// **'Разархивируйте, чтобы создавать занятия'**
  String get unarchiveToCreateLessons;

  /// No description provided for @contactInfo.
  ///
  /// In ru, this message translates to:
  /// **'Контактная информация'**
  String get contactInfo;

  /// No description provided for @noPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон не указан'**
  String get noPhone;

  /// No description provided for @phoneCopied.
  ///
  /// In ru, this message translates to:
  /// **'Телефон скопирован'**
  String get phoneCopied;

  /// No description provided for @lessonStatisticsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Статистика занятий'**
  String get lessonStatisticsTitle;

  /// No description provided for @noLessonsYet.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий'**
  String get noLessonsYet;

  /// No description provided for @balance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс'**
  String get balance;

  /// No description provided for @subscriptionsSection.
  ///
  /// In ru, this message translates to:
  /// **'Абонементы'**
  String get subscriptionsSection;

  /// No description provided for @noActiveSubscriptions.
  ///
  /// In ru, this message translates to:
  /// **'Нет активных абонементов'**
  String get noActiveSubscriptions;

  /// No description provided for @paymentsSection.
  ///
  /// In ru, this message translates to:
  /// **'Оплаты'**
  String get paymentsSection;

  /// No description provided for @noPaymentsHistory.
  ///
  /// In ru, this message translates to:
  /// **'Нет истории оплат'**
  String get noPaymentsHistory;

  /// No description provided for @showMoreCount.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё ({count})'**
  String showMoreCount(int count);

  /// No description provided for @permanentScheduleSection.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное расписание'**
  String get permanentScheduleSection;

  /// No description provided for @noPermanentSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Нет постоянного расписания'**
  String get noPermanentSchedule;

  /// No description provided for @addScheduleSlot.
  ///
  /// In ru, this message translates to:
  /// **'Добавить слот'**
  String get addScheduleSlot;

  /// No description provided for @createLessonsFromSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия из расписания'**
  String get createLessonsFromSchedule;

  /// No description provided for @repeatGroupsSection.
  ///
  /// In ru, this message translates to:
  /// **'Серии занятий'**
  String get repeatGroupsSection;

  /// No description provided for @noRepeatGroups.
  ///
  /// In ru, this message translates to:
  /// **'Нет серий занятий'**
  String get noRepeatGroups;

  /// No description provided for @lessonHistorySection.
  ///
  /// In ru, this message translates to:
  /// **'История занятий'**
  String get lessonHistorySection;

  /// No description provided for @manageLessonsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Управление занятиями'**
  String get manageLessonsTitle;

  /// No description provided for @archivedSection.
  ///
  /// In ru, this message translates to:
  /// **'Архивированные'**
  String get archivedSection;

  /// No description provided for @archived.
  ///
  /// In ru, this message translates to:
  /// **'Архивировано'**
  String get archived;

  /// No description provided for @inRoom.
  ///
  /// In ru, this message translates to:
  /// **'в каб. {room}'**
  String inRoom(String room);

  /// No description provided for @temporaryRoomUntil.
  ///
  /// In ru, this message translates to:
  /// **'Временно {room} до {date}'**
  String temporaryRoomUntil(String room, String date);

  /// No description provided for @schedulePausedUntil.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено до {date}'**
  String schedulePausedUntil(String date);

  /// No description provided for @resumeScheduleAction.
  ///
  /// In ru, this message translates to:
  /// **'Возобновить'**
  String get resumeScheduleAction;

  /// No description provided for @pauseScheduleAction.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pauseScheduleAction;

  /// No description provided for @clearReplacementRoom.
  ///
  /// In ru, this message translates to:
  /// **'Снять замену кабинета'**
  String get clearReplacementRoom;

  /// No description provided for @temporaryRoomReplacementAction.
  ///
  /// In ru, this message translates to:
  /// **'Временная замена кабинета'**
  String get temporaryRoomReplacementAction;

  /// No description provided for @archiveSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать'**
  String get archiveSchedule;

  /// No description provided for @unarchiveSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Разархивировать'**
  String get unarchiveSchedule;

  /// No description provided for @deleteScheduleAction.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteScheduleAction;

  /// No description provided for @scheduleResumedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание возобновлено'**
  String get scheduleResumedMessage;

  /// No description provided for @pauseScheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить расписание'**
  String get pauseScheduleTitle;

  /// No description provided for @pauseScheduleUntilQuestion.
  ///
  /// In ru, this message translates to:
  /// **'До какой даты приостановить?'**
  String get pauseScheduleUntilQuestion;

  /// No description provided for @resumeDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата возобновления'**
  String get resumeDate;

  /// No description provided for @selectDatePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дату'**
  String get selectDatePlaceholder;

  /// No description provided for @pauseAction.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pauseAction;

  /// No description provided for @schedulePausedUntilMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание приостановлено до {date}'**
  String schedulePausedUntilMessage(String date);

  /// No description provided for @replacementRoomCleared.
  ///
  /// In ru, this message translates to:
  /// **'Замена кабинета снята'**
  String get replacementRoomCleared;

  /// No description provided for @temporaryRoomReplacementTitle.
  ///
  /// In ru, this message translates to:
  /// **'Временная замена кабинета'**
  String get temporaryRoomReplacementTitle;

  /// No description provided for @untilDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'До какой даты'**
  String get untilDateLabel;

  /// No description provided for @replacementRoomSet.
  ///
  /// In ru, this message translates to:
  /// **'Замена кабинета установлена'**
  String get replacementRoomSet;

  /// No description provided for @archiveScheduleQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать расписание?'**
  String get archiveScheduleQuestion;

  /// No description provided for @archiveScheduleMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот будет перемещён в архив. Вы сможете разархивировать его позже.'**
  String get archiveScheduleMessage;

  /// No description provided for @scheduleArchivedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание архивировано'**
  String get scheduleArchivedMessage;

  /// No description provided for @scheduleUnarchivedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание разархивировано'**
  String get scheduleUnarchivedMessage;

  /// No description provided for @deleteScheduleQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить расписание?'**
  String get deleteScheduleQuestion;

  /// No description provided for @deleteScheduleMessage.
  ///
  /// In ru, this message translates to:
  /// **'Этот слот будет удалён навсегда. Это действие нельзя отменить.'**
  String get deleteScheduleMessage;

  /// No description provided for @scheduleDeletedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание удалено'**
  String get scheduleDeletedMessage;

  /// No description provided for @editScheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать расписание'**
  String get editScheduleTitle;

  /// No description provided for @startTimeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Время начала'**
  String get startTimeLabel;

  /// No description provided for @endTimeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Время окончания'**
  String get endTimeLabel;

  /// No description provided for @roomFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get roomFieldLabel;

  /// No description provided for @scheduleUpdatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание обновлено'**
  String get scheduleUpdatedMessage;

  /// No description provided for @scheduleUpdateError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка обновления (возможно конфликт времени)'**
  String get scheduleUpdateError;

  /// No description provided for @lessonsInSeries.
  ///
  /// In ru, this message translates to:
  /// **'{count} занятий в серии'**
  String lessonsInSeries(int count);

  /// No description provided for @seriesStartDate.
  ///
  /// In ru, this message translates to:
  /// **'Начало: {date}'**
  String seriesStartDate(String date);

  /// No description provided for @editAction.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editAction;

  /// No description provided for @deleteSeriesAction.
  ///
  /// In ru, this message translates to:
  /// **'Удалить серию'**
  String get deleteSeriesAction;

  /// No description provided for @editSeriesSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать серию'**
  String get editSeriesSheetTitle;

  /// No description provided for @deleteSeriesQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить серию?'**
  String get deleteSeriesQuestion;

  /// No description provided for @deleteSeriesMessage.
  ///
  /// In ru, this message translates to:
  /// **'Будет удалено {count} занятий из расписания. Это действие нельзя отменить.'**
  String deleteSeriesMessage(int count);

  /// No description provided for @seriesDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Серия удалена'**
  String get seriesDeleted;

  /// No description provided for @deletionError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка удаления'**
  String get deletionError;

  /// No description provided for @seriesUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Серия обновлена'**
  String get seriesUpdated;

  /// No description provided for @updateError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка обновления'**
  String get updateError;

  /// No description provided for @createLessonsFromScheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия из расписания'**
  String get createLessonsFromScheduleTitle;

  /// No description provided for @createLessonsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Будут созданы занятия на основе постоянного расписания ученика.'**
  String get createLessonsDescription;

  /// No description provided for @fromDateField.
  ///
  /// In ru, this message translates to:
  /// **'С даты'**
  String get fromDateField;

  /// No description provided for @toDateField.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get toDateField;

  /// No description provided for @oneWeek.
  ///
  /// In ru, this message translates to:
  /// **'1 неделя'**
  String get oneWeek;

  /// No description provided for @twoWeeks.
  ///
  /// In ru, this message translates to:
  /// **'2 недели'**
  String get twoWeeks;

  /// No description provided for @checkConflicts.
  ///
  /// In ru, this message translates to:
  /// **'Проверить конфликты'**
  String get checkConflicts;

  /// No description provided for @noConflictsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Конфликтов не найдено'**
  String get noConflictsMessage;

  /// No description provided for @conflictsFoundCount.
  ///
  /// In ru, this message translates to:
  /// **'Найдено конфликтов: {count}'**
  String conflictsFoundCount(int count);

  /// No description provided for @datesWillBeSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Эти даты будут пропущены:'**
  String get datesWillBeSkipped;

  /// No description provided for @andMoreCount.
  ///
  /// In ru, this message translates to:
  /// **'...и ещё {count}'**
  String andMoreCount(int count);

  /// No description provided for @createLessonsAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия'**
  String get createLessonsAction;

  /// No description provided for @creatingLessons.
  ///
  /// In ru, this message translates to:
  /// **'Создание...'**
  String get creatingLessons;

  /// No description provided for @lessonsCreatedSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Создано занятий: {success}, пропущено: {skipped}'**
  String lessonsCreatedSkipped(int success, int skipped);

  /// No description provided for @addPermanentScheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить постоянное расписание'**
  String get addPermanentScheduleTitle;

  /// No description provided for @selectDaysAndTimeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дни недели и время занятий'**
  String get selectDaysAndTimeDescription;

  /// No description provided for @daysOfWeek.
  ///
  /// In ru, this message translates to:
  /// **'Дни недели'**
  String get daysOfWeek;

  /// No description provided for @timeAndRooms.
  ///
  /// In ru, this message translates to:
  /// **'Время и кабинеты'**
  String get timeAndRooms;

  /// No description provided for @validFromField.
  ///
  /// In ru, this message translates to:
  /// **'Действует с'**
  String get validFromField;

  /// No description provided for @teacherRequired.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель *'**
  String get teacherRequired;

  /// No description provided for @selectTeacherValidation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите преподавателя'**
  String get selectTeacherValidation;

  /// No description provided for @subjectOptional.
  ///
  /// In ru, this message translates to:
  /// **'Предмет (опционально)'**
  String get subjectOptional;

  /// No description provided for @notSpecifiedOption.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get notSpecifiedOption;

  /// No description provided for @lessonTypeOptional.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия (опционально)'**
  String get lessonTypeOptional;

  /// No description provided for @checkingConflictsStatus.
  ///
  /// In ru, this message translates to:
  /// **'Проверка конфликтов...'**
  String get checkingConflictsStatus;

  /// No description provided for @conflictsCountChange.
  ///
  /// In ru, this message translates to:
  /// **'Конфликты: {count} (измените время)'**
  String conflictsCountChange(int count);

  /// No description provided for @hasConflicts.
  ///
  /// In ru, this message translates to:
  /// **'Есть конфликты'**
  String get hasConflicts;

  /// No description provided for @selectRoomsValidation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты'**
  String get selectRoomsValidation;

  /// No description provided for @createSchedulesCountAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать {count} занятий'**
  String createSchedulesCountAction(int count);

  /// No description provided for @createScheduleAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать расписание'**
  String get createScheduleAction;

  /// No description provided for @selectAtLeastOneDayValidation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы один день недели'**
  String get selectAtLeastOneDayValidation;

  /// No description provided for @selectRoomForEachDayValidation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинет для каждого дня'**
  String get selectRoomForEachDayValidation;

  /// No description provided for @schedulesCreatedCount.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} записей расписания'**
  String schedulesCreatedCount(int count);

  /// No description provided for @scheduleCreated.
  ///
  /// In ru, this message translates to:
  /// **'Расписание создано'**
  String get scheduleCreated;

  /// No description provided for @conflictTimeMessage.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт! Время занято'**
  String get conflictTimeMessage;

  /// No description provided for @manageLessonsSection.
  ///
  /// In ru, this message translates to:
  /// **'Управление занятиями'**
  String get manageLessonsSection;

  /// No description provided for @futureLessonsFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено {count} будущих занятий'**
  String futureLessonsFound(int count);

  /// No description provided for @noScheduledLessonsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет запланированных занятий'**
  String get noScheduledLessonsMessage;

  /// No description provided for @loadingErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {error}'**
  String loadingErrorMessage(String error);

  /// No description provided for @reassignTeacherTitle.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить преподавателя'**
  String get reassignTeacherTitle;

  /// No description provided for @reassignTeacherSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать нового преподавателя для всех занятий'**
  String get reassignTeacherSubtitle;

  /// No description provided for @deleteAllFutureLessonsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все занятия'**
  String get deleteAllFutureLessonsTitle;

  /// No description provided for @deleteAllFutureLessonsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Баланс абонементов не изменится'**
  String get deleteAllFutureLessonsSubtitle;

  /// No description provided for @deleteAllLessonsQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все занятия?'**
  String get deleteAllLessonsQuestion;

  /// No description provided for @deleteAllLessonsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить {count} будущих занятий \"{name}\"?\n\nБаланс абонементов не изменится.'**
  String deleteAllLessonsMessage(int count, String name);

  /// No description provided for @deletedLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Удалено {count} занятий'**
  String deletedLessonsCount(int count);

  /// No description provided for @noAvailableTeachersMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных преподавателей'**
  String get noAvailableTeachersMessage;

  /// No description provided for @selectTeacherTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите преподавателя'**
  String get selectTeacherTitle;

  /// No description provided for @reassignedSlotsCount.
  ///
  /// In ru, this message translates to:
  /// **'Переназначено {count} слотов'**
  String reassignedSlotsCount(int count);

  /// No description provided for @pausedSlotsCount.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено {count} слотов'**
  String pausedSlotsCount(int count);

  /// No description provided for @deactivateScheduleQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать расписание?'**
  String get deactivateScheduleQuestion;

  /// No description provided for @deactivateSlotsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать {count} слотов постоянного расписания?\n\nСлоты останутся в архиве и могут быть восстановлены.'**
  String deactivateSlotsMessage(int count);

  /// No description provided for @deactivateAction.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать'**
  String get deactivateAction;

  /// No description provided for @deactivatedSlotsCount.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировано {count} слотов'**
  String deactivatedSlotsCount(int count);

  /// No description provided for @scheduleSlotsDays.
  ///
  /// In ru, this message translates to:
  /// **'{count} {slots}'**
  String scheduleSlotsDays(int count, String slots);

  /// No description provided for @slotWord.
  ///
  /// In ru, this message translates to:
  /// **'слот'**
  String get slotWord;

  /// No description provided for @slotsWordFew.
  ///
  /// In ru, this message translates to:
  /// **'слота'**
  String get slotsWordFew;

  /// No description provided for @slotsWordMany.
  ///
  /// In ru, this message translates to:
  /// **'слотов'**
  String get slotsWordMany;

  /// No description provided for @pauseAllSlots.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get pauseAllSlots;

  /// No description provided for @pauseAllSlotsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Временно приостановить все слоты'**
  String get pauseAllSlotsSubtitle;

  /// No description provided for @deactivateAllSlots.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать'**
  String get deactivateAllSlots;

  /// No description provided for @deactivateAllSlotsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Отключить постоянное расписание'**
  String get deactivateAllSlotsSubtitle;

  /// No description provided for @newTeacherLabel.
  ///
  /// In ru, this message translates to:
  /// **'Новый преподаватель'**
  String get newTeacherLabel;

  /// No description provided for @allLessonsCanBeReassigned.
  ///
  /// In ru, this message translates to:
  /// **'Все {count} занятий можно переназначить'**
  String allLessonsCanBeReassigned(int count);

  /// No description provided for @canReassignCount.
  ///
  /// In ru, this message translates to:
  /// **'Можно переназначить: {count} занятий'**
  String canReassignCount(int count);

  /// No description provided for @reassignCount.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить {count} занятий'**
  String reassignCount(int count);

  /// No description provided for @reassignAllLessons.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить все занятия'**
  String get reassignAllLessons;

  /// No description provided for @noCompletedLessons.
  ///
  /// In ru, this message translates to:
  /// **'Нет завершённых занятий'**
  String get noCompletedLessons;

  /// No description provided for @noSubjectLabel.
  ///
  /// In ru, this message translates to:
  /// **'Без предмета'**
  String get noSubjectLabel;

  /// No description provided for @showMore.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get showMore;

  /// No description provided for @editStudentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editStudentTitle;

  /// No description provided for @basicInfoSection.
  ///
  /// In ru, this message translates to:
  /// **'Основная информация'**
  String get basicInfoSection;

  /// No description provided for @fullNameField.
  ///
  /// In ru, this message translates to:
  /// **'ФИО'**
  String get fullNameField;

  /// No description provided for @phoneField.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phoneField;

  /// No description provided for @commentField.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get commentField;

  /// No description provided for @legacyBalanceSection.
  ///
  /// In ru, this message translates to:
  /// **'Остаток занятий'**
  String get legacyBalanceSection;

  /// No description provided for @currentBalance.
  ///
  /// In ru, this message translates to:
  /// **'Текущий остаток'**
  String get currentBalance;

  /// No description provided for @balanceLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} занятий'**
  String balanceLessonsCount(int count);

  /// No description provided for @changeBalance.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get changeBalance;

  /// No description provided for @changeBalanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить остаток'**
  String get changeBalanceTitle;

  /// No description provided for @quantityField.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantityField;

  /// No description provided for @quantityHint.
  ///
  /// In ru, this message translates to:
  /// **'+5 или -3'**
  String get quantityHint;

  /// No description provided for @reasonOptional.
  ///
  /// In ru, this message translates to:
  /// **'Причина (опционально)'**
  String get reasonOptional;

  /// No description provided for @applyAction.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get applyAction;

  /// No description provided for @saveChangesAction.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get saveChangesAction;

  /// No description provided for @lessonsAddedCount.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено {count} занятий'**
  String lessonsAddedCount(int count);

  /// No description provided for @lessonsDeductedCount.
  ///
  /// In ru, this message translates to:
  /// **'Списано {count} занятий'**
  String lessonsDeductedCount(int count);

  /// No description provided for @addLessonsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить занятия'**
  String get addLessonsTitle;

  /// No description provided for @legacyBalanceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Остаток занятий: {count}'**
  String legacyBalanceLabel(int count);

  /// No description provided for @lessonsQuantityField.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий'**
  String get lessonsQuantityField;

  /// No description provided for @quantityPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Положительное или отрицательное число'**
  String get quantityPlaceholder;

  /// No description provided for @enterQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество'**
  String get enterQuantity;

  /// No description provided for @enterInteger.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число'**
  String get enterInteger;

  /// No description provided for @quantityCannotBeZero.
  ///
  /// In ru, this message translates to:
  /// **'Количество не может быть 0'**
  String get quantityCannotBeZero;

  /// No description provided for @commentOptionalField.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get commentOptionalField;

  /// No description provided for @commentHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Перенос с другого абонемента'**
  String get commentHint;

  /// No description provided for @archiveStudentQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Архивировать ученика?'**
  String get archiveStudentQuestion;

  /// No description provided for @archiveStudentMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" будет перемещён в архив. Вы сможете восстановить его позже.'**
  String archiveStudentMessage(String name);

  /// No description provided for @restoreStudentQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить ученика?'**
  String get restoreStudentQuestion;

  /// No description provided for @restoreStudentMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" будет восстановлен из архива.'**
  String restoreStudentMessage(String name);

  /// No description provided for @deleteStudentQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить ученика навсегда?'**
  String get deleteStudentQuestion;

  /// No description provided for @deleteStudentMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" будет удалён навсегда вместе со всеми данными (занятия, оплаты, абонементы).\n\nЭто действие НЕЛЬЗЯ отменить!'**
  String deleteStudentMessage(String name);

  /// No description provided for @teacherDefault.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель'**
  String get teacherDefault;

  /// No description provided for @unknownName.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный'**
  String get unknownName;

  /// No description provided for @roomDefault.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get roomDefault;

  /// No description provided for @checking.
  ///
  /// In ru, this message translates to:
  /// **'Проверка...'**
  String get checking;

  /// No description provided for @freezeSubscription.
  ///
  /// In ru, this message translates to:
  /// **'Заморозить абонемент'**
  String get freezeSubscription;

  /// No description provided for @freezeSubscriptionDescription.
  ///
  /// In ru, this message translates to:
  /// **'При заморозке срок действия абонемента приостанавливается. После разморозки срок будет продлён на количество дней заморозки.'**
  String get freezeSubscriptionDescription;

  /// No description provided for @daysCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество дней'**
  String get daysCount;

  /// No description provided for @enterQuantityValidation.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество'**
  String get enterQuantityValidation;

  /// No description provided for @enterNumberFrom1To90.
  ///
  /// In ru, this message translates to:
  /// **'Введите число от 1 до 90'**
  String get enterNumberFrom1To90;

  /// No description provided for @freeze.
  ///
  /// In ru, this message translates to:
  /// **'Заморозить'**
  String get freeze;

  /// No description provided for @subscriptionFrozen.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент заморожен'**
  String get subscriptionFrozen;

  /// No description provided for @subscriptionUnfrozen.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент разморожен. Срок продлён до {date}'**
  String subscriptionUnfrozen(String date);

  /// No description provided for @extendSubscription.
  ///
  /// In ru, this message translates to:
  /// **'Продлить срок'**
  String get extendSubscription;

  /// No description provided for @currentTermUntil.
  ///
  /// In ru, this message translates to:
  /// **'Текущий срок: до {date}'**
  String currentTermUntil(String date);

  /// No description provided for @extendForDays.
  ///
  /// In ru, this message translates to:
  /// **'Продлить на дней'**
  String get extendForDays;

  /// No description provided for @enterNumberFrom1To365.
  ///
  /// In ru, this message translates to:
  /// **'Введите число от 1 до 365'**
  String get enterNumberFrom1To365;

  /// No description provided for @extend.
  ///
  /// In ru, this message translates to:
  /// **'Продлить'**
  String get extend;

  /// No description provided for @termExtendedUntil.
  ///
  /// In ru, this message translates to:
  /// **'Срок продлён до {date}'**
  String termExtendedUntil(String date);

  /// No description provided for @subscriptionBalanceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Абонементы: {count}'**
  String subscriptionBalanceLabel(int count);

  /// No description provided for @legacyBalanceShort.
  ///
  /// In ru, this message translates to:
  /// **'Остаток: {count}'**
  String legacyBalanceShort(int count);

  /// No description provided for @addLessonsAction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить занятия'**
  String get addLessonsAction;

  /// No description provided for @avgCost.
  ///
  /// In ru, this message translates to:
  /// **'СР. СТОИМОСТЬ'**
  String get avgCost;

  /// No description provided for @avgCostApprox.
  ///
  /// In ru, this message translates to:
  /// **'СР. СТОИМОСТЬ ≈'**
  String get avgCostApprox;

  /// No description provided for @noDataAvailable.
  ///
  /// In ru, this message translates to:
  /// **'нет данных'**
  String get noDataAvailable;

  /// No description provided for @perLesson.
  ///
  /// In ru, this message translates to:
  /// **'за занятие'**
  String get perLesson;

  /// No description provided for @manageLessonsAction.
  ///
  /// In ru, this message translates to:
  /// **'Управление'**
  String get manageLessonsAction;

  /// No description provided for @conductedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Проведено'**
  String get conductedLabel;

  /// No description provided for @cancelledLabel.
  ///
  /// In ru, this message translates to:
  /// **'Отменено'**
  String get cancelledLabel;

  /// No description provided for @discountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get discountLabel;

  /// No description provided for @correctionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Корр.'**
  String get correctionLabel;

  /// No description provided for @legacyBalanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Остаток занятий'**
  String get legacyBalanceTitle;

  /// No description provided for @exhaustedStatus.
  ///
  /// In ru, this message translates to:
  /// **'Исчерпан'**
  String get exhaustedStatus;

  /// No description provided for @expiringSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро истекает'**
  String get expiringSoon;

  /// No description provided for @groupSubscription.
  ///
  /// In ru, this message translates to:
  /// **'Групповой'**
  String get groupSubscription;

  /// No description provided for @frozenUntilDate.
  ///
  /// In ru, this message translates to:
  /// **'Заморожен до {date}'**
  String frozenUntilDate(String date);

  /// No description provided for @expiredDate.
  ///
  /// In ru, this message translates to:
  /// **'Истёк {date}'**
  String expiredDate(String date);

  /// No description provided for @validUntilDate.
  ///
  /// In ru, this message translates to:
  /// **'Действует до {date}'**
  String validUntilDate(String date);

  /// No description provided for @unfreezeAction.
  ///
  /// In ru, this message translates to:
  /// **'Разморозить'**
  String get unfreezeAction;

  /// No description provided for @teachersSection.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get teachersSection;

  /// No description provided for @addTeacherTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить преподавателя'**
  String get addTeacherTooltip;

  /// No description provided for @noLinkedTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Нет привязанных преподавателей'**
  String get noLinkedTeachers;

  /// No description provided for @addTeacherTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить преподавателя'**
  String get addTeacherTitle;

  /// No description provided for @allTeachersAdded.
  ///
  /// In ru, this message translates to:
  /// **'Все преподаватели уже добавлены'**
  String get allTeachersAdded;

  /// No description provided for @teacherAdded.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель добавлен'**
  String get teacherAdded;

  /// No description provided for @removeTeacherQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить преподавателя?'**
  String get removeTeacherQuestion;

  /// No description provided for @removeTeacherMessage.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель будет отвязан от этого ученика.'**
  String get removeTeacherMessage;

  /// No description provided for @teacherRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель удалён'**
  String get teacherRemoved;

  /// No description provided for @subjectsSection.
  ///
  /// In ru, this message translates to:
  /// **'Предметы'**
  String get subjectsSection;

  /// No description provided for @noLinkedSubjects.
  ///
  /// In ru, this message translates to:
  /// **'Нет привязанных предметов'**
  String get noLinkedSubjects;

  /// No description provided for @addSubjectTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить предмет'**
  String get addSubjectTitle;

  /// No description provided for @allSubjectsAdded.
  ///
  /// In ru, this message translates to:
  /// **'Все предметы уже добавлены'**
  String get allSubjectsAdded;

  /// No description provided for @subjectAdded.
  ///
  /// In ru, this message translates to:
  /// **'Предмет добавлен'**
  String get subjectAdded;

  /// No description provided for @removeSubjectQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить предмет?'**
  String get removeSubjectQuestion;

  /// No description provided for @removeSubjectMessage.
  ///
  /// In ru, this message translates to:
  /// **'Предмет будет отвязан от этого ученика.'**
  String get removeSubjectMessage;

  /// No description provided for @subjectRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Предмет удалён'**
  String get subjectRemoved;

  /// No description provided for @lessonTypesSection.
  ///
  /// In ru, this message translates to:
  /// **'Типы занятий'**
  String get lessonTypesSection;

  /// No description provided for @noLinkedLessonTypes.
  ///
  /// In ru, this message translates to:
  /// **'Нет привязанных типов занятий'**
  String get noLinkedLessonTypes;

  /// No description provided for @addLessonTypeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тип занятия'**
  String get addLessonTypeTitle;

  /// No description provided for @allLessonTypesAdded.
  ///
  /// In ru, this message translates to:
  /// **'Все типы занятий уже добавлены'**
  String get allLessonTypesAdded;

  /// No description provided for @lessonTypeAdded.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия добавлен'**
  String get lessonTypeAdded;

  /// No description provided for @removeLessonTypeQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить тип занятия?'**
  String get removeLessonTypeQuestion;

  /// No description provided for @removeLessonTypeMessage.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия будет отвязан от этого ученика.'**
  String get removeLessonTypeMessage;

  /// No description provided for @lessonTypeRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия удалён'**
  String get lessonTypeRemoved;

  /// No description provided for @mergeWithAction.
  ///
  /// In ru, this message translates to:
  /// **'Объединить с...'**
  String get mergeWithAction;

  /// No description provided for @selectStudentsToMerge.
  ///
  /// In ru, this message translates to:
  /// **'Выберите учеников для объединения с \"{name}\"'**
  String selectStudentsToMerge(String name);

  /// No description provided for @searchStudentsHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск учеников...'**
  String get searchStudentsHint;

  /// No description provided for @noStudentsToMerge.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников для объединения'**
  String get noStudentsToMerge;

  /// No description provided for @balanceValue.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {count}'**
  String balanceValue(int count);

  /// No description provided for @selectStudentsValidation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите учеников'**
  String get selectStudentsValidation;

  /// No description provided for @nextWithCount.
  ///
  /// In ru, this message translates to:
  /// **'Далее ({count})'**
  String nextWithCount(int count);

  /// No description provided for @groupCard.
  ///
  /// In ru, this message translates to:
  /// **'Групповая карточка'**
  String get groupCard;

  /// No description provided for @failedToLoadNames.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить имена'**
  String get failedToLoadNames;

  /// No description provided for @archiveSlots.
  ///
  /// In ru, this message translates to:
  /// **'Архив ({count})'**
  String archiveSlots(int count);

  /// No description provided for @replacementRoom.
  ///
  /// In ru, this message translates to:
  /// **'Замена'**
  String get replacementRoom;

  /// No description provided for @pauseUntilDateFormat.
  ///
  /// In ru, this message translates to:
  /// **'Пауза до {date}'**
  String pauseUntilDateFormat(String date);

  /// No description provided for @onPause.
  ///
  /// In ru, this message translates to:
  /// **'На паузе'**
  String get onPause;

  /// No description provided for @mondayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Пн'**
  String get mondayShort2;

  /// No description provided for @tuesdayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Вт'**
  String get tuesdayShort2;

  /// No description provided for @wednesdayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Ср'**
  String get wednesdayShort2;

  /// No description provided for @thursdayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Чт'**
  String get thursdayShort2;

  /// No description provided for @fridayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Пт'**
  String get fridayShort2;

  /// No description provided for @saturdayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Сб'**
  String get saturdayShort2;

  /// No description provided for @sundayShort2.
  ///
  /// In ru, this message translates to:
  /// **'Вс'**
  String get sundayShort2;

  /// No description provided for @mondayFull.
  ///
  /// In ru, this message translates to:
  /// **'Понедельник'**
  String get mondayFull;

  /// No description provided for @tuesdayFull.
  ///
  /// In ru, this message translates to:
  /// **'Вторник'**
  String get tuesdayFull;

  /// No description provided for @wednesdayFull.
  ///
  /// In ru, this message translates to:
  /// **'Среда'**
  String get wednesdayFull;

  /// No description provided for @thursdayFull.
  ///
  /// In ru, this message translates to:
  /// **'Четверг'**
  String get thursdayFull;

  /// No description provided for @fridayFull.
  ///
  /// In ru, this message translates to:
  /// **'Пятница'**
  String get fridayFull;

  /// No description provided for @saturdayFull.
  ///
  /// In ru, this message translates to:
  /// **'Суббота'**
  String get saturdayFull;

  /// No description provided for @sundayFull.
  ///
  /// In ru, this message translates to:
  /// **'Воскресенье'**
  String get sundayFull;

  /// No description provided for @seriesStartDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Начало: {date}'**
  String seriesStartDateLabel(String date);

  /// No description provided for @editSeriesAction.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editSeriesAction;

  /// No description provided for @deleteSeriesLessons.
  ///
  /// In ru, this message translates to:
  /// **'Будет удалено {count} занятий из расписания. Это действие нельзя отменить.'**
  String deleteSeriesLessons(int count);

  /// No description provided for @saveSeries.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get saveSeries;

  /// No description provided for @invalidTimeError.
  ///
  /// In ru, this message translates to:
  /// **'Некорректно'**
  String get invalidTimeError;

  /// No description provided for @roomFieldHint.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get roomFieldHint;

  /// No description provided for @pauseScheduleUntilDate.
  ///
  /// In ru, this message translates to:
  /// **'До какой даты приостановить?'**
  String get pauseScheduleUntilDate;

  /// No description provided for @resumeDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Дата возобновления'**
  String get resumeDateLabel;

  /// No description provided for @selectDateHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дату'**
  String get selectDateHint;

  /// No description provided for @pauseUntilMessage.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить до'**
  String get pauseUntilMessage;

  /// No description provided for @selectRoomLabel.
  ///
  /// In ru, this message translates to:
  /// **'Новый кабинет'**
  String get selectRoomLabel;

  /// No description provided for @untilDateQuestion.
  ///
  /// In ru, this message translates to:
  /// **'До какой даты'**
  String get untilDateQuestion;

  /// No description provided for @applyRoomReplacement.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get applyRoomReplacement;

  /// No description provided for @archiveScheduleConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Слот будет перемещён в архив. Вы сможете разархивировать его позже.'**
  String get archiveScheduleConfirm;

  /// No description provided for @deleteScheduleConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Этот слот будет удалён навсегда. Это действие нельзя отменить.'**
  String get deleteScheduleConfirm;

  /// No description provided for @errorWithParam.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String errorWithParam(String error);

  /// No description provided for @createLessonsFromScheduleDescription.
  ///
  /// In ru, this message translates to:
  /// **'Будут созданы занятия на основе постоянного расписания ученика.'**
  String get createLessonsFromScheduleDescription;

  /// No description provided for @toDateLabel2.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get toDateLabel2;

  /// No description provided for @checkConflictsAction.
  ///
  /// In ru, this message translates to:
  /// **'Проверить конфликты'**
  String get checkConflictsAction;

  /// No description provided for @noConflictsFoundMessage.
  ///
  /// In ru, this message translates to:
  /// **'Конфликтов не найдено'**
  String get noConflictsFoundMessage;

  /// No description provided for @conflictsCountMessage.
  ///
  /// In ru, this message translates to:
  /// **'Найдено конфликтов: {count}'**
  String conflictsCountMessage(int count);

  /// No description provided for @datesWillBeSkippedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Эти даты будут пропущены:'**
  String get datesWillBeSkippedMessage;

  /// No description provided for @andMoreLabel.
  ///
  /// In ru, this message translates to:
  /// **'...и ещё {count}'**
  String andMoreLabel(int count);

  /// No description provided for @creatingMessage.
  ///
  /// In ru, this message translates to:
  /// **'Создание...'**
  String get creatingMessage;

  /// No description provided for @lessonsCreatedResult.
  ///
  /// In ru, this message translates to:
  /// **'Создано занятий: {count}'**
  String lessonsCreatedResult(int count);

  /// No description provided for @addPermanentScheduleDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите дни недели и время занятий'**
  String get addPermanentScheduleDescription;

  /// No description provided for @timeAndRoomsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Время и кабинеты'**
  String get timeAndRoomsLabel;

  /// No description provided for @validFromLabel.
  ///
  /// In ru, this message translates to:
  /// **'Действует с'**
  String get validFromLabel;

  /// No description provided for @teacherRequiredLabel.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель *'**
  String get teacherRequiredLabel;

  /// No description provided for @selectTeacherError.
  ///
  /// In ru, this message translates to:
  /// **'Выберите преподавателя'**
  String get selectTeacherError;

  /// No description provided for @subjectOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Предмет (опционально)'**
  String get subjectOptionalLabel;

  /// No description provided for @notSpecifiedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get notSpecifiedLabel;

  /// No description provided for @lessonTypeOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия (опционально)'**
  String get lessonTypeOptionalLabel;

  /// No description provided for @conflictsChangeTime.
  ///
  /// In ru, this message translates to:
  /// **'Конфликты: {count} (измените время)'**
  String conflictsChangeTime(int count);

  /// No description provided for @hasConflictsError.
  ///
  /// In ru, this message translates to:
  /// **'Есть конфликты'**
  String get hasConflictsError;

  /// No description provided for @selectRoomsError.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты'**
  String get selectRoomsError;

  /// No description provided for @checkingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Проверка...'**
  String get checkingLabel;

  /// No description provided for @createCountSchedules.
  ///
  /// In ru, this message translates to:
  /// **'Создать {count} занятий'**
  String createCountSchedules(int count);

  /// No description provided for @createScheduleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать расписание'**
  String get createScheduleLabel;

  /// No description provided for @selectAtLeastOneDay.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы один день недели'**
  String get selectAtLeastOneDay;

  /// No description provided for @selectRoomForEachDay.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинет для каждого дня'**
  String get selectRoomForEachDay;

  /// No description provided for @scheduleCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание создано'**
  String get scheduleCreatedMessage;

  /// No description provided for @schedulesCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} записей расписания'**
  String schedulesCreatedMessage(int count);

  /// No description provided for @conflictTimeOccupiedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт! Время занято'**
  String get conflictTimeOccupiedMessage;

  /// No description provided for @deleteAllLessonsConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить {count} будущих занятий \"{name}\"?\n\nБаланс абонементов не изменится.'**
  String deleteAllLessonsConfirm(int count, String name);

  /// No description provided for @deletedCountLessons.
  ///
  /// In ru, this message translates to:
  /// **'Удалено {count} занятий'**
  String deletedCountLessons(int count);

  /// No description provided for @noAvailableTeachersError.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных преподавателей'**
  String get noAvailableTeachersError;

  /// No description provided for @selectTeacherLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выберите преподавателя'**
  String get selectTeacherLabel;

  /// No description provided for @noNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get noNameLabel;

  /// No description provided for @reassignedSlotsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Переназначено {count} слотов'**
  String reassignedSlotsMessage(int count);

  /// No description provided for @pausedSlotsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено {count} слотов'**
  String pausedSlotsMessage(int count);

  /// No description provided for @deactivateScheduleConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать {count} слотов постоянного расписания?\n\nСлоты останутся в архиве и могут быть восстановлены.'**
  String deactivateScheduleConfirm(int count);

  /// No description provided for @deactivatedSlotsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировано {count} слотов'**
  String deactivatedSlotsMessage(int count);

  /// No description provided for @manageLessonsHeader.
  ///
  /// In ru, this message translates to:
  /// **'Управление занятиями'**
  String get manageLessonsHeader;

  /// No description provided for @loadingErrorLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {error}'**
  String loadingErrorLabel(String error);

  /// No description provided for @noScheduledLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Нет запланированных занятий'**
  String get noScheduledLessonsLabel;

  /// No description provided for @foundFutureLessons.
  ///
  /// In ru, this message translates to:
  /// **'Найдено {count} будущих занятий'**
  String foundFutureLessons(int count);

  /// No description provided for @reassignTeacherSubtitleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать нового преподавателя для всех занятий'**
  String get reassignTeacherSubtitleLabel;

  /// No description provided for @deleteAllLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все занятия'**
  String get deleteAllLessonsLabel;

  /// No description provided for @subscriptionBalanceWontChange.
  ///
  /// In ru, this message translates to:
  /// **'Баланс абонементов не изменится'**
  String get subscriptionBalanceWontChange;

  /// No description provided for @permanentScheduleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное расписание'**
  String get permanentScheduleLabel;

  /// No description provided for @slotsCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'{count} {slots}'**
  String slotsCountLabel(int count, String slots);

  /// No description provided for @forAllScheduleSlots.
  ///
  /// In ru, this message translates to:
  /// **'Для всех слотов расписания'**
  String get forAllScheduleSlots;

  /// No description provided for @temporaryPauseAllSlots.
  ///
  /// In ru, this message translates to:
  /// **'Временно приостановить все слоты'**
  String get temporaryPauseAllSlots;

  /// No description provided for @disablePermanentSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Отключить постоянное расписание'**
  String get disablePermanentSchedule;

  /// No description provided for @noLessonsToReassignError.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий для переназначения'**
  String get noLessonsToReassignError;

  /// No description provided for @reassignedLessonsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Переназначено {count} занятий'**
  String reassignedLessonsMessage(int count);

  /// No description provided for @reassignTeacherHeader.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить преподавателя'**
  String get reassignTeacherHeader;

  /// No description provided for @newTeacherFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Новый преподаватель'**
  String get newTeacherFieldLabel;

  /// No description provided for @allLessonsCanReassign.
  ///
  /// In ru, this message translates to:
  /// **'Все {count} занятий можно переназначить'**
  String allLessonsCanReassign(int count);

  /// No description provided for @foundConflictsCount.
  ///
  /// In ru, this message translates to:
  /// **'Найдено конфликтов: {count}'**
  String foundConflictsCount(int count);

  /// No description provided for @canReassignLessons.
  ///
  /// In ru, this message translates to:
  /// **'Можно переназначить: {count} занятий'**
  String canReassignLessons(int count);

  /// No description provided for @reassignLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить {count} занятий'**
  String reassignLessonsCount(int count);

  /// No description provided for @reassignAllLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Переназначить все занятия'**
  String get reassignAllLessonsLabel;

  /// No description provided for @lessonHistoryHeader.
  ///
  /// In ru, this message translates to:
  /// **'История занятий'**
  String get lessonHistoryHeader;

  /// No description provided for @noCompletedLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Нет завершённых занятий'**
  String get noCompletedLessonsLabel;

  /// No description provided for @showMoreAction.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get showMoreAction;

  /// No description provided for @noSubjectPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Без предмета'**
  String get noSubjectPlaceholder;

  /// No description provided for @studentUpdatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ученик обновлен'**
  String get studentUpdatedMessage;

  /// No description provided for @enterLessonsCountValidation.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество занятий'**
  String get enterLessonsCountValidation;

  /// No description provided for @lessonsAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено {count} занятий'**
  String lessonsAddedMessage(int count);

  /// No description provided for @lessonsDeductedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Списано {count} занятий'**
  String lessonsDeductedMessage(int count);

  /// No description provided for @editStudentHeader.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editStudentHeader;

  /// No description provided for @basicInfoHeader.
  ///
  /// In ru, this message translates to:
  /// **'Основная информация'**
  String get basicInfoHeader;

  /// No description provided for @fullNameFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'ФИО'**
  String get fullNameFieldLabel;

  /// No description provided for @enterNameError.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get enterNameError;

  /// No description provided for @phoneFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phoneFieldLabel;

  /// No description provided for @commentFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get commentFieldLabel;

  /// No description provided for @legacyBalanceHeader.
  ///
  /// In ru, this message translates to:
  /// **'Остаток занятий'**
  String get legacyBalanceHeader;

  /// No description provided for @currentBalanceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Текущий остаток'**
  String get currentBalanceLabel;

  /// No description provided for @changeBalanceAction.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get changeBalanceAction;

  /// No description provided for @changeBalanceHeader.
  ///
  /// In ru, this message translates to:
  /// **'Изменить остаток'**
  String get changeBalanceHeader;

  /// No description provided for @quantityFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantityFieldLabel;

  /// No description provided for @reasonOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Причина (опционально)'**
  String get reasonOptionalLabel;

  /// No description provided for @applyChangeAction.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get applyChangeAction;

  /// No description provided for @quantityCannotBeZeroError.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий не может быть 0'**
  String get quantityCannotBeZeroError;

  /// No description provided for @addLessonsHeader.
  ///
  /// In ru, this message translates to:
  /// **'Добавить занятия'**
  String get addLessonsHeader;

  /// No description provided for @legacyBalanceDisplay.
  ///
  /// In ru, this message translates to:
  /// **'Остаток занятий: {count}'**
  String legacyBalanceDisplay(int count);

  /// No description provided for @lessonsQuantityFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий'**
  String get lessonsQuantityFieldLabel;

  /// No description provided for @positiveOrNegativeHint.
  ///
  /// In ru, this message translates to:
  /// **'Положительное или отрицательное число'**
  String get positiveOrNegativeHint;

  /// No description provided for @enterQuantityError.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество'**
  String get enterQuantityError;

  /// No description provided for @enterIntegerError.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число'**
  String get enterIntegerError;

  /// No description provided for @commentOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get commentOptionalLabel;

  /// No description provided for @transferFromSubscriptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Перенос с другого абонемента'**
  String get transferFromSubscriptionHint;

  /// No description provided for @saveAction.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get saveAction;

  /// No description provided for @lessonWillNotShowOnDate.
  ///
  /// In ru, this message translates to:
  /// **'Занятие не будет отображаться на {date}.\n\nЭто не создаст запись в истории занятий.'**
  String lessonWillNotShowOnDate(String date);

  /// No description provided for @lessonDeletedWithPayment.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет удалено из истории.\nОплата за занятие также будет удалена.'**
  String get lessonDeletedWithPayment;

  /// No description provided for @lessonDeletedWithReturn.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет удалено из истории.\nСписанное занятие будет возвращено на баланс ученика.'**
  String get lessonDeletedWithReturn;

  /// No description provided for @lessonDeletedCompletely.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет полностью удалено из истории.'**
  String get lessonDeletedCompletely;

  /// No description provided for @lessonPaymentDefault.
  ///
  /// In ru, this message translates to:
  /// **'Оплата занятия'**
  String get lessonPaymentDefault;

  /// No description provided for @lessonWillBeCancelledNoDeduction.
  ///
  /// In ru, this message translates to:
  /// **'Занятие будет отменено и архивировано без списания с баланса'**
  String get lessonWillBeCancelledNoDeduction;

  /// No description provided for @deductedLessonWillBeReturned.
  ///
  /// In ru, this message translates to:
  /// **'Списанное при проведении занятие будет автоматически возвращено на баланс.'**
  String get deductedLessonWillBeReturned;

  /// No description provided for @whoToDeductLesson.
  ///
  /// In ru, this message translates to:
  /// **'Кому списать занятие:'**
  String get whoToDeductLesson;

  /// No description provided for @lessonIsPartOfSeries.
  ///
  /// In ru, this message translates to:
  /// **'Это занятие является частью серии ({count} шт.)'**
  String lessonIsPartOfSeries(int count);

  /// No description provided for @deductionAppliesToTodayOnly.
  ///
  /// In ru, this message translates to:
  /// **'Списание применится только к сегодняшнему занятию'**
  String get deductionAppliesToTodayOnly;

  /// No description provided for @allSeriesLessonsWillBeArchived.
  ///
  /// In ru, this message translates to:
  /// **'Все занятия серии будут архивированы без списания'**
  String get allSeriesLessonsWillBeArchived;

  /// No description provided for @cancelLessonAction.
  ///
  /// In ru, this message translates to:
  /// **'Отменить занятие'**
  String get cancelLessonAction;

  /// No description provided for @lessonSeriesCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Серия занятий отменена'**
  String get lessonSeriesCancelled;

  /// No description provided for @lessonCancelledAndDeducted.
  ///
  /// In ru, this message translates to:
  /// **'Занятие отменено и списано с баланса'**
  String get lessonCancelledAndDeducted;

  /// No description provided for @lessonIsPartOfPermanentSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Это занятие является частью постоянного расписания'**
  String get lessonIsPartOfPermanentSchedule;

  /// No description provided for @participantsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get participantsLabel;

  /// No description provided for @paymentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get paymentLabel;

  /// No description provided for @paymentErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка оплаты: {error}'**
  String paymentErrorMessage(String error);

  /// No description provided for @removeStudentFromLessonConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Убрать {name} из этого занятия?'**
  String removeStudentFromLessonConfirm(String name);

  /// No description provided for @removeParticipantFromLesson.
  ///
  /// In ru, this message translates to:
  /// **'Убрать участника из этого занятия?'**
  String get removeParticipantFromLesson;

  /// No description provided for @allStudentsAlreadyAdded.
  ///
  /// In ru, this message translates to:
  /// **'Все ученики уже добавлены'**
  String get allStudentsAlreadyAdded;

  /// No description provided for @roomLabel2.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get roomLabel2;

  /// No description provided for @roomWithNumberLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет {number}'**
  String roomWithNumberLabel(String number);

  /// No description provided for @studentFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get studentFieldLabel;

  /// No description provided for @notSelectedOption.
  ///
  /// In ru, this message translates to:
  /// **'Не выбран'**
  String get notSelectedOption;

  /// No description provided for @repeatNone.
  ///
  /// In ru, this message translates to:
  /// **'Без повтора'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In ru, this message translates to:
  /// **'Каждый день'**
  String get repeatDaily;

  /// No description provided for @repeatWeeklyOption.
  ///
  /// In ru, this message translates to:
  /// **'Каждую неделю'**
  String get repeatWeeklyOption;

  /// No description provided for @repeatWeekdays.
  ///
  /// In ru, this message translates to:
  /// **'По дням недели'**
  String get repeatWeekdays;

  /// No description provided for @repeatCustom.
  ///
  /// In ru, this message translates to:
  /// **'Ручной выбор дат'**
  String get repeatCustom;

  /// No description provided for @editScopeThisOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только это занятие'**
  String get editScopeThisOnly;

  /// No description provided for @editScopeThisAndFollowing.
  ///
  /// In ru, this message translates to:
  /// **'Это и последующие'**
  String get editScopeThisAndFollowing;

  /// No description provided for @editScopeAll.
  ///
  /// In ru, this message translates to:
  /// **'Все занятия серии'**
  String get editScopeAll;

  /// No description provided for @editScopeSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбранные'**
  String get editScopeSelected;

  /// No description provided for @roomAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет \"{name}\" добавлен'**
  String roomAddedMessage(String name);

  /// No description provided for @roomNameOptionalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название (опционально)'**
  String get roomNameOptionalLabel;

  /// No description provided for @roomNameHintExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: Фортепианный'**
  String get roomNameHintExample;

  /// No description provided for @createRoomAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать кабинет'**
  String get createRoomAction;

  /// No description provided for @noOwnStudentsMessage.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет своих учеников'**
  String get noOwnStudentsMessage;

  /// No description provided for @showAllStudents.
  ///
  /// In ru, this message translates to:
  /// **'Показать всех ({count})'**
  String showAllStudents(int count);

  /// No description provided for @otherStudentsSection.
  ///
  /// In ru, this message translates to:
  /// **'Остальные ученики'**
  String get otherStudentsSection;

  /// No description provided for @hideAction.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть'**
  String get hideAction;

  /// No description provided for @quickAddMessage.
  ///
  /// In ru, this message translates to:
  /// **'Быстрое добавление'**
  String get quickAddMessage;

  /// No description provided for @createStudentAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать ученика'**
  String get createStudentAction;

  /// No description provided for @addSubjectForLessons.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте предмет для занятий'**
  String get addSubjectForLessons;

  /// No description provided for @createSubjectAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать предмет'**
  String get createSubjectAction;

  /// No description provided for @configureLessonParams.
  ///
  /// In ru, this message translates to:
  /// **'Настройте параметры занятия'**
  String get configureLessonParams;

  /// No description provided for @enterNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get enterNameRequired;

  /// No description provided for @minutesUnit.
  ///
  /// In ru, this message translates to:
  /// **'мин'**
  String get minutesUnit;

  /// No description provided for @createTypeAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать тип'**
  String get createTypeAction;

  /// No description provided for @teachersFilter.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get teachersFilter;

  /// No description provided for @lessonTypesFilter.
  ///
  /// In ru, this message translates to:
  /// **'Типы занятий'**
  String get lessonTypesFilter;

  /// No description provided for @directionsFilter.
  ///
  /// In ru, this message translates to:
  /// **'Направления'**
  String get directionsFilter;

  /// No description provided for @applyFiltersAction.
  ///
  /// In ru, this message translates to:
  /// **'Применить фильтры'**
  String get applyFiltersAction;

  /// No description provided for @showAllAction.
  ///
  /// In ru, this message translates to:
  /// **'Показать все'**
  String get showAllAction;

  /// No description provided for @studentsFilter.
  ///
  /// In ru, this message translates to:
  /// **'Ученики'**
  String get studentsFilter;

  /// No description provided for @deletedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Удалён'**
  String get deletedLabel;

  /// No description provided for @temporarilyShowingAll.
  ///
  /// In ru, this message translates to:
  /// **'Временно показаны все'**
  String get temporarilyShowingAll;

  /// No description provided for @allRoomsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Все кабинеты'**
  String get allRoomsLabel;

  /// No description provided for @noDataLabel.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noDataLabel;

  /// No description provided for @selectDatesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите даты'**
  String get selectDatesTitle;

  /// No description provided for @lessonSegment.
  ///
  /// In ru, this message translates to:
  /// **'Занятие'**
  String get lessonSegment;

  /// No description provided for @bookingSegment.
  ///
  /// In ru, this message translates to:
  /// **'Бронь'**
  String get bookingSegment;

  /// No description provided for @roomRequired.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет *'**
  String get roomRequired;

  /// No description provided for @noRoomsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет кабинетов'**
  String get noRoomsMessage;

  /// No description provided for @addRoomTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Добавить кабинет'**
  String get addRoomTooltip;

  /// No description provided for @roomsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты'**
  String get roomsLabel;

  /// No description provided for @roomAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Каб. {number}'**
  String roomAbbr(String number);

  /// No description provided for @studentSegment.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get studentSegment;

  /// No description provided for @groupSegment.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get groupSegment;

  /// No description provided for @selectStudentHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика'**
  String get selectStudentHint;

  /// No description provided for @noGroupsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет групп'**
  String get noGroupsMessage;

  /// No description provided for @addSubjectTooltip2.
  ///
  /// In ru, this message translates to:
  /// **'Добавить предмет'**
  String get addSubjectTooltip2;

  /// No description provided for @addLessonTypeTooltip2.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тип занятия'**
  String get addLessonTypeTooltip2;

  /// No description provided for @lessonsCountQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Количество занятий:'**
  String get lessonsCountQuestion;

  /// No description provided for @mondayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Пн'**
  String get mondayAbbr;

  /// No description provided for @tuesdayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Вт'**
  String get tuesdayAbbr;

  /// No description provided for @wednesdayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Ср'**
  String get wednesdayAbbr;

  /// No description provided for @thursdayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Чт'**
  String get thursdayAbbr;

  /// No description provided for @fridayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Пт'**
  String get fridayAbbr;

  /// No description provided for @saturdayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Сб'**
  String get saturdayAbbr;

  /// No description provided for @sundayAbbr.
  ///
  /// In ru, this message translates to:
  /// **'Вс'**
  String get sundayAbbr;

  /// No description provided for @checkingConflictsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Проверка конфликтов...'**
  String get checkingConflictsLabel;

  /// No description provided for @willCreateLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано {count} занятий'**
  String willCreateLessonsCount(int count);

  /// No description provided for @createLessonLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятие'**
  String get createLessonLabel;

  /// No description provided for @roomsBookedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты забронированы'**
  String get roomsBookedMessage;

  /// No description provided for @invalidLabel.
  ///
  /// In ru, this message translates to:
  /// **'Некорректно'**
  String get invalidLabel;

  /// No description provided for @minLessonDurationMessage.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длительность занятия — 15 минут'**
  String get minLessonDurationMessage;

  /// No description provided for @lessonsCreatedSkippedCount.
  ///
  /// In ru, this message translates to:
  /// **'Создано {created} занятий (пропущено: {skipped})'**
  String lessonsCreatedSkippedCount(int created, int skipped);

  /// No description provided for @bookedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Забронировано'**
  String get bookedLabel;

  /// No description provided for @deleteBookingAction.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бронь'**
  String get deleteBookingAction;

  /// No description provided for @selectMinOneRoom.
  ///
  /// In ru, this message translates to:
  /// **'Выберите минимум один кабинет'**
  String get selectMinOneRoom;

  /// No description provided for @descriptionHintExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: Репетиция, Мероприятие'**
  String get descriptionHintExample;

  /// No description provided for @temporaryRoomUntilMessage.
  ///
  /// In ru, this message translates to:
  /// **'Временно в кабинете {room} до {date}'**
  String temporaryRoomUntilMessage(String room, String date);

  /// No description provided for @slotWillNotWorkOnDateFull.
  ///
  /// In ru, this message translates to:
  /// **'Слот не будет действовать {date}.\n\nЭто позволит создать другое занятие в это время.'**
  String slotWillNotWorkOnDateFull(String date);

  /// No description provided for @exceptionAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Исключение добавлено'**
  String get exceptionAddedMessage;

  /// No description provided for @slotResumedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот возобновлён'**
  String get slotResumedMessage;

  /// No description provided for @slotDeactivateConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Слот будет полностью отключён и не будет отображаться в расписании.\n\nВы сможете активировать его снова в карточке ученика.'**
  String get slotDeactivateConfirm;

  /// No description provided for @slotDeactivatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот деактивирован'**
  String get slotDeactivatedMessage;

  /// No description provided for @studentNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ученик: {name}'**
  String studentNameLabel(String name);

  /// No description provided for @willBeCreatedCount.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано: {count} занятий'**
  String willBeCreatedCount(int count);

  /// No description provided for @createdLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} занятий'**
  String createdLessonsCount(int count);

  /// No description provided for @applyChangesAction.
  ///
  /// In ru, this message translates to:
  /// **'Применить изменения'**
  String get applyChangesAction;

  /// No description provided for @changeScopeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Область изменений'**
  String get changeScopeLabel;

  /// No description provided for @seriesLessonsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Занятия серии ({count})'**
  String seriesLessonsTitle(int count);

  /// No description provided for @selectedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count}'**
  String selectedLabel(int count);

  /// No description provided for @changesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Изменения'**
  String get changesLabel;

  /// No description provided for @updatedLessonsSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {updated} занятий (пропущено: {skipped})'**
  String updatedLessonsSkipped(int updated, int skipped);

  /// No description provided for @updatedLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {count} занятий'**
  String updatedLessonsCount(int count);

  /// No description provided for @allRoomsDisplayed.
  ///
  /// In ru, this message translates to:
  /// **'Отображаются все кабинеты'**
  String get allRoomsDisplayed;

  /// No description provided for @selectedRoomsCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано кабинетов: {count}'**
  String selectedRoomsCount(int count);

  /// No description provided for @defaultRoomsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты по умолчанию'**
  String get defaultRoomsLabel;

  /// No description provided for @roomSetupFirstTimeHint.
  ///
  /// In ru, this message translates to:
  /// **'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.'**
  String get roomSetupFirstTimeHint;

  /// No description provided for @roomSetupHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.'**
  String get roomSetupHint;

  /// No description provided for @selectRoomsAction.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты'**
  String get selectRoomsAction;

  /// No description provided for @saveCountAction.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить ({count})'**
  String saveCountAction(int count);

  /// No description provided for @virtualLessonLabel.
  ///
  /// In ru, this message translates to:
  /// **'Виртуальное занятие'**
  String get virtualLessonLabel;

  /// No description provided for @lessonWillNotShowMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие не будет отображаться на {date}.\n\nЭто не создаст запись в истории занятий.'**
  String lessonWillNotShowMessage(String date);

  /// No description provided for @schedulePausedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание приостановлено'**
  String get schedulePausedMessage;

  /// No description provided for @scheduleResumedSuccessMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание возобновлено'**
  String get scheduleResumedSuccessMessage;

  /// No description provided for @scheduleDeactivatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Расписание деактивировано'**
  String get scheduleDeactivatedMessage;

  /// No description provided for @conflictsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Конфликты: {count}'**
  String conflictsLabel(int count);

  /// No description provided for @willBeChangedCount.
  ///
  /// In ru, this message translates to:
  /// **'Будет изменено: {count} занятий'**
  String willBeChangedCount(int count);

  /// No description provided for @conflictsWillBeSkippedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Конфликты: {count} (будут пропущены)'**
  String conflictsWillBeSkippedLabel(int count);

  /// No description provided for @errorFormat.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String errorFormat(String error);

  /// No description provided for @theseDatesWillBeSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Эти даты будут пропущены:'**
  String get theseDatesWillBeSkipped;

  /// No description provided for @andMore.
  ///
  /// In ru, this message translates to:
  /// **'...и ещё {count}'**
  String andMore(int count);

  /// No description provided for @enabledForAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Включено для администратора'**
  String get enabledForAdmin;

  /// No description provided for @teacherSubjectsLabel.
  ///
  /// In ru, this message translates to:
  /// **'НАПРАВЛЕНИЯ'**
  String get teacherSubjectsLabel;

  /// No description provided for @teacherSubjectsHint.
  ///
  /// In ru, this message translates to:
  /// **'Предметы, которые ведёт преподаватель'**
  String get teacherSubjectsHint;

  /// No description provided for @noDirectionsHint.
  ///
  /// In ru, this message translates to:
  /// **'Направления не указаны.\nДобавьте предметы, которые ведёт преподаватель.'**
  String get noDirectionsHint;

  /// No description provided for @unknownSubject.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный'**
  String get unknownSubject;

  /// No description provided for @addDirectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить направление'**
  String get addDirectionTitle;

  /// No description provided for @selectSubjectFor.
  ///
  /// In ru, this message translates to:
  /// **'Выберите предмет для {name}'**
  String selectSubjectFor(String name);

  /// No description provided for @directionAdded.
  ///
  /// In ru, this message translates to:
  /// **'Направление \"{name}\" добавлено'**
  String directionAdded(String name);

  /// No description provided for @addSubjectDescription.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте предмет для занятий'**
  String get addSubjectDescription;

  /// No description provided for @subjectNameField.
  ///
  /// In ru, this message translates to:
  /// **'Название предмета'**
  String get subjectNameField;

  /// No description provided for @nameField.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get nameField;

  /// No description provided for @minSuffix.
  ///
  /// In ru, this message translates to:
  /// **'мин'**
  String get minSuffix;

  /// No description provided for @priceOptional.
  ///
  /// In ru, this message translates to:
  /// **'Цена (необязательно)'**
  String get priceOptional;

  /// No description provided for @showAll.
  ///
  /// In ru, this message translates to:
  /// **'Показать все'**
  String get showAll;

  /// No description provided for @deleted.
  ///
  /// In ru, this message translates to:
  /// **'Удалён'**
  String get deleted;

  /// No description provided for @studentAddedAsGuest.
  ///
  /// In ru, this message translates to:
  /// **'{name} добавлен как гость'**
  String studentAddedAsGuest(String name);

  /// No description provided for @roomWithNumberDefault.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет {number}'**
  String roomWithNumberDefault(String number);

  /// No description provided for @showAllStudentsCount.
  ///
  /// In ru, this message translates to:
  /// **'Показать всех ({count})'**
  String showAllStudentsCount(int count);

  /// No description provided for @otherStudentsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Остальные ученики'**
  String get otherStudentsLabel;

  /// No description provided for @studentNameAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ученик \"{name}\" добавлен'**
  String studentNameAddedMessage(String name);

  /// No description provided for @subjectNameAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Предмет \"{name}\" добавлен'**
  String subjectNameAddedMessage(String name);

  /// No description provided for @lessonTypeNameAddedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия \"{name}\" добавлен'**
  String lessonTypeNameAddedMessage(String name);

  /// No description provided for @durationMinutesLabel.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String durationMinutesLabel(int minutes);

  /// No description provided for @lessonTypeDurationFormat.
  ///
  /// In ru, this message translates to:
  /// **'{name} ({duration} мин)'**
  String lessonTypeDurationFormat(String name, int duration);

  /// No description provided for @groupMembersCount.
  ///
  /// In ru, this message translates to:
  /// **'{name} ({count} уч.)'**
  String groupMembersCount(String name, int count);

  /// No description provided for @roomSetupFirstTimeDescription.
  ///
  /// In ru, this message translates to:
  /// **'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.'**
  String get roomSetupFirstTimeDescription;

  /// No description provided for @roomSetupDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.'**
  String get roomSetupDescription;

  /// No description provided for @saveWithCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить ({count})'**
  String saveWithCountLabel(int count);

  /// No description provided for @allRoomsDisplayedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Отображаются все кабинеты'**
  String get allRoomsDisplayedMessage;

  /// No description provided for @selectedRoomsCountMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано кабинетов: {count}'**
  String selectedRoomsCountMessage(int count);

  /// No description provided for @temporarilyShowingAllRooms.
  ///
  /// In ru, this message translates to:
  /// **'Временно показаны все'**
  String get temporarilyShowingAllRooms;

  /// No description provided for @notConfiguredRooms.
  ///
  /// In ru, this message translates to:
  /// **'Не настроено'**
  String get notConfiguredRooms;

  /// No description provided for @allRoomsDefault.
  ///
  /// In ru, this message translates to:
  /// **'Все кабинеты'**
  String get allRoomsDefault;

  /// No description provided for @noDataAvailableMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noDataAvailableMessage;

  /// No description provided for @januaryMonth.
  ///
  /// In ru, this message translates to:
  /// **'Январь'**
  String get januaryMonth;

  /// No description provided for @februaryMonth.
  ///
  /// In ru, this message translates to:
  /// **'Февраль'**
  String get februaryMonth;

  /// No description provided for @marchMonth.
  ///
  /// In ru, this message translates to:
  /// **'Март'**
  String get marchMonth;

  /// No description provided for @aprilMonth.
  ///
  /// In ru, this message translates to:
  /// **'Апрель'**
  String get aprilMonth;

  /// No description provided for @mayMonth.
  ///
  /// In ru, this message translates to:
  /// **'Май'**
  String get mayMonth;

  /// No description provided for @juneMonth.
  ///
  /// In ru, this message translates to:
  /// **'Июнь'**
  String get juneMonth;

  /// No description provided for @julyMonth.
  ///
  /// In ru, this message translates to:
  /// **'Июль'**
  String get julyMonth;

  /// No description provided for @augustMonth.
  ///
  /// In ru, this message translates to:
  /// **'Август'**
  String get augustMonth;

  /// No description provided for @septemberMonth.
  ///
  /// In ru, this message translates to:
  /// **'Сентябрь'**
  String get septemberMonth;

  /// No description provided for @octoberMonth.
  ///
  /// In ru, this message translates to:
  /// **'Октябрь'**
  String get octoberMonth;

  /// No description provided for @novemberMonth.
  ///
  /// In ru, this message translates to:
  /// **'Ноябрь'**
  String get novemberMonth;

  /// No description provided for @decemberMonth.
  ///
  /// In ru, this message translates to:
  /// **'Декабрь'**
  String get decemberMonth;

  /// No description provided for @selectDatesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выберите даты'**
  String get selectDatesLabel;

  /// No description provided for @lessonTabLabel.
  ///
  /// In ru, this message translates to:
  /// **'Занятие'**
  String get lessonTabLabel;

  /// No description provided for @bookingTabLabel.
  ///
  /// In ru, this message translates to:
  /// **'Бронь'**
  String get bookingTabLabel;

  /// No description provided for @noRoomsAvailableMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет кабинетов'**
  String get noRoomsAvailableMessage;

  /// No description provided for @roomAbbreviation.
  ///
  /// In ru, this message translates to:
  /// **'Каб. {number}'**
  String roomAbbreviation(String number);

  /// No description provided for @descriptionOptionalField.
  ///
  /// In ru, this message translates to:
  /// **'Описание (необязательно)'**
  String get descriptionOptionalField;

  /// No description provided for @eventMeetingHint.
  ///
  /// In ru, this message translates to:
  /// **'Мероприятие, встреча и т.д.'**
  String get eventMeetingHint;

  /// No description provided for @studentTabLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get studentTabLabel;

  /// No description provided for @groupTabLabel.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get groupTabLabel;

  /// No description provided for @noStudentsAvailableMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет учеников'**
  String get noStudentsAvailableMessage;

  /// No description provided for @selectStudentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ученика'**
  String get selectStudentLabel;

  /// No description provided for @noGroupsAvailableMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет групп'**
  String get noGroupsAvailableMessage;

  /// No description provided for @lessonTimeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Время занятий'**
  String get lessonTimeTitle;

  /// No description provided for @selectDatesInCalendarLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать даты в календаре'**
  String get selectDatesInCalendarLabel;

  /// No description provided for @selectedDatesCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count} дат'**
  String selectedDatesCountLabel(int count);

  /// No description provided for @checkingConflictsProgress.
  ///
  /// In ru, this message translates to:
  /// **'Проверка конфликтов...'**
  String get checkingConflictsProgress;

  /// No description provided for @willCreateLessonsCountMessage.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано {count} занятий'**
  String willCreateLessonsCountMessage(int count);

  /// No description provided for @conflictsWillBeSkippedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Конфликты: {count} (будут пропущены)'**
  String conflictsWillBeSkippedMessage(int count);

  /// No description provided for @createSchedulesCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать {count} расписаний'**
  String createSchedulesCountLabel(int count);

  /// No description provided for @createScheduleActionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать расписание'**
  String get createScheduleActionLabel;

  /// No description provided for @createLessonsCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать {count} занятий'**
  String createLessonsCountLabel(int count);

  /// No description provided for @createLessonActionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятие'**
  String get createLessonActionLabel;

  /// No description provided for @minBookingDurationError.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длительность брони — 15 минут'**
  String get minBookingDurationError;

  /// No description provided for @roomsBookedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Кабинеты забронированы'**
  String get roomsBookedSuccess;

  /// No description provided for @durationHoursMinutesFormat.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String durationHoursMinutesFormat(int hours, int minutes);

  /// No description provided for @durationHoursOnlyFormat.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String durationHoursOnlyFormat(int hours);

  /// No description provided for @durationMinutesOnlyFormat.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String durationMinutesOnlyFormat(int minutes);

  /// No description provided for @invalidTimeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Некорректно'**
  String get invalidTimeLabel;

  /// No description provided for @dayStartTimeHelpText.
  ///
  /// In ru, this message translates to:
  /// **'{day}: Начало занятия'**
  String dayStartTimeHelpText(String day);

  /// No description provided for @dayEndTimeHelpText.
  ///
  /// In ru, this message translates to:
  /// **'{day}: Конец занятия'**
  String dayEndTimeHelpText(String day);

  /// No description provided for @minLessonDurationError.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длительность занятия — 15 минут'**
  String get minLessonDurationError;

  /// No description provided for @permanentSchedulesCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} постоянных расписаний'**
  String permanentSchedulesCreatedMessage(int count);

  /// No description provided for @permanentScheduleCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Постоянное расписание создано'**
  String get permanentScheduleCreatedMessage;

  /// No description provided for @allDatesOccupiedError.
  ///
  /// In ru, this message translates to:
  /// **'Все даты заняты'**
  String get allDatesOccupiedError;

  /// No description provided for @lessonsCreatedSkippedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Создано {created} занятий (пропущено: {skipped})'**
  String lessonsCreatedSkippedMessage(int created, int skipped);

  /// No description provided for @lessonsCreatedSuccessMessage.
  ///
  /// In ru, this message translates to:
  /// **'Создано {count} занятий'**
  String lessonsCreatedSuccessMessage(int count);

  /// No description provided for @groupLessonCreatedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Групповое занятие создано'**
  String get groupLessonCreatedMessage;

  /// No description provided for @lessonCreatedSuccessMessage.
  ///
  /// In ru, this message translates to:
  /// **'Занятие создано'**
  String get lessonCreatedSuccessMessage;

  /// No description provided for @enterGroupName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get enterGroupName;

  /// No description provided for @unknownUserLabel.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестный пользователь'**
  String get unknownUserLabel;

  /// No description provided for @deletingProgress.
  ///
  /// In ru, this message translates to:
  /// **'Удаление...'**
  String get deletingProgress;

  /// No description provided for @deleteBookingActionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Удалить бронь'**
  String get deleteBookingActionLabel;

  /// No description provided for @bookingWillBeDeletedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Бронирование будет удалено и кабинеты освободятся.'**
  String get bookingWillBeDeletedMessage;

  /// No description provided for @bookingDeletedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Бронь удалена'**
  String get bookingDeletedSuccess;

  /// No description provided for @deletionErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при удалении'**
  String get deletionErrorMessage;

  /// No description provided for @bookRoomsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать кабинеты'**
  String get bookRoomsLabel;

  /// No description provided for @selectMinOneRoomMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите минимум один кабинет'**
  String get selectMinOneRoomMessage;

  /// No description provided for @bookingErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка бронирования'**
  String get bookingErrorMessage;

  /// No description provided for @slotExceptionMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот не будет действовать {date}.\n\nЭто позволит создать другое занятие в это время.'**
  String slotExceptionMessage(String date);

  /// No description provided for @exceptionAddedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Исключение добавлено'**
  String get exceptionAddedSuccess;

  /// No description provided for @pauseUntilHelpText.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить до'**
  String get pauseUntilHelpText;

  /// No description provided for @slotPausedUntilMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот приостановлен до {date}'**
  String slotPausedUntilMessage(String date);

  /// No description provided for @slotResumedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Слот возобновлён'**
  String get slotResumedSuccess;

  /// No description provided for @slotDeactivateMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот будет полностью отключён и не будет отображаться в расписании.\n\nВы сможете активировать его снова в карточке ученика.'**
  String get slotDeactivateMessage;

  /// No description provided for @slotDeactivatedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Слот деактивирован'**
  String get slotDeactivatedSuccess;

  /// No description provided for @studentLabelWithName.
  ///
  /// In ru, this message translates to:
  /// **'Ученик: {name}'**
  String studentLabelWithName(String name);

  /// No description provided for @toDateLabelSchedule.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get toDateLabelSchedule;

  /// No description provided for @willBeCreatedCountMessage.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано: {count} занятий'**
  String willBeCreatedCountMessage(int count);

  /// No description provided for @creatingProgress.
  ///
  /// In ru, this message translates to:
  /// **'Создание...'**
  String get creatingProgress;

  /// No description provided for @createLessonsActionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия'**
  String get createLessonsActionLabel;

  /// No description provided for @noDatesToCreateError.
  ///
  /// In ru, this message translates to:
  /// **'Нет дат для создания'**
  String get noDatesToCreateError;

  /// No description provided for @roomNotSpecifiedError.
  ///
  /// In ru, this message translates to:
  /// **'Не указан кабинет'**
  String get roomNotSpecifiedError;

  /// No description provided for @editSeriesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать серию'**
  String get editSeriesLabel;

  /// No description provided for @savingProgress.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение...'**
  String get savingProgress;

  /// No description provided for @byWeekdaysFilterLabel.
  ///
  /// In ru, this message translates to:
  /// **'По дням недели'**
  String get byWeekdaysFilterLabel;

  /// No description provided for @allLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get allLessonsLabel;

  /// No description provided for @seriesLessonsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Занятия серии ({count})'**
  String seriesLessonsLabel(int count);

  /// No description provided for @selectedCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count}'**
  String selectedCountLabel(int count);

  /// No description provided for @timeChangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get timeChangeLabel;

  /// No description provided for @roomChangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get roomChangeLabel;

  /// No description provided for @studentChangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ученик'**
  String get studentChangeLabel;

  /// No description provided for @subjectChangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Предмет'**
  String get subjectChangeLabel;

  /// No description provided for @lessonTypeChangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип занятия'**
  String get lessonTypeChangeLabel;

  /// No description provided for @currentValueLabel.
  ///
  /// In ru, this message translates to:
  /// **'текущий'**
  String get currentValueLabel;

  /// No description provided for @willBeChangedCountMessage.
  ///
  /// In ru, this message translates to:
  /// **'Будет изменено: {count} занятий'**
  String willBeChangedCountMessage(int count);

  /// No description provided for @noLessonsToUpdateError.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий для обновления (все имеют конфликты)'**
  String get noLessonsToUpdateError;

  /// No description provided for @updatedLessonsSkippedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {updated} занятий (пропущено: {skipped})'**
  String updatedLessonsSkippedMessage(int updated, int skipped);

  /// No description provided for @updatedLessonsSuccessMessage.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {count} занятий'**
  String updatedLessonsSuccessMessage(int count);

  /// No description provided for @lessonSchedulePaused.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено до {date}'**
  String lessonSchedulePaused(String date);

  /// No description provided for @lessonScheduleIndefinitePause.
  ///
  /// In ru, this message translates to:
  /// **'Бессрочная пауза'**
  String get lessonScheduleIndefinitePause;

  /// No description provided for @temporaryRoomReplacementInfo.
  ///
  /// In ru, this message translates to:
  /// **'Временно в кабинете {room} до {date}'**
  String temporaryRoomReplacementInfo(String room, String date);

  /// No description provided for @createLessonOnDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятие на {date}'**
  String createLessonOnDateLabel(String date);

  /// No description provided for @completeLessonOnDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Провести занятие на {date}'**
  String completeLessonOnDateLabel(String date);

  /// No description provided for @cancelLessonOnDateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить занятие на {date}'**
  String cancelLessonOnDateLabel(String date);

  /// No description provided for @lessonCompletedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Занятие проведено'**
  String get lessonCompletedSuccess;

  /// No description provided for @dateSkippedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Дата пропущена'**
  String get dateSkippedSuccess;

  /// No description provided for @schedulePausedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Расписание приостановлено'**
  String get schedulePausedSuccess;

  /// No description provided for @scheduleResumedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Расписание возобновлено'**
  String get scheduleResumedSuccess;

  /// No description provided for @scheduleDeactivatedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Расписание деактивировано'**
  String get scheduleDeactivatedSuccess;

  /// No description provided for @january.
  ///
  /// In ru, this message translates to:
  /// **'Январь'**
  String get january;

  /// No description provided for @february.
  ///
  /// In ru, this message translates to:
  /// **'Февраль'**
  String get february;

  /// No description provided for @march.
  ///
  /// In ru, this message translates to:
  /// **'Март'**
  String get march;

  /// No description provided for @april.
  ///
  /// In ru, this message translates to:
  /// **'Апрель'**
  String get april;

  /// No description provided for @may.
  ///
  /// In ru, this message translates to:
  /// **'Май'**
  String get may;

  /// No description provided for @june.
  ///
  /// In ru, this message translates to:
  /// **'Июнь'**
  String get june;

  /// No description provided for @july.
  ///
  /// In ru, this message translates to:
  /// **'Июль'**
  String get july;

  /// No description provided for @august.
  ///
  /// In ru, this message translates to:
  /// **'Август'**
  String get august;

  /// No description provided for @september.
  ///
  /// In ru, this message translates to:
  /// **'Сентябрь'**
  String get september;

  /// No description provided for @october.
  ///
  /// In ru, this message translates to:
  /// **'Октябрь'**
  String get october;

  /// No description provided for @november.
  ///
  /// In ru, this message translates to:
  /// **'Ноябрь'**
  String get november;

  /// No description provided for @december.
  ///
  /// In ru, this message translates to:
  /// **'Декабрь'**
  String get december;

  /// No description provided for @changes.
  ///
  /// In ru, this message translates to:
  /// **'Изменения'**
  String get changes;

  /// No description provided for @editSeries.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать серию'**
  String get editSeries;

  /// No description provided for @saving.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение...'**
  String get saving;

  /// No description provided for @applyChanges.
  ///
  /// In ru, this message translates to:
  /// **'Применить изменения'**
  String get applyChanges;

  /// No description provided for @byDaysOfWeek.
  ///
  /// In ru, this message translates to:
  /// **'По дням недели'**
  String get byDaysOfWeek;

  /// No description provided for @current.
  ///
  /// In ru, this message translates to:
  /// **'текущий'**
  String get current;

  /// No description provided for @seriesLessonsCount.
  ///
  /// In ru, this message translates to:
  /// **'Занятия серии ({count})'**
  String seriesLessonsCount(int count);

  /// No description provided for @willBeChangedLessons.
  ///
  /// In ru, this message translates to:
  /// **'Будет изменено: {count} занятий'**
  String willBeChangedLessons(int count);

  /// No description provided for @creating.
  ///
  /// In ru, this message translates to:
  /// **'Создание...'**
  String get creating;

  /// No description provided for @createLessonsButton.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятия'**
  String get createLessonsButton;

  /// No description provided for @willBeCreatedLessons.
  ///
  /// In ru, this message translates to:
  /// **'Будет создано: {count} занятий'**
  String willBeCreatedLessons(int count);

  /// No description provided for @fromDate.
  ///
  /// In ru, this message translates to:
  /// **'С даты'**
  String get fromDate;

  /// No description provided for @toDate.
  ///
  /// In ru, this message translates to:
  /// **'По дату'**
  String get toDate;

  /// No description provided for @bookRooms.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать кабинеты'**
  String get bookRooms;

  /// No description provided for @selectRooms.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты'**
  String get selectRooms;

  /// No description provided for @selectAtLeastOneRoomValidation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите минимум один кабинет'**
  String get selectAtLeastOneRoomValidation;

  /// No description provided for @createLessonOn.
  ///
  /// In ru, this message translates to:
  /// **'Создать занятие на {date}'**
  String createLessonOn(String date);

  /// No description provided for @exceptionMessage.
  ///
  /// In ru, this message translates to:
  /// **'Слот не будет действовать {date}.\n\nЭто позволит создать другое занятие в это время.'**
  String exceptionMessage(String date);

  /// No description provided for @temporaryRoomMessage.
  ///
  /// In ru, this message translates to:
  /// **'Временно в кабинете {room} до {date}'**
  String temporaryRoomMessage(String room, String date);

  /// No description provided for @deleting.
  ///
  /// In ru, this message translates to:
  /// **'Удаление...'**
  String get deleting;

  /// No description provided for @deleteError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при удалении'**
  String get deleteError;

  /// No description provided for @roomSetupDefaultDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.'**
  String get roomSetupDefaultDescription;

  /// No description provided for @selectRoomsPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинеты'**
  String get selectRoomsPlaceholder;

  /// No description provided for @completeLessonOn.
  ///
  /// In ru, this message translates to:
  /// **'Провести занятие на {date}'**
  String completeLessonOn(String date);

  /// No description provided for @cancelLessonOn.
  ///
  /// In ru, this message translates to:
  /// **'Отменить занятие на {date}'**
  String cancelLessonOn(String date);

  /// No description provided for @paymentLessonsWithDate.
  ///
  /// In ru, this message translates to:
  /// **'{count} занятий • {date}'**
  String paymentLessonsWithDate(int count, String date);

  /// No description provided for @subscriptionLessonsProgress.
  ///
  /// In ru, this message translates to:
  /// **'{remaining} / {total} занятий'**
  String subscriptionLessonsProgress(int remaining, int total);

  /// No description provided for @daysRemainingShort.
  ///
  /// In ru, this message translates to:
  /// **'({days} дн.)'**
  String daysRemainingShort(int days);
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
