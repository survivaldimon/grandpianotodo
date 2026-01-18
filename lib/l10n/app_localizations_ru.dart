// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Kabinet';

  @override
  String get loading => 'Загрузка...';

  @override
  String get error => 'Ошибка';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get archive => 'Архивировать';

  @override
  String get restore => 'Восстановить';

  @override
  String get edit => 'Редактировать';

  @override
  String get add => 'Добавить';

  @override
  String get create => 'Создать';

  @override
  String get search => 'Поиск';

  @override
  String get noData => 'Нет данных';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get close => 'Закрыть';

  @override
  String get done => 'Готово';

  @override
  String get next => 'Далее';

  @override
  String get back => 'Назад';

  @override
  String get apply => 'Применить';

  @override
  String get reset => 'Сбросить';

  @override
  String get all => 'Все';

  @override
  String get select => 'Выбрать';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get share => 'Поделиться';

  @override
  String get more => 'Ещё';

  @override
  String get less => 'Меньше';

  @override
  String get show => 'Показать';

  @override
  String get hide => 'Скрыть';

  @override
  String get optional => 'Необязательно';

  @override
  String get required => 'Обязательно';

  @override
  String get or => 'или';

  @override
  String get and => 'и';

  @override
  String get from => 'от';

  @override
  String get to => 'до';

  @override
  String get tenge => 'тг';

  @override
  String get login => 'Войти';

  @override
  String get register => 'Зарегистрироваться';

  @override
  String get logout => 'Выйти';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get fullName => 'Полное имя';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get resetPassword => 'Восстановить пароль';

  @override
  String get resetPasswordTitle => 'Восстановление пароля';

  @override
  String get resetPasswordMessage =>
      'Введите email, указанный при регистрации. Мы отправим вам ссылку для сброса пароля.';

  @override
  String get resetPasswordSuccess => 'Письмо отправлено! Проверьте свою почту.';

  @override
  String get noAccount => 'Нет аккаунта?';

  @override
  String get hasAccount => 'Уже есть аккаунт?';

  @override
  String get loginWithGoogle => 'Войти через Google';

  @override
  String get loginWithApple => 'Войти через Apple';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get setNewPassword => 'Задать новый пароль';

  @override
  String get setNewPasswordDescription => 'Установите новый пароль';

  @override
  String get savePassword => 'Сохранить пароль';

  @override
  String passwordChangeError(String error) {
    return 'Ошибка смены пароля: $error';
  }

  @override
  String get passwordChanged => 'Пароль успешно изменён';

  @override
  String get registrationSuccess => 'Регистрация успешна!';

  @override
  String get passwordRequirements =>
      'Мин. 8 символов, заглавная буква, спецсимвол';

  @override
  String get institutions => 'Заведения';

  @override
  String get createInstitution => 'Создать заведение';

  @override
  String get joinInstitution => 'Присоединиться';

  @override
  String get institutionName => 'Название заведения';

  @override
  String get inviteCode => 'Код приглашения';

  @override
  String get institutionNameHint => 'Например: Музыкальная школа №1';

  @override
  String get inviteCodeHint => 'Например: ABC12345';

  @override
  String get inviteCodeDescription =>
      'Введите код приглашения, который вам прислал администратор заведения';

  @override
  String joinedInstitution(String name) {
    return 'Вы присоединились к \"$name\"';
  }

  @override
  String get owner => 'Владелец';

  @override
  String get member => 'Участник';

  @override
  String get admin => 'Администратор';

  @override
  String get teacher => 'Преподаватель';

  @override
  String get noInstitutions => 'Нет заведений';

  @override
  String get createOrJoin => 'Создайте новое или присоединитесь';

  @override
  String get dashboard => 'Главная';

  @override
  String get rooms => 'Кабинеты';

  @override
  String get students => 'Ученики';

  @override
  String get payments => 'Оплаты';

  @override
  String get settings => 'Настройки';

  @override
  String get statistics => 'Статистика';

  @override
  String get groups => 'Группы';

  @override
  String get schedule => 'Расписание';

  @override
  String get room => 'Кабинет';

  @override
  String get roomName => 'Название кабинета';

  @override
  String get roomNumber => 'Номер кабинета';

  @override
  String get addRoom => 'Добавить кабинет';

  @override
  String get editRoom => 'Редактировать кабинет';

  @override
  String get deleteRoom => 'Удалить кабинет';

  @override
  String get noRooms => 'Нет кабинетов';

  @override
  String get addRoomFirst => 'Сначала добавьте кабинет';

  @override
  String get roomDeleted => 'Кабинет удалён';

  @override
  String get roomUpdated => 'Кабинет обновлён';

  @override
  String get roomCreated => 'Кабинет создан';

  @override
  String get roomColor => 'Цвет кабинета';

  @override
  String get roomOccupied => 'Кабинет занят в это время';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get tomorrow => 'Завтра';

  @override
  String get lesson => 'Занятие';

  @override
  String get lessons => 'Занятия';

  @override
  String get newLesson => 'Новое занятие';

  @override
  String get editLesson => 'Редактировать занятие';

  @override
  String get deleteLesson => 'Удалить занятие';

  @override
  String get lessonType => 'Тип занятия';

  @override
  String get subject => 'Предмет';

  @override
  String get date => 'Дата';

  @override
  String get time => 'Время';

  @override
  String get startTime => 'Начало';

  @override
  String get endTime => 'Окончание';

  @override
  String get duration => 'Длительность';

  @override
  String get minutes => 'мин';

  @override
  String get comment => 'Комментарий';

  @override
  String get noLessons => 'Нет занятий';

  @override
  String get noLessonsToday => 'Нет занятий сегодня';

  @override
  String get lessonsToday => 'Занятия сегодня';

  @override
  String get nextLesson => 'Ближайшее занятие';

  @override
  String get selectDate => 'Выберите дату';

  @override
  String get selectTime => 'Выберите время';

  @override
  String get selectRoom => 'Выберите кабинет';

  @override
  String get selectStudent => 'Выберите ученика';

  @override
  String get selectSubject => 'Выберите предмет';

  @override
  String get selectTeacher => 'Выберите преподавателя';

  @override
  String get selectLessonType => 'Выберите тип занятия';

  @override
  String get repeatLesson => 'Повторять занятие';

  @override
  String get repeatWeekly => 'Каждую неделю';

  @override
  String get repeatCount => 'Количество повторений';

  @override
  String get quickAdd => 'Быстрое добавление';

  @override
  String get scheduled => 'Запланировано';

  @override
  String get completed => 'Проведено';

  @override
  String get cancelled => 'Отменено';

  @override
  String get rescheduled => 'Перенесено';

  @override
  String get markCompleted => 'Отметить проведённым';

  @override
  String get markCancelled => 'Отменить занятие';

  @override
  String get unmarkedLessons => 'Неотмеченные занятия';

  @override
  String get noUnmarkedLessons => 'Нет неотмеченных занятий';

  @override
  String get lessonCompleted => 'Занятие проведено';

  @override
  String get lessonCancelled => 'Занятие отменено';

  @override
  String get lessonDeleted => 'Занятие удалено';

  @override
  String get lessonCreated => 'Занятие создано';

  @override
  String get lessonUpdated => 'Занятие обновлено';

  @override
  String get student => 'Ученик';

  @override
  String get studentName => 'Имя ученика';

  @override
  String get phone => 'Телефон';

  @override
  String get addStudent => 'Добавить ученика';

  @override
  String get editStudent => 'Редактировать ученика';

  @override
  String get deleteStudent => 'Удалить ученика';

  @override
  String get archiveStudent => 'Архивировать ученика';

  @override
  String get unarchiveStudent => 'Разархивировать';

  @override
  String get prepaidLessons => 'Предоплаченных занятий';

  @override
  String get debt => 'Долг';

  @override
  String get individualLesson => 'Индивидуальное';

  @override
  String get groupLesson => 'Групповое';

  @override
  String get noStudents => 'Нет учеников';

  @override
  String get addStudentFirst => 'Добавьте первого ученика';

  @override
  String get studentDeleted => 'Ученик удалён';

  @override
  String get studentArchived => 'Ученик архивирован';

  @override
  String get studentUnarchived => 'Ученик разархивирован';

  @override
  String get studentUpdated => 'Ученик обновлён';

  @override
  String get studentCreated => 'Ученик добавлен';

  @override
  String get showArchived => 'Показать архив';

  @override
  String get hideArchived => 'Скрыть архив';

  @override
  String get mergeStudents => 'Объединить учеников';

  @override
  String get mergeWith => 'Объединить с...';

  @override
  String get parentName => 'Имя родителя';

  @override
  String get parentPhone => 'Телефон родителя';

  @override
  String get notes => 'Заметки';

  @override
  String get debtors => 'Должники';

  @override
  String get noDebtors => 'Должников нет';

  @override
  String get group => 'Группа';

  @override
  String get groupName => 'Название группы';

  @override
  String get addGroup => 'Добавить группу';

  @override
  String get editGroup => 'Редактировать группу';

  @override
  String get deleteGroup => 'Удалить группу';

  @override
  String get archiveGroup => 'Архивировать группу';

  @override
  String get members => 'Участники';

  @override
  String get addMember => 'Добавить участника';

  @override
  String get noGroups => 'Нет групп';

  @override
  String get groupDeleted => 'Группа удалена';

  @override
  String get groupArchived => 'Группа архивирована';

  @override
  String get groupUpdated => 'Группа обновлена';

  @override
  String get groupCreated => 'Группа создана';

  @override
  String get selectStudents => 'Выберите учеников';

  @override
  String get minTwoStudents => 'Выберите минимум 2 ученика';

  @override
  String get participants => 'Участники';

  @override
  String participantsCount(int count) {
    return 'УЧАСТНИКИ ($count)';
  }

  @override
  String get addParticipants => 'Добавить участников';

  @override
  String get selectStudentsForGroup => 'Выберите учеников для группы';

  @override
  String get searchStudent => 'Поиск ученика...';

  @override
  String get createNewStudent => 'Создать нового ученика';

  @override
  String get allStudentsInGroup => 'Все ученики уже в группе';

  @override
  String get noAvailableStudents => 'Нет доступных учеников';

  @override
  String get resetSearch => 'Сбросить поиск';

  @override
  String balanceColon(int count) {
    return 'Баланс: $count';
  }

  @override
  String get removeFromGroup => 'Удалить из группы';

  @override
  String get removeStudentFromGroupQuestion => 'Удалить из группы?';

  @override
  String removeStudentFromGroupMessage(String name) {
    return 'Удалить $name из группы?';
  }

  @override
  String get studentAddedToGroup => 'Ученик добавлен в группу';

  @override
  String studentsAddedCount(int count) {
    return 'Добавлено учеников: $count';
  }

  @override
  String get newStudent => 'Новый ученик';

  @override
  String studentCreatedAndSelected(String name) {
    return 'Ученик \"$name\" создан и выбран';
  }

  @override
  String get archiveGroupConfirmation => 'Архивировать группу?';

  @override
  String archiveGroupMessage(String name) {
    return 'Группа \"$name\" будет перемещена в архив. Вы сможете восстановить её позже.';
  }

  @override
  String get noParticipants => 'Нет участников';

  @override
  String get addStudentsToGroup => 'Добавьте учеников в группу';

  @override
  String get createFirstGroup => 'Создайте первую группу учеников';

  @override
  String get createGroup => 'Создать группу';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String lessonsCountLabel(int count) {
    return 'Количество занятий:';
  }

  @override
  String selectedColon(int count) {
    return 'Выбрано: $count';
  }

  @override
  String addCount(int count) {
    return 'Добавить ($count)';
  }

  @override
  String get payment => 'Оплата';

  @override
  String get addPayment => 'Добавить оплату';

  @override
  String get editPayment => 'Редактировать оплату';

  @override
  String get deletePayment => 'Удалить оплату';

  @override
  String get amount => 'Сумма';

  @override
  String get lessonsCount => 'Количество занятий';

  @override
  String get paymentPlan => 'Тариф';

  @override
  String get paidAt => 'Дата оплаты';

  @override
  String get correction => 'Корректировка';

  @override
  String get correctionReason => 'Причина корректировки';

  @override
  String get noPayments => 'Нет оплат';

  @override
  String get paymentDeleted => 'Оплата удалена';

  @override
  String get paymentUpdated => 'Оплата обновлена';

  @override
  String get paymentCreated => 'Оплата добавлена';

  @override
  String get paymentMethod => 'Способ оплаты';

  @override
  String get cash => 'Наличные';

  @override
  String get card => 'Карта';

  @override
  String get transfer => 'Передать';

  @override
  String get todayPayments => 'Сегодня оплачено';

  @override
  String get paymentHistory => 'История оплат';

  @override
  String get balanceTransfer => 'Перенос остатка';

  @override
  String get balanceTransferComment => 'Комментарий к переносу';

  @override
  String get filterStudents => 'Ученики';

  @override
  String get filterSubjects => 'Предметы';

  @override
  String get filterTeachers => 'Преподаватели';

  @override
  String get filterPlans => 'Тарифы';

  @override
  String get filterMethod => 'Способ';

  @override
  String get resetFilters => 'Сбросить фильтры';

  @override
  String get periodWeek => 'Неделя';

  @override
  String get periodMonth => 'Месяц';

  @override
  String get periodQuarter => 'Квартал';

  @override
  String get periodYear => 'Год';

  @override
  String get periodCustom => 'Свой';

  @override
  String get total => 'Итого:';

  @override
  String get totalOwnStudents => 'Итого (ваши ученики):';

  @override
  String get noAccessToPayments => 'Нет доступа к просмотру оплат';

  @override
  String get noPaymentsForPeriod => 'Нет оплат за этот период';

  @override
  String get noPaymentsOwnForPeriod =>
      'Нет оплат ваших учеников за этот период';

  @override
  String get noPaymentsWithFilters => 'Нет оплат по заданным фильтрам';

  @override
  String get familySubscriptionOption => 'Групповой абонемент';

  @override
  String get familySubscriptionDescription =>
      'Один абонемент на несколько учеников';

  @override
  String get selectParticipants => 'Выберите участников';

  @override
  String participantsOf(int count, int total) {
    return '$count из $total';
  }

  @override
  String get minTwoParticipants => 'Минимум 2 участника';

  @override
  String get minTwoParticipantsRequired =>
      'Выберите минимум 2 участника для группового абонемента';

  @override
  String get mergeIntoCard => 'Объединить в одну карточку';

  @override
  String get mergeIntoCardDescription => 'Создаст групповую карточку учеников';

  @override
  String get groupCardName => 'Имя групповой карточки';

  @override
  String get groupCardNameHint => 'Например: Семья Петровых';

  @override
  String get selectStudentRequired => 'Выберите ученика';

  @override
  String get selectStudentAndPlan => 'Выберите ученика и тариф';

  @override
  String get addStudentsFirst => 'Сначала добавьте учеников';

  @override
  String get customOption => 'Свой вариант';

  @override
  String get discount => 'Скидка';

  @override
  String get discountSize => 'Размер скидки';

  @override
  String wasPrice(String price) {
    return 'Было: $price ₸';
  }

  @override
  String totalPrice(String price) {
    return 'Итого: $price ₸';
  }

  @override
  String get enterAmount => 'Введите сумму';

  @override
  String get invalidAmount => 'Неверная сумма';

  @override
  String get lessonsCountField => 'Занятий';

  @override
  String get enterValue => 'Введите';

  @override
  String get invalidNumber => 'Число';

  @override
  String get validityDays => 'Срок (дн.)';

  @override
  String get invalidValue => 'Некорректное значение';

  @override
  String get commentOptional => 'Комментарий (необязательно)';

  @override
  String addPaymentWithAmount(String amount) {
    return 'Добавить оплату $amount ₸';
  }

  @override
  String get cardMergedAndPaymentAdded =>
      'Карточка объединена и оплата добавлена';

  @override
  String get groupSubscriptionAdded => 'Групповой абонемент добавлен';

  @override
  String get paymentAdded => 'Оплата добавлена';

  @override
  String deletePaymentConfirmation(int amount, int lessons) {
    return 'Оплата на сумму $amount ₸ будет удалена. Баланс ученика уменьшится на $lessons занятий.';
  }

  @override
  String get noEditPermission => 'Нет прав на редактирование';

  @override
  String get canEditOwnStudentsOnly =>
      'Вы можете редактировать только оплаты своих учеников';

  @override
  String paymentFrom(String date) {
    return 'Оплата от $date';
  }

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get deletePaymentButton => 'Удалить оплату';

  @override
  String get subscriptionMembers => 'Участники абонемента';

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String loadingError(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get noStudentsYet => 'Нет учеников';

  @override
  String discountNote(String amount) {
    return 'Скидка: $amount ₸';
  }

  @override
  String get subscription => 'Абонемент';

  @override
  String get subscriptions => 'Абонементы';

  @override
  String get expiringSubscriptions => 'Истекающие абонементы';

  @override
  String get noSubscriptions => 'Нет абонементов';

  @override
  String get lessonsRemaining => 'Осталось занятий';

  @override
  String get validUntil => 'Действует до';

  @override
  String get expired => 'Истёк';

  @override
  String get active => 'Активный';

  @override
  String get familySubscription => 'Семейный абонемент';

  @override
  String get statusActive => 'Активен';

  @override
  String get statusFrozen => 'Заморожен';

  @override
  String get statusExpired => 'Истёк';

  @override
  String get statusExhausted => 'Исчерпан';

  @override
  String minutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String get hourOne => '1 час';

  @override
  String get hourOneHalf => '1.5 часа';

  @override
  String hoursShort(int hours) {
    return '$hours ч';
  }

  @override
  String hoursMinutesShort(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String get currencyName => 'тенге';

  @override
  String get networkErrorMessage =>
      'Ошибка сети. Проверьте подключение к интернету.';

  @override
  String get timeoutErrorMessage =>
      'Превышено время ожидания. Попробуйте ещё раз.';

  @override
  String get sessionExpiredMessage => 'Сессия истекла. Войдите заново.';

  @override
  String get errorOccurredMessage => 'Произошла ошибка';

  @override
  String errorMessage(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get profile => 'Профиль';

  @override
  String get name => 'Имя';

  @override
  String get registrationDate => 'Дата регистрации';

  @override
  String get editName => 'Изменить имя';

  @override
  String get personName => 'ФИО';

  @override
  String get personNameHint => 'Иванов Иван Иванович';

  @override
  String get enterPersonName => 'Введите имя';

  @override
  String get personNameUpdated => 'Имя обновлено';

  @override
  String get subjects => 'Направления';

  @override
  String get lessonTypes => 'Типы занятий';

  @override
  String get paymentPlans => 'Тарифы оплаты';

  @override
  String get teamMembers => 'Участники';

  @override
  String get inviteMembers => 'Пригласить участника';

  @override
  String get theme => 'Тема оформления';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get account => 'Аккаунт';

  @override
  String get general => 'Основные';

  @override
  String get data => 'Данные';

  @override
  String get workingHours => 'Рабочие часы';

  @override
  String get workStart => 'Начало работы';

  @override
  String get workEnd => 'Конец работы';

  @override
  String get phoneCountry => 'Код страны для телефонов';

  @override
  String get changesSaved => 'Изменения сохранены';

  @override
  String get inviteCodeCopied => 'Код приглашения скопирован';

  @override
  String get shareInviteCode => 'Поделиться кодом';

  @override
  String get generateNewCode => 'Сгенерировать новый код';

  @override
  String get permissions => 'Права доступа';

  @override
  String get editPermissions => 'Редактировать права';

  @override
  String get removeMember => 'Удалить участника';

  @override
  String get leaveInstitution => 'Покинуть заведение';

  @override
  String get booking => 'Бронь';

  @override
  String get bookings => 'Бронирования';

  @override
  String get addBooking => 'Добавить бронь';

  @override
  String get deleteBooking => 'Удалить бронь';

  @override
  String get bookingDeleted => 'Бронь удалена';

  @override
  String get bookingCreated => 'Бронь создана';

  @override
  String get permanentSchedule => 'Постоянное расписание';

  @override
  String get oneTimeBooking => 'Разовое бронирование';

  @override
  String get slot => 'Слот';

  @override
  String get slots => 'Слоты';

  @override
  String get freeSlot => 'Свободный слот';

  @override
  String get occupiedSlot => 'Занятый слот';

  @override
  String get lessonSchedule => 'Постоянное занятие';

  @override
  String get lessonSchedules => 'Постоянные занятия';

  @override
  String get addLessonSchedule => 'Добавить постоянное занятие';

  @override
  String get editLessonSchedule => 'Редактировать постоянное занятие';

  @override
  String get deleteLessonSchedule => 'Удалить постоянное занятие';

  @override
  String get pauseLessonSchedule => 'Приостановить';

  @override
  String get resumeLessonSchedule => 'Возобновить';

  @override
  String get pauseUntil => 'Приостановить до';

  @override
  String get paused => 'Приостановлено';

  @override
  String get dayOfWeek => 'День недели';

  @override
  String get validFrom => 'Действует с';

  @override
  String get replaceRoom => 'Временная замена кабинета';

  @override
  String get replaceUntil => 'Замена до';

  @override
  String get totalLessons => 'Всего занятий';

  @override
  String get totalPayments => 'Всего оплат';

  @override
  String get totalStudents => 'Всего учеников';

  @override
  String get period => 'Период';

  @override
  String get thisWeek => 'Эта неделя';

  @override
  String get thisMonth => 'Этот месяц';

  @override
  String get lastMonth => 'Прошлый месяц';

  @override
  String get customPeriod => 'Свой период';

  @override
  String get income => 'Доход';

  @override
  String get lessonsCompleted => 'Проведено';

  @override
  String get lessonsCancelled => 'Отменено';

  @override
  String get bySubject => 'По предметам';

  @override
  String get byTeacher => 'По преподавателям';

  @override
  String get byStudent => 'По ученикам';

  @override
  String get filters => 'Фильтры';

  @override
  String get filterBy => 'Фильтр по';

  @override
  String get sortBy => 'Сортировать по';

  @override
  String get dateRange => 'Период';

  @override
  String get status => 'Статус';

  @override
  String get clearFilters => 'Сбросить фильтры';

  @override
  String get applyFilters => 'Применить фильтры';

  @override
  String get noResults => 'Ничего не найдено';

  @override
  String get teachers => 'Преподаватели';

  @override
  String get monday => 'Понедельник';

  @override
  String get tuesday => 'Вторник';

  @override
  String get wednesday => 'Среда';

  @override
  String get thursday => 'Четверг';

  @override
  String get friday => 'Пятница';

  @override
  String get saturday => 'Суббота';

  @override
  String get sunday => 'Воскресенье';

  @override
  String get mondayShort => 'Пн';

  @override
  String get tuesdayShort => 'Вт';

  @override
  String get wednesdayShort => 'Ср';

  @override
  String get thursdayShort => 'Чт';

  @override
  String get fridayShort => 'Пт';

  @override
  String get saturdayShort => 'Сб';

  @override
  String get sundayShort => 'Вс';

  @override
  String get errorOccurred => 'Произошла ошибка';

  @override
  String get networkError => 'Ошибка сети. Проверьте подключение.';

  @override
  String get unknownError => 'Неизвестная ошибка';

  @override
  String get invalidEmail => 'Некорректный email';

  @override
  String get weakPassword => 'Пароль слишком простой';

  @override
  String get emailInUse => 'Email уже используется';

  @override
  String get invalidCredentials => 'Неверный email или пароль';

  @override
  String get fieldRequired => 'Это поле обязательно';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get minPasswordLength => 'Минимум 8 символов';

  @override
  String get passwordNeedsUppercase => 'Нужна хотя бы одна заглавная буква';

  @override
  String get passwordNeedsSpecialChar =>
      'Нужен хотя бы один спецсимвол (!@#\$%^&*)';

  @override
  String get invalidPhoneNumber => 'Некорректный номер телефона';

  @override
  String get enterPositiveNumber => 'Введите положительное число';

  @override
  String get enterPositiveInteger => 'Введите целое положительное число';

  @override
  String get sessionExpired => 'Сессия истекла. Войдите заново.';

  @override
  String get noServerConnection => 'Нет соединения с сервером';

  @override
  String get errorOccurredTitle => 'Произошла ошибка';

  @override
  String get timeoutError => 'Превышено время ожидания. Попробуйте ещё раз.';

  @override
  String get noConnection => 'Нет соединения с сервером';

  @override
  String get timeout => 'Превышено время ожидания. Попробуйте ещё раз.';

  @override
  String get notFound => 'Не найдено';

  @override
  String get accessDenied => 'Доступ запрещён';

  @override
  String errorWithMessage(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get confirmDelete => 'Подтвердите удаление';

  @override
  String get confirmArchive => 'Подтвердите архивацию';

  @override
  String get confirmCancel => 'Подтвердите отмену';

  @override
  String get confirmLogout => 'Выйти из аккаунта?';

  @override
  String get confirmLeave => 'Покинуть заведение?';

  @override
  String get deleteConfirmation => 'Вы уверены, что хотите удалить?';

  @override
  String get archiveConfirmation => 'Вы уверены, что хотите архивировать?';

  @override
  String get actionCannotBeUndone => 'Это действие нельзя отменить';

  @override
  String deleteQuestion(String item) {
    return 'Удалить $item?';
  }

  @override
  String archiveQuestion(String item) {
    return 'Архивировать $item?';
  }

  @override
  String lessonsCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count занятий',
      many: '$count занятий',
      few: '$count занятия',
      one: '1 занятие',
      zero: 'нет занятий',
    );
    return '$_temp0';
  }

  @override
  String studentsCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count учеников',
      many: '$count учеников',
      few: '$count ученика',
      one: '1 ученик',
      zero: 'нет учеников',
    );
    return '$_temp0';
  }

  @override
  String paymentsCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count оплат',
      many: '$count оплат',
      few: '$count оплаты',
      one: '1 оплата',
      zero: 'нет оплат',
    );
    return '$_temp0';
  }

  @override
  String daysCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      many: '$count дней',
      few: '$count дня',
      one: '1 день',
      zero: '0 дней',
    );
    return '$_temp0';
  }

  @override
  String minutesCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минут',
      many: '$count минут',
      few: '$count минуты',
      one: '1 минута',
      zero: '0 минут',
    );
    return '$_temp0';
  }

  @override
  String membersCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      many: '$count участников',
      few: '$count участника',
      one: '1 участник',
      zero: 'нет участников',
    );
    return '$_temp0';
  }

  @override
  String prepaidLessonsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Предоплачено $count занятий',
      many: 'Предоплачено $count занятий',
      few: 'Предоплачено $count занятия',
      one: 'Предоплачено 1 занятие',
      zero: 'Нет предоплаченных занятий',
    );
    return '$_temp0';
  }

  @override
  String lessonsRemainingPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count занятий',
      many: 'Осталось $count занятий',
      few: 'Осталось $count занятия',
      one: 'Осталось 1 занятие',
      zero: 'Занятий не осталось',
    );
    return '$_temp0';
  }

  @override
  String get colorPicker => 'Выберите цвет';

  @override
  String get selectColor => 'Выберите цвет';

  @override
  String get defaultColor => 'Цвет по умолчанию';

  @override
  String get dateMissed => 'Дата пропущена';

  @override
  String get slotPaused => 'Слот приостановлен';

  @override
  String get exclusionAdded => 'Исключение добавлено';

  @override
  String get history => 'История';

  @override
  String get deleteFromHistory => 'Удалить из истории';

  @override
  String get noHistory => 'Нет истории';

  @override
  String get sendLink => 'Отправить ссылку';

  @override
  String get linkSent => 'Ссылка отправлена';

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get archiveInstitution => 'Архивировать заведение';

  @override
  String get leaveInstitutionAction => 'Покинуть заведение';

  @override
  String get institutionCanBeRestored => 'Заведение можно будет восстановить';

  @override
  String get youWillNoLongerBeMember => 'Вы больше не будете участником';

  @override
  String get archiveInstitutionQuestion => 'Архивировать заведение?';

  @override
  String get leaveInstitutionQuestion => 'Покинуть заведение?';

  @override
  String archiveInstitutionMessage(String name) {
    return 'Заведение \"$name\" будет перемещено в архив. Вы сможете восстановить его позже из списка заведений.';
  }

  @override
  String leaveInstitutionMessage(String name) {
    return 'Вы уверены, что хотите покинуть \"$name\"? Чтобы вернуться, вам понадобится новый код приглашения.';
  }

  @override
  String get institutionArchived => 'Заведение архивировано';

  @override
  String get institutionDeleted => 'Заведение удалено';

  @override
  String get institutionDeletedMessage =>
      'Это заведение было удалено владельцем. Вы будете перенаправлены на главный экран.';

  @override
  String get ok => 'ОК';

  @override
  String get youLeftInstitution => 'Вы покинули заведение';

  @override
  String get generateNewCodeQuestion => 'Сгенерировать новый код?';

  @override
  String get generateNewCodeMessage =>
      'Старый код перестанет работать. Все, кто ещё не присоединился по старому коду, не смогут это сделать.';

  @override
  String get generate => 'Сгенерировать';

  @override
  String newCodeGenerated(String code) {
    return 'Новый код: $code';
  }

  @override
  String get nameUpdated => 'Название обновлено';

  @override
  String get enterName => 'Введите название';

  @override
  String get workingHoursUpdated => 'Рабочее время обновлено';

  @override
  String get workingHoursDescription =>
      'Это время будет отображаться в сетке расписания';

  @override
  String get start => 'Начало';

  @override
  String get end => 'Конец';

  @override
  String get byLocale => 'По локали устройства';

  @override
  String todayWithDate(String date) {
    return 'Сегодня, $date';
  }

  @override
  String get noScheduledLessons => 'Нет запланированных занятий';

  @override
  String get urgent => 'Срочно';

  @override
  String get daysShort => 'дн.';

  @override
  String get lessonPayment => 'Оплата занятия';

  @override
  String saveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get completeProfileSetup => 'Завершите настройку профиля';

  @override
  String get selectColorAndSubjects => 'Выберите цвет и направления';

  @override
  String get fillIn => 'Заполнить';

  @override
  String get paid => 'Оплачено';

  @override
  String get archivedInstitutions => 'Архив заведений';

  @override
  String get archiveEmpty => 'Архив пуст';

  @override
  String get restoreInstitutionQuestion => 'Восстановить заведение?';

  @override
  String restoreInstitutionMessage(String name) {
    return 'Заведение \"$name\" будет восстановлено и появится в основном списке.';
  }

  @override
  String get institutionRestored => 'Заведение восстановлено';

  @override
  String archivedOn(String date) {
    return 'Архивировано $date';
  }

  @override
  String get noMembers => 'Нет участников';

  @override
  String get noName => 'Без имени';

  @override
  String get you => 'Вы';

  @override
  String get adminBadge => 'Админ';

  @override
  String get changeColor => 'Изменить цвет';

  @override
  String get colorUpdated => 'Цвет обновлён';

  @override
  String get colorReset => 'Цвет сброшен';

  @override
  String get directions => 'Направления';

  @override
  String get changeRole => 'Изменить роль';

  @override
  String get roleName => 'Название роли';

  @override
  String get roleNameHint => 'Например: Преподаватель, Администратор';

  @override
  String get accessRights => 'Права доступа';

  @override
  String get manageLessons => 'Управление занятиями';

  @override
  String get transferOwnershipQuestion => 'Передать владение?';

  @override
  String get transferOwnershipWarning =>
      'Вы собираетесь передать права владельца пользователю:';

  @override
  String get transferWarningTitle => 'Внимание!';

  @override
  String get transferWarningPoints =>
      '• Вы потеряете права владельца\n• Новый владелец сможет удалить заведение\n• Это действие нельзя отменить самостоятельно';

  @override
  String ownershipTransferred(String name) {
    return 'Права владельца переданы $name';
  }

  @override
  String get removeMemberQuestion => 'Удалить участника?';

  @override
  String removeMemberConfirmation(String name) {
    return 'Вы уверены, что хотите удалить $name из заведения?';
  }

  @override
  String futureLessonsCount(int count) {
    return 'Будущих занятий: $count';
  }

  @override
  String get noFutureLessonsToManage => 'Нет будущих занятий для управления';

  @override
  String get deleteAllFutureLessons => 'Удалить все будущие занятия';

  @override
  String get deleteAllFutureLessonsDescription =>
      'Занятия будут удалены без изменения баланса учеников';

  @override
  String get reassignTeacher => 'Переназначить преподавателя';

  @override
  String get reassignTeacherDescription =>
      'Передать все занятия другому преподавателю';

  @override
  String get deleteLessonsQuestion => 'Удалить занятия?';

  @override
  String deleteLessonsCount(int count) {
    return 'Будет удалено $count занятий преподавателя:';
  }

  @override
  String get deleteLessonsWarning =>
      'Баланс абонементов учеников не изменится.\nЭто действие нельзя отменить.';

  @override
  String lessonsDeletedCount(int count) {
    return 'Удалено занятий: $count';
  }

  @override
  String get reassignLessons => 'Переназначить занятия';

  @override
  String reassignLessonsFrom(int count, String name) {
    return '$count занятий от $name';
  }

  @override
  String get selectNewTeacher => 'Выберите нового преподавателя:';

  @override
  String get noOtherTeachers => 'Нет других преподавателей';

  @override
  String get checkingConflicts => 'Проверка конфликтов...';

  @override
  String conflictsFound(int count) {
    return 'Найдено $count конфликтов';
  }

  @override
  String get noConflictsFound => 'Конфликтов не найдено';

  @override
  String andMoreConflicts(int count) {
    return '...и ещё $count конфликтов';
  }

  @override
  String get skipConflicts => 'Пропустить конфликты';

  @override
  String get reassign => 'Переназначить';

  @override
  String conflictCheckError(String error) {
    return 'Ошибка проверки: $error';
  }

  @override
  String get noLessonsToReassign => 'Нет занятий для переназначения';

  @override
  String reassignedCount(int count) {
    return 'Переназначено занятий: $count';
  }

  @override
  String skippedConflicts(int count) {
    return 'пропущено: $count';
  }

  @override
  String get noSubjectsAvailable => 'Нет доступных направлений';

  @override
  String get subjectsUpdated => 'Направления обновлены';

  @override
  String errorWithDetails(String details) {
    return 'Ошибка: $details';
  }

  @override
  String get newRoom => 'Новый кабинет';

  @override
  String get editRoomTitle => 'Редактировать кабинет';

  @override
  String get roomNumberRequired => 'Номер кабинета *';

  @override
  String get roomNumberHint => 'Например: 101';

  @override
  String get roomNameOptional => 'Название (опционально)';

  @override
  String get roomNameHint => 'Например: Фортепианный';

  @override
  String get enterRoomNumber => 'Введите номер кабинета';

  @override
  String get fillRoomData => 'Заполните данные кабинета';

  @override
  String get changeRoomData => 'Измените данные кабинета';

  @override
  String get createRoom => 'Создать кабинет';

  @override
  String roomWithNumber(String number) {
    return 'Кабинет $number';
  }

  @override
  String roomCreatedMessage(String name) {
    return 'Кабинет \"$name\" создан';
  }

  @override
  String get deleteRoomQuestion => 'Удалить кабинет?';

  @override
  String deleteRoomMessage(String name) {
    return 'Кабинет \"$name\" будет удалён. Это действие нельзя отменить.';
  }

  @override
  String get myStudents => 'Мои';

  @override
  String get withDebt => 'С долгом';

  @override
  String get searchByName => 'Поиск по имени...';

  @override
  String get direction => 'Направление';

  @override
  String get activity => 'Активность';

  @override
  String get noStudentsByFilters => 'Нет учеников по заданным фильтрам';

  @override
  String get tryDifferentQuery => 'Попробуйте изменить запрос';

  @override
  String get archivedStudentsHere =>
      'Здесь будут отображаться архивированные ученики';

  @override
  String get noStudentsWithDebt => 'Нет учеников с долгом';

  @override
  String get allStudentsPositiveBalance =>
      'У всех учеников положительный баланс';

  @override
  String get noLinkedStudents => 'Нет привязанных учеников';

  @override
  String get noLinkedStudentsHint => 'К вам пока не привязаны ученики';

  @override
  String get addFirstStudent => 'Добавьте первого ученика';

  @override
  String get noLessons7Days => 'Нет занятий 7+ дней';

  @override
  String get noLessons14Days => 'Нет занятий 14+ дней';

  @override
  String get noLessons30Days => 'Нет занятий 30+ дней';

  @override
  String get noLessons60Days => 'Нет занятий 60+ дней';

  @override
  String get groupNameHint => 'Например: Группа вокала';

  @override
  String studentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count учеников',
      many: '$count учеников',
      few: '$count ученика',
      one: '1 ученик',
    );
    return '$_temp0';
  }

  @override
  String mergeCount(int count) {
    return 'Объединить ($count)';
  }

  @override
  String get fillStudentData => 'Заполните данные ученика';

  @override
  String get fullNameRequired => 'ФИО *';

  @override
  String get fullNameHint => 'Иванов Иван Иванович';

  @override
  String get enterStudentName => 'Введите имя ученика';

  @override
  String get phoneHint => '+7 (777) 123-45-67';

  @override
  String get noAvailableTeachers => 'Нет доступных преподавателей';

  @override
  String get additionalInfo => 'Дополнительная информация...';

  @override
  String get remainingLessons => 'Остаток занятий';

  @override
  String get fromOtherSchool => 'При переносе из другой школы';

  @override
  String get lessonsUnit => 'занятий';

  @override
  String get remainingLessonsHint => 'Списывается первым, не влияет на доход';

  @override
  String get createStudent => 'Создать ученика';

  @override
  String get selectRoomForSchedule => 'Выберите кабинет для расписания';

  @override
  String get scheduleConflictsError =>
      'Есть конфликты в расписании. Измените время или кабинет.';

  @override
  String get initialBalanceComment => 'Начальный остаток';

  @override
  String studentCreatedWithSchedule(String name) {
    return 'Ученик \"$name\" создан с расписанием';
  }

  @override
  String studentCreatedSimple(String name) {
    return 'Ученик \"$name\" создан';
  }

  @override
  String get setupPermanentSchedule => 'Настроить постоянное расписание';

  @override
  String get selectDaysAndTime => 'Выберите дни и время занятий';

  @override
  String get roomForLessons => 'Кабинет для занятий';

  @override
  String get daysOfWeekLabel => 'Дни недели';

  @override
  String get lessonTimeLabel => 'Время занятий';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String durationHours(int hours) {
    return '$hours ч';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get incorrect => 'Некорректно';

  @override
  String get conflictTimeOccupied => 'Конфликт! Время занято';

  @override
  String lessonsBalance(int count) {
    return '$count занятий';
  }

  @override
  String get noLessonTypes => 'Нет типов занятий';

  @override
  String get addFirstLessonType => 'Добавьте первый тип занятия';

  @override
  String get addType => 'Добавить тип';

  @override
  String get deleteLessonTypeQuestion => 'Удалить тип занятия?';

  @override
  String lessonTypeWillBeDeleted(String name) {
    return 'Тип \"$name\" будет удалён';
  }

  @override
  String get lessonTypeDeleted => 'Тип занятия удалён';

  @override
  String get newLessonType => 'Новый тип занятия';

  @override
  String get fillLessonTypeData => 'Заполните данные типа';

  @override
  String get nameRequired => 'Название *';

  @override
  String get nameHintExample => 'Например: Индивидуальное';

  @override
  String get enterNameValidation => 'Введите название';

  @override
  String get other => 'Другое';

  @override
  String get customDuration => 'Своя длительность';

  @override
  String get defaultPrice => 'Цена по умолчанию';

  @override
  String get groupLessonSwitch => 'Групповое занятие';

  @override
  String get multipleStudents => 'Несколько учеников одновременно';

  @override
  String get oneStudent => 'Один ученик';

  @override
  String get createType => 'Создать тип';

  @override
  String lessonTypeCreated(String name) {
    return 'Тип \"$name\" создан';
  }

  @override
  String get editLessonType => 'Редактировать тип';

  @override
  String get changeLessonTypeData => 'Измените данные типа занятия';

  @override
  String get durationValidationError =>
      'Длительность должна быть от 5 до 480 минут';

  @override
  String get color => 'Цвет';

  @override
  String get lessonTypeUpdated => 'Тип занятия обновлён';

  @override
  String get scheduleTitle => 'Расписание';

  @override
  String roomWithNumberTitle(String number) {
    return 'Кабинет $number';
  }

  @override
  String get filtersTooltip => 'Фильтры';

  @override
  String get addTooltip => 'Добавить';

  @override
  String get compactView => 'Компакт.';

  @override
  String get detailedView => 'Подробн.';

  @override
  String get dayView => 'День';

  @override
  String get weekView => 'Неделя';

  @override
  String get lessonDefault => 'Занятие';

  @override
  String get booked => 'Забронировано';

  @override
  String get studentDefault => 'Ученик';

  @override
  String get hour => 'Час';

  @override
  String get deletedFromHistory => 'Удалить из истории';

  @override
  String get modify => 'Изменить';

  @override
  String get cancelLesson => 'Отменить';

  @override
  String get skipThisDate => 'Пропустить эту дату';

  @override
  String get statusUpdateFailed => 'Не удалось обновить статус';

  @override
  String get lessonCompletedMessage => 'Занятие проведено';

  @override
  String get lessonCancelledMessage => 'Занятие отменено';

  @override
  String get skipDateTitle => 'Пропустить дату';

  @override
  String skipDateMessage(String date) {
    return 'Занятие не будет отображаться на $date.\n\nЭто не создаст запись в истории занятий.';
  }

  @override
  String get skip => 'Пропустить';

  @override
  String get dateSkipped => 'Дата пропущена';

  @override
  String get lessonDeducted => 'Занятие списано';

  @override
  String get lessonReturned => 'Занятие возвращено';

  @override
  String get deleteLessonWithPayment =>
      'Занятие будет удалено из истории.\nОплата за занятие также будет удалена.';

  @override
  String get deleteLessonWithBalance =>
      'Занятие будет удалено из истории.\nСписанное занятие будет возвращено на баланс ученика.';

  @override
  String get deleteLessonSimple =>
      'Занятие будет полностью удалено из истории.';

  @override
  String get deleteLessonQuestion => 'Удалить занятие?';

  @override
  String get lessonDeletedFromHistory => 'Занятие удалено из истории';

  @override
  String get lessonPaymentType => 'Оплата занятия';

  @override
  String get paymentAddedMessage => 'Оплата добавлена';

  @override
  String get paymentDeletedMessage => 'Оплата удалена';

  @override
  String paymentDeleteError(String error) {
    return 'Ошибка удаления оплаты: $error';
  }

  @override
  String cancelledLessonsCount(int count) {
    return 'Отменено $count занятий';
  }

  @override
  String get cancelLessonTitle => 'Отменить занятие';

  @override
  String get cancelWithoutDeduction =>
      'Занятие будет отменено и архивировано без списания с баланса';

  @override
  String get deductionWillBeReturned =>
      'Списанное при проведении занятие будет автоматически возвращено на баланс.';

  @override
  String get deductFromBalance => 'Списать занятие с баланса';

  @override
  String get lessonWillBeDeducted => 'Занятие будет вычтено из предоплаченных';

  @override
  String get whoToDeduct => 'Кому списать занятие:';

  @override
  String balanceLabel(int count) {
    return 'Баланс: $count';
  }

  @override
  String seriesPartInfo(int count) {
    return 'Это занятие является частью серии ($count шт.)';
  }

  @override
  String get onlyThis => 'Только это';

  @override
  String get thisAndFollowing => 'Это и последующие';

  @override
  String get deductOnlyToday =>
      'Списание применится только к сегодняшнему занятию';

  @override
  String get archiveWithoutDeduction =>
      'Все занятия серии будут архивированы без списания';

  @override
  String cancelLessonsCount(int count) {
    return 'Отменить $count занятий';
  }

  @override
  String get seriesCancelled => 'Серия занятий отменена';

  @override
  String get cancelledWithDeduction => 'Занятие отменено и списано с баланса';

  @override
  String get cancelledWithoutDeduction => 'Занятие отменено';

  @override
  String get permanentSchedulePart =>
      'Это занятие является частью постоянного расписания';

  @override
  String get thisAndAllFollowing => 'Это и все последующие';

  @override
  String get participantsTitle => 'Участники';

  @override
  String get noParticipantsMessage => 'Нет участников';

  @override
  String get addGuestLabel => 'Добавить гостя';

  @override
  String get payLabel => 'Оплатить';

  @override
  String get unknownStudent => 'Неизвестный';

  @override
  String get paymentTitle => 'Оплата';

  @override
  String get removeFromLessonTooltip => 'Убрать из занятия';

  @override
  String paymentRecorded(int count, String students) {
    return 'Оплата записана: $count $students';
  }

  @override
  String paymentError(String error) {
    return 'Ошибка оплаты: $error';
  }

  @override
  String get studentSingular => 'ученик';

  @override
  String get studentFew => 'ученика';

  @override
  String get studentMany => 'учеников';

  @override
  String get removeParticipantQuestion => 'Убрать участника?';

  @override
  String removeFromLessonMessage(String name) {
    return 'Убрать $name из этого занятия?';
  }

  @override
  String get removeFromLessonGeneric => 'Убрать участника из этого занятия?';

  @override
  String get remove => 'Убрать';

  @override
  String get addGuestTitle => 'Добавить гостя';

  @override
  String get allStudentsAdded => 'Все ученики уже добавлены';

  @override
  String get editLessonTitle => 'Редактировать занятие';

  @override
  String get dateLabel => 'Дата';

  @override
  String get timeLabel => 'Время';

  @override
  String get roomLabel => 'Кабинет';

  @override
  String get groupLabel => 'Группа';

  @override
  String get subjectLabel => 'Предмет';

  @override
  String get lessonTypeLabel => 'Тип занятия';

  @override
  String get notSelected => 'Не выбран';

  @override
  String get saveChangesLabel => 'Сохранить изменения';

  @override
  String get minDurationError => 'Минимальная длительность занятия — 15 минут';

  @override
  String get lessonUpdatedMessage => 'Занятие обновлено';

  @override
  String get noRepeat => 'Без повтора';

  @override
  String get everyDay => 'Каждый день';

  @override
  String get everyWeek => 'Каждую неделю';

  @override
  String get byWeekdays => 'По дням недели';

  @override
  String get manualDates => 'Ручной выбор дат';

  @override
  String get onlyThisLesson => 'Только это занятие';

  @override
  String get allSeriesLessons => 'Все занятия серии';

  @override
  String get selectedLessons => 'Выбранные';

  @override
  String roomAdded(String name) {
    return 'Кабинет \"$name\" добавлен';
  }

  @override
  String get newRoomTitle => 'Новый кабинет';

  @override
  String get fillRoomDataMessage => 'Заполните данные кабинета';

  @override
  String get roomNumberLabel => 'Номер кабинета *';

  @override
  String get enterRoomNumberValidation => 'Введите номер кабинета';

  @override
  String get nameOptionalLabel => 'Название (опционально)';

  @override
  String get nameOptionalHint => 'Например: Фортепианный';

  @override
  String get createRoomLabel => 'Создать кабинет';

  @override
  String get selectStudentTitle => 'Выберите ученика';

  @override
  String get noOwnStudents => 'У вас нет своих учеников';

  @override
  String showAllCount(int count) {
    return 'Показать всех ($count)';
  }

  @override
  String get otherStudents => 'Остальные ученики';

  @override
  String get hideLabel => 'Скрыть';

  @override
  String studentAddedMessage(String name) {
    return 'Ученик \"$name\" добавлен';
  }

  @override
  String get newStudentTitle => 'Новый ученик';

  @override
  String get quickAddLabel => 'Быстрое добавление';

  @override
  String get fullNameLabel => 'ФИО';

  @override
  String get enterStudentNameValidation => 'Введите имя ученика';

  @override
  String get phoneLabel => 'Телефон';

  @override
  String get createStudentLabel => 'Создать ученика';

  @override
  String subjectAddedMessage(String name) {
    return 'Предмет \"$name\" добавлен';
  }

  @override
  String get newSubjectTitle => 'Новый предмет';

  @override
  String get addSubjectMessage => 'Добавьте предмет для занятий';

  @override
  String get subjectNameLabel => 'Название предмета';

  @override
  String get subjectNameHint => 'Например: Фортепиано';

  @override
  String get enterSubjectNameValidation => 'Введите название предмета';

  @override
  String get createSubjectLabel => 'Создать предмет';

  @override
  String get durationValidation => 'Длительность должна быть от 5 до 480 минут';

  @override
  String lessonTypeAddedMessage(String name) {
    return 'Тип занятия \"$name\" добавлен';
  }

  @override
  String get newLessonTypeTitle => 'Новый тип занятия';

  @override
  String get configureLessonType => 'Настройте параметры занятия';

  @override
  String get nameLabel => 'Название';

  @override
  String get lessonTypeNameHint => 'Например: Индивидуальное занятие';

  @override
  String get durationLabel => 'Длительность';

  @override
  String get otherOption => 'Другое';

  @override
  String get customDurationLabel => 'Своя длительность';

  @override
  String get enterMinutes => 'Введите минуты';

  @override
  String get minutesSuffix => 'мин';

  @override
  String get priceOptionalLabel => 'Цена (необязательно)';

  @override
  String get priceHint => 'Например: 5000';

  @override
  String get groupLessonTitle => 'Групповое занятие';

  @override
  String get forMultipleStudents => 'Для нескольких учеников';

  @override
  String get createTypeLabel => 'Создать тип';

  @override
  String get filtersTitle => 'Фильтры';

  @override
  String get resetLabel => 'Сбросить';

  @override
  String get teachersTitle => 'Преподаватели';

  @override
  String get lessonTypesTitle => 'Типы занятий';

  @override
  String get directionsTitle => 'Направления';

  @override
  String get applyFiltersLabel => 'Применить фильтры';

  @override
  String get showAllLabel => 'Показать все';

  @override
  String get studentsTitle => 'Ученики';

  @override
  String get noStudentsMessage => 'Нет учеников';

  @override
  String get deletedStudent => 'Удалён';

  @override
  String get temporarilyShowAll => 'Временно показаны все';

  @override
  String get notConfigured => 'Не настроено';

  @override
  String get allRooms => 'Все кабинеты';

  @override
  String get defaultRoomsTitle => 'Кабинеты по умолчанию';

  @override
  String get restoreRoomFilter => 'Вернуть фильтр кабинетов';

  @override
  String get showAllRooms => 'Показать все кабинеты';

  @override
  String get noDataMessage => 'Нет данных';

  @override
  String get selectDates => 'Выберите даты';

  @override
  String get doneLabel => 'Готово';

  @override
  String get lessonTab => 'Занятие';

  @override
  String get bookingTab => 'Бронь';

  @override
  String get noRoomsAvailable => 'Нет кабинетов';

  @override
  String get dateRequired => 'Дата *';

  @override
  String get timeRequired => 'Время *';

  @override
  String get roomsTitle => 'Кабинеты';

  @override
  String roomShort(String number) {
    return 'Каб. $number';
  }

  @override
  String get selectAtLeastOneRoom => 'Выберите хотя бы один кабинет';

  @override
  String get descriptionOptional => 'Описание (опционально)';

  @override
  String get descriptionHint => 'Мероприятие, встреча и т.д.';

  @override
  String get bookLabel => 'Забронировать';

  @override
  String get studentTab => 'Ученик';

  @override
  String get groupTab => 'Группа';

  @override
  String get studentRequired => 'Ученик *';

  @override
  String get selectStudentPlaceholder => 'Выберите ученика';

  @override
  String get addStudentTooltip => 'Добавить ученика';

  @override
  String get groupRequired => 'Группа *';

  @override
  String get noGroupsAvailable => 'Нет групп';

  @override
  String get createGroupTooltip => 'Создать группу';

  @override
  String get teacherLabel => 'Преподаватель';

  @override
  String get addSubjectTooltip => 'Добавить предмет';

  @override
  String get addLessonTypeTooltip => 'Добавить тип занятия';

  @override
  String get repeatLabel => 'Повтор';

  @override
  String get selectDatesInCalendar => 'Выбрать даты в календаре';

  @override
  String selectedDatesCount(int count) {
    return 'Выбрано: $count дат';
  }

  @override
  String get checkingConflictsMessage => 'Проверка конфликтов...';

  @override
  String willCreateLessons(int count) {
    return 'Будет создано $count занятий';
  }

  @override
  String conflictsWillBeSkipped(int count) {
    return 'Конфликты: $count (будут пропущены)';
  }

  @override
  String createSchedulesCount(int count) {
    return 'Создать $count расписаний';
  }

  @override
  String get createSchedule => 'Создать расписание';

  @override
  String createLessonsCount(int count) {
    return 'Создать $count занятий';
  }

  @override
  String get createLessonSingle => 'Создать занятие';

  @override
  String get minBookingDuration => 'Минимальная длительность брони — 15 минут';

  @override
  String get roomsBooked => 'Кабинеты забронированы';

  @override
  String get invalidTime => 'Некорректно';

  @override
  String get minLessonDuration => 'Минимальная длительность занятия — 15 минут';

  @override
  String permanentSchedulesCreated(int count) {
    return 'Создано $count постоянных расписаний';
  }

  @override
  String get permanentScheduleCreated => 'Постоянное расписание создано';

  @override
  String get allDatesOccupied => 'Все даты заняты';

  @override
  String lessonsCreatedWithSkipped(int created, int skipped) {
    return 'Создано $created занятий (пропущено: $skipped)';
  }

  @override
  String lessonsCreatedCount(int count) {
    return 'Создано $count занятий';
  }

  @override
  String get groupLessonCreated => 'Групповое занятие создано';

  @override
  String get lessonCreatedMessage => 'Занятие создано';

  @override
  String get newGroupTitle => 'Новая группа';

  @override
  String get groupNameLabel => 'Название группы';

  @override
  String get createLabel => 'Создать';

  @override
  String get unknownUser => 'Неизвестный пользователь';

  @override
  String get deletingLabel => 'Удаление...';

  @override
  String get deleteBookingLabel => 'Удалить бронь';

  @override
  String get deleteBookingQuestion => 'Удалить бронь?';

  @override
  String get bookingWillBeDeleted =>
      'Бронирование будет удалено и кабинеты освободятся.';

  @override
  String get bookingDeletedMessage => 'Бронь удалена';

  @override
  String get bookingDeleteError => 'Ошибка при удалении';

  @override
  String get bookRoomsTitle => 'Забронировать кабинеты';

  @override
  String get selectRoomsLabel => 'Выберите кабинеты';

  @override
  String get selectAtLeastOneRoomMessage => 'Выберите хотя бы один кабинет';

  @override
  String get dateTitle => 'Дата';

  @override
  String get startTitle => 'Начало';

  @override
  String get endTitle => 'Окончание';

  @override
  String get descriptionOptionalLabel => 'Описание (необязательно)';

  @override
  String get descriptionExampleHint => 'Например: Репетиция, Мероприятие';

  @override
  String get bookingError => 'Ошибка бронирования';

  @override
  String get permanentScheduleTitle => 'Постоянное расписание';

  @override
  String get notSpecified => 'Не указан';

  @override
  String temporaryRoomReplacement(String room, String date) {
    return 'Временно в кабинете $room до $date';
  }

  @override
  String createLessonOnDate(String date) {
    return 'Создать занятие на $date';
  }

  @override
  String get createLessonsForPeriod => 'Создать занятия на период';

  @override
  String get createMultipleLessons =>
      'Создать несколько занятий из этого слота';

  @override
  String get addException => 'Добавить исключение';

  @override
  String get slotWontWorkOnDate => 'Слот не будет действовать в выбранную дату';

  @override
  String get pauseSlot => 'Приостановить';

  @override
  String get temporarilyDeactivate => 'Временно деактивировать';

  @override
  String get resumeSlot => 'Возобновить';

  @override
  String pausedUntilDate(String date) {
    return 'Приостановлено до $date';
  }

  @override
  String get indefinitePause => 'Бессрочная пауза';

  @override
  String get deactivate => 'Деактивировать';

  @override
  String get completelyDisableSlot => 'Полностью отключить слот';

  @override
  String get addExceptionTitle => 'Добавить исключение';

  @override
  String slotWontWorkMessage(String date) {
    return 'Слот не будет действовать $date.\n\nЭто позволит создать другое занятие в это время.';
  }

  @override
  String get addLabel => 'Добавить';

  @override
  String get exceptionAdded => 'Исключение добавлено';

  @override
  String get pauseUntilLabel => 'Приостановить до';

  @override
  String slotPausedUntil(String date) {
    return 'Слот приостановлен до $date';
  }

  @override
  String get slotResumed => 'Слот возобновлён';

  @override
  String get deactivateSlotTitle => 'Деактивировать слот';

  @override
  String get deactivateSlotMessage =>
      'Слот будет полностью отключён и не будет отображаться в расписании.\n\nВы сможете активировать его снова в карточке ученика.';

  @override
  String get slotDeactivated => 'Слот деактивирован';

  @override
  String get createLessonsForPeriodTitle => 'Создать занятия на период';

  @override
  String studentLabel(String name) {
    return 'Ученик: $name';
  }

  @override
  String get fromDateLabel => 'С даты';

  @override
  String get toDateLabel => 'По дату';

  @override
  String willBeCreated(int count) {
    return 'Будет создано: $count занятий';
  }

  @override
  String get creatingLabel => 'Создание...';

  @override
  String get createLessonsLabel => 'Создать занятия';

  @override
  String get noDatesToCreate => 'Нет дат для создания';

  @override
  String get roomNotSpecified => 'Не указан кабинет';

  @override
  String lessonsCreatedMessage(int count) {
    return 'Создано $count занятий';
  }

  @override
  String seriesLoadError(String error) {
    return 'Ошибка загрузки серии: $error';
  }

  @override
  String get editSeriesTitle => 'Редактировать серию';

  @override
  String get savingLabel => 'Сохранение...';

  @override
  String get applyChangesLabel => 'Применить изменения';

  @override
  String get changesScope => 'Область изменений';

  @override
  String get byWeekdaysLabel => 'По дням недели';

  @override
  String get quantityLabel => 'Количество занятий:';

  @override
  String get allLabel => 'Все';

  @override
  String seriesLessons(int count) {
    return 'Занятия серии ($count)';
  }

  @override
  String get changesTitle => 'Изменения';

  @override
  String willBeChanged(int count) {
    return 'Будет изменено: $count занятий';
  }

  @override
  String get currentLabel => 'текущий';

  @override
  String get noLessonsToUpdate =>
      'Нет занятий для обновления (все имеют конфликты)';

  @override
  String lessonsUpdatedWithSkipped(int updated, int skipped) {
    return 'Обновлено $updated занятий (пропущено: $skipped)';
  }

  @override
  String lessonsUpdatedCount(int count) {
    return 'Обновлено $count занятий';
  }

  @override
  String get memberDataError => 'Не удалось получить данные участника';

  @override
  String get showingAllRooms => 'Отображаются все кабинеты';

  @override
  String roomsSelectedCount(int count) {
    return 'Выбрано кабинетов: $count';
  }

  @override
  String get whichRoomsDoYouUse => 'Какими кабинетами вы пользуетесь?';

  @override
  String get onlySelectedRoomsShown =>
      'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.';

  @override
  String get selectDefaultRooms =>
      'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.';

  @override
  String get skipLabel => 'Пропустить';

  @override
  String saveWithCount(int count) {
    return 'Сохранить ($count)';
  }

  @override
  String get virtualLesson => 'Виртуальное занятие';

  @override
  String completeOnDate(String date) {
    return 'Провести занятие на $date';
  }

  @override
  String get createRealCompleted =>
      'Создать реальное занятие со статусом \"Проведено\"';

  @override
  String cancelOnDate(String date) {
    return 'Отменить занятие на $date';
  }

  @override
  String get createRealCancelled =>
      'Создать реальное занятие со статусом \"Отменено\"';

  @override
  String get skipThisDateLabel => 'Пропустить эту дату';

  @override
  String get addExceptionWithoutLesson =>
      'Добавить исключение без создания занятия';

  @override
  String get pauseSchedule => 'Приостановить расписание';

  @override
  String get temporarilyDeactivateSchedule => 'Временно деактивировать';

  @override
  String get resumeSchedule => 'Возобновить расписание';

  @override
  String get completelyDisableSchedule => 'Полностью отключить расписание';

  @override
  String get schedulePaused => 'Расписание приостановлено';

  @override
  String get scheduleResumed => 'Расписание возобновлено';

  @override
  String get deactivateScheduleTitle => 'Деактивировать расписание';

  @override
  String get deactivateScheduleMessage =>
      'Расписание будет полностью отключено. Это действие можно отменить.';

  @override
  String get scheduleDeactivated => 'Расписание деактивировано';

  @override
  String get deductedFromBalance => 'Списано с баланса';

  @override
  String get lessonDeductedFromBalance => 'Занятие списано с баланса ученика';

  @override
  String get lessonNotDeducted => 'Занятие не списано с баланса';

  @override
  String get completedLabel => 'Проведено';

  @override
  String get paidLabel => 'Оплачено';

  @override
  String get costLabel => 'Стоимость';

  @override
  String get repeatSeriesLabel => 'Повтор';

  @override
  String get yesLabel => 'Да';

  @override
  String get typeLabel => 'Тип';

  @override
  String get statusUpdateError => 'Не удалось обновить статус';

  @override
  String get deductFromBalanceTitle => 'Списать занятие с баланса';

  @override
  String get addGuest => 'Добавить гостя';

  @override
  String get pay => 'Оплатить';

  @override
  String get defaultRooms => 'Кабинеты по умолчанию';

  @override
  String get book => 'Забронировать';

  @override
  String get deleteBookingMessage =>
      'Бронирование будет удалено и кабинеты освободятся.';

  @override
  String get endLabel => 'Окончание';

  @override
  String get createMultipleLessonsFromSlot =>
      'Создать несколько занятий из этого слота';

  @override
  String get slotWillNotWorkOnDate =>
      'Слот не будет действовать в выбранную дату';

  @override
  String get pause => 'Приостановить';

  @override
  String get temporarilyDeactivateSlot => 'Временно деактивировать слот';

  @override
  String get resume => 'Возобновить';

  @override
  String get deactivateSlot => 'Деактивировать слот';

  @override
  String get oneMonth => '1 месяц';

  @override
  String get threeMonths => '3 месяца';

  @override
  String get sixMonths => '6 месяцев';

  @override
  String get oneYear => '1 год';

  @override
  String get createCompletedLesson =>
      'Создать реальное занятие со статусом \"Проведено\"';

  @override
  String get createCancelledLesson =>
      'Создать реальное занятие со статусом \"Отменено\"';

  @override
  String get deactivateSchedule => 'Деактивировать расписание';

  @override
  String get scheduleWillBeDisabled =>
      'Расписание будет полностью отключено. Это действие можно отменить.';

  @override
  String get permissionsSaved => 'Права сохранены';

  @override
  String get permissionSectionInstitution => 'Управление заведением';

  @override
  String get permissionManageInstitution => 'Изменение заведения';

  @override
  String get permissionManageInstitutionDesc => 'Изменение названия, настроек';

  @override
  String get permissionManageMembers => 'Управление участниками';

  @override
  String get permissionManageMembersDesc =>
      'Добавление, удаление, изменение прав';

  @override
  String get permissionArchiveData => 'Архивация данных';

  @override
  String get permissionArchiveDataDesc => 'Архивация учеников, групп';

  @override
  String get permissionSectionReferences => 'Справочники';

  @override
  String get permissionManageRooms => 'Управление кабинетами';

  @override
  String get permissionManageRoomsDesc => 'Создание, редактирование, удаление';

  @override
  String get permissionManageSubjects => 'Управление предметами';

  @override
  String get permissionManageSubjectsDesc =>
      'Создание, редактирование, удаление';

  @override
  String get permissionManageLessonTypes => 'Управление типами занятий';

  @override
  String get permissionManageLessonTypesDesc =>
      'Создание, редактирование, удаление';

  @override
  String get permissionManagePaymentPlans => 'Управление тарифами';

  @override
  String get permissionManagePaymentPlansDesc =>
      'Создание, редактирование, удаление';

  @override
  String get permissionSectionStudents => 'Ученики и группы';

  @override
  String get permissionManageOwnStudents => 'Управление своими учениками';

  @override
  String get permissionManageOwnStudentsDesc =>
      'Создание, редактирование своих учеников';

  @override
  String get permissionManageAllStudents => 'Управление всеми учениками';

  @override
  String get permissionManageAllStudentsDesc =>
      'Управление учениками других преподавателей';

  @override
  String get permissionManageGroups => 'Управление группами';

  @override
  String get permissionManageGroupsDesc => 'Создание, редактирование групп';

  @override
  String get permissionSectionSchedule => 'Расписание';

  @override
  String get permissionViewAllSchedule => 'Просмотр всего расписания';

  @override
  String get permissionViewAllScheduleDesc =>
      'Просмотр занятий других преподавателей';

  @override
  String get permissionCreateLessons => 'Создание занятий';

  @override
  String get permissionCreateLessonsDesc =>
      'Добавление новых занятий в расписание';

  @override
  String get permissionEditOwnLessons => 'Редактирование своих занятий';

  @override
  String get permissionEditOwnLessonsDesc => 'Изменение своих занятий';

  @override
  String get permissionEditAllLessons => 'Редактирование всех занятий';

  @override
  String get permissionEditAllLessonsDesc =>
      'Изменение занятий других преподавателей';

  @override
  String get permissionDeleteOwnLessons => 'Удаление своих занятий';

  @override
  String get permissionDeleteOwnLessonsDesc =>
      'Удаление своих занятий из расписания';

  @override
  String get permissionDeleteAllLessons => 'Удаление всех занятий';

  @override
  String get permissionDeleteAllLessonsDesc =>
      'Удаление занятий других преподавателей';

  @override
  String get permissionSectionFinance => 'Финансы';

  @override
  String get permissionViewOwnStudentsPayments =>
      'Просмотр оплат своих учеников';

  @override
  String get permissionViewOwnStudentsPaymentsDesc =>
      'Просмотр платежей своих учеников';

  @override
  String get permissionViewAllPayments => 'Просмотр всех оплат';

  @override
  String get permissionViewAllPaymentsDesc => 'Просмотр платежей всех учеников';

  @override
  String get permissionAddPaymentsForOwnStudents =>
      'Добавление оплат своим ученикам';

  @override
  String get permissionAddPaymentsForOwnStudentsDesc =>
      'Принятие оплат от своих учеников';

  @override
  String get permissionAddPaymentsForAllStudents =>
      'Добавление оплат всем ученикам';

  @override
  String get permissionAddPaymentsForAllStudentsDesc =>
      'Принятие оплат от любых учеников';

  @override
  String get permissionManageOwnStudentsPayments =>
      'Редактирование оплат своих учеников';

  @override
  String get permissionManageOwnStudentsPaymentsDesc =>
      'Изменение и удаление оплат своих учеников';

  @override
  String get permissionManageAllPayments => 'Редактирование всех оплат';

  @override
  String get permissionManageAllPaymentsDesc =>
      'Изменение и удаление любых оплат';

  @override
  String get permissionViewStatistics => 'Просмотр статистики';

  @override
  String get permissionViewStatisticsDesc => 'Доступ к разделу статистики';

  @override
  String get statusSection => 'СТАТУС';

  @override
  String get adminHasAllPermissions => 'Администратор';

  @override
  String get grantFullPermissions => 'Предоставить все права';

  @override
  String get allPermissionsEnabledForAdmin => 'Включено для администратора';

  @override
  String get welcome => 'Добро пожаловать!';

  @override
  String get selectColorForLessons =>
      'Выберите цвет для отображения\nваших занятий в расписании';

  @override
  String get yourDirections => 'Ваши направления';

  @override
  String get selectSubjectsYouTeach => 'Выберите предметы, которые вы ведёте';

  @override
  String get noSubjectsInInstitution => 'В заведении пока нет предметов';

  @override
  String get ownerCanAddInSettings => 'Владелец может добавить их в настройках';

  @override
  String get noPaymentPlans => 'Нет тарифов';

  @override
  String get addFirstPaymentPlan => 'Добавьте первый тариф оплаты';

  @override
  String get addPlan => 'Добавить тариф';

  @override
  String get addPaymentPlan => 'Добавить тариф';

  @override
  String get paymentPlanNameHint => 'Например: Абонемент на 8 занятий';

  @override
  String get enterNameField => 'Введите название';

  @override
  String get lessonsRequired => 'Занятий *';

  @override
  String get invalidValueError => 'Некорректное значение';

  @override
  String get createPaymentPlan => 'Создать тариф';

  @override
  String get deletePaymentPlanQuestion => 'Удалить тариф?';

  @override
  String paymentPlanWillBeDeleted(String name) {
    return 'Тариф \"$name\" будет удалён';
  }

  @override
  String get paymentPlanDeleted => 'Тариф удалён';

  @override
  String paymentPlanCreated(String name) {
    return 'Тариф \"$name\" создан';
  }

  @override
  String get newPaymentPlan => 'Новый тариф';

  @override
  String get fillPaymentPlanData => 'Заполните данные тарифа';

  @override
  String get planNameHint => 'Например: Абонемент на 8 занятий';

  @override
  String get lessonsCountRequired => 'Занятий *';

  @override
  String get priceRequired => 'Цена *';

  @override
  String get validityDaysRequired => 'Срок действия (дней) *';

  @override
  String get enterValidityDays => 'Введите срок';

  @override
  String get createPlan => 'Создать тариф';

  @override
  String get paymentPlanUpdated => 'Тариф обновлён';

  @override
  String get editPaymentPlan => 'Редактировать тариф';

  @override
  String get changePaymentPlanData => 'Измените данные тарифа';

  @override
  String pricePerLesson(String price) {
    return '$price ₸/занятие';
  }

  @override
  String validityDaysShort(int days) {
    return '$days дн.';
  }

  @override
  String get noSubjects => 'Нет предметов';

  @override
  String get addFirstSubject => 'Добавьте первый предмет';

  @override
  String get deleteSubjectQuestion => 'Удалить предмет?';

  @override
  String subjectWillBeDeleted(String name) {
    return 'Предмет \"$name\" будет удалён';
  }

  @override
  String get subjectDeleted => 'Предмет удалён';

  @override
  String subjectCreated(String name) {
    return 'Предмет \"$name\" создан';
  }

  @override
  String get newSubject => 'Новый предмет';

  @override
  String get fillSubjectData => 'Введите название предмета';

  @override
  String get addSubject => 'Добавить предмет';

  @override
  String get createSubject => 'Создать предмет';

  @override
  String get enterSubjectName => 'Введите название предмета';

  @override
  String get subjectNameRequired => 'Название *';

  @override
  String get subjectUpdated => 'Предмет обновлён';

  @override
  String get editSubject => 'Редактировать предмет';

  @override
  String get changeSubjectData => 'Измените данные предмета';

  @override
  String get noAccessToStatistics => 'Нет доступа к статистике';

  @override
  String get statisticsNoAccess => 'Нет доступа к статистике';

  @override
  String get statsTabGeneral => 'Общая';

  @override
  String get statsTotal => 'Занятия';

  @override
  String get statsFinances => 'Финансы';

  @override
  String get statsAvgLessonApprox => '≈';

  @override
  String get statsAvgLesson => 'Ср. занятие';

  @override
  String get statsDiscounts => 'Скидки';

  @override
  String statsPaidLessonsOf(int paid, int total) {
    return '$paid из $total';
  }

  @override
  String statsPaymentsWithDiscount(int count) {
    return '$count со скидкой';
  }

  @override
  String get statsWorkload => 'Загруженность';

  @override
  String get statsLessonHours => 'Часов занятий';

  @override
  String get statsActiveStudents => 'Активных учеников';

  @override
  String get statsPaymentMethods => 'Способы оплаты';

  @override
  String statsCardPayments(int count, String percent) {
    return 'Карта ($count) — $percent%';
  }

  @override
  String statsCashPayments(int count, String percent) {
    return 'Наличные ($count) — $percent%';
  }

  @override
  String get statsAvgLessonShort => 'Ср.:';

  @override
  String get statsLessonStats => 'Статистика занятий';

  @override
  String get contactOwner => 'Обратитесь к владельцу заведения';

  @override
  String get tabGeneral => 'Общая';

  @override
  String get tabSubjects => 'Предметы';

  @override
  String get tabTeachers => 'Преподаватели';

  @override
  String get tabStudents => 'Ученики';

  @override
  String get tabPlans => 'Тарифы';

  @override
  String get lessonsTotal => 'Всего';

  @override
  String get lessonsScheduled => 'Запланировано';

  @override
  String get paymentsLabel => 'Оплаты';

  @override
  String get avgLesson => 'Ср. занятие';

  @override
  String get discounts => 'Скидки';

  @override
  String get workload => 'Загруженность';

  @override
  String get hoursOfLessons => 'Часов занятий';

  @override
  String get activeStudentsCount => 'Активных учеников';

  @override
  String get paymentMethodCard => 'Карта';

  @override
  String get paymentMethodCash => 'Наличные';

  @override
  String get noDataForPeriod => 'Нет данных за период';

  @override
  String get lessonStatistics => 'Статистика занятий';

  @override
  String get cancellationRate => 'Процент отмен';

  @override
  String get topByLessons => 'Топ по занятиям';

  @override
  String get lessonsShort => 'зан.';

  @override
  String get byStudents => 'По ученикам';

  @override
  String get purchases => 'Покупок';

  @override
  String get sumLabel => 'Сумма';

  @override
  String get avgLessonCost => 'Средняя стоимость занятия';

  @override
  String get paymentsWithDiscount => 'Оплаты со скидкой';

  @override
  String get discountSum => 'Сумма скидок';

  @override
  String get byPlans => 'По тарифам';

  @override
  String get purchasesShort => 'покуп.';

  @override
  String cancellationRatePercent(String rate) {
    return 'Процент отмен: $rate%';
  }

  @override
  String get paymentMethods => 'Способы оплаты';

  @override
  String cardPaymentsCount(int count) {
    return 'Карта ($count)';
  }

  @override
  String cashPaymentsCount(int count) {
    return 'Наличные ($count)';
  }

  @override
  String lessonsCountShort(int count) {
    return '$count зан.';
  }

  @override
  String mergeStudentsCount(int count) {
    return 'Объединить $count учеников';
  }

  @override
  String mergeStudentsTitle(int count) {
    return 'Объединить $count учеников';
  }

  @override
  String get mergeStudentsWarning =>
      'Будет создана новая карточка. Исходные карточки будут архивированы.';

  @override
  String get fromLegacyBalance => 'Из остатка';

  @override
  String cardCreatedWithName(String name) {
    return 'Создана карточка \"$name\"';
  }

  @override
  String get mergeWarning =>
      'Будет создана новая карточка. Исходные карточки будут архивированы.';

  @override
  String get studentsToMerge => 'Объединяемые ученики';

  @override
  String get totalBalance => 'Общий баланс';

  @override
  String get fromLegacy => 'Из остатка';

  @override
  String get newCardData => 'Данные новой карточки';

  @override
  String get merge => 'Объединить';

  @override
  String cardCreated(String name) {
    return 'Создана карточка \"$name\"';
  }

  @override
  String get mergeError => 'Ошибка при объединении';

  @override
  String get lessonTime => 'Время занятия';

  @override
  String get invalid => 'Некорректно';

  @override
  String durationFormat(int hours, int mins) {
    return '$hours ч $mins мин';
  }

  @override
  String hoursOnly(int hours) {
    return '$hours ч';
  }

  @override
  String minutesOnly(int mins) {
    return '$mins мин';
  }

  @override
  String get quickSelect => 'Быстрый выбор';

  @override
  String get palette => 'Палитра';

  @override
  String get unarchive => 'Разархивировать';

  @override
  String get deleteForever => 'Удалить навсегда';

  @override
  String get studentInArchive => 'Ученик в архиве';

  @override
  String get unarchiveToCreateLessons =>
      'Разархивируйте, чтобы создавать занятия';

  @override
  String get contactInfo => 'Контактная информация';

  @override
  String get noPhone => 'Телефон не указан';

  @override
  String get phoneCopied => 'Телефон скопирован';

  @override
  String get lessonStatisticsTitle => 'Статистика занятий';

  @override
  String get noLessonsYet => 'Нет занятий';

  @override
  String get balance => 'Баланс';

  @override
  String get subscriptionsSection => 'Абонементы';

  @override
  String get noActiveSubscriptions => 'Нет активных абонементов';

  @override
  String get paymentsSection => 'Оплаты';

  @override
  String get noPaymentsHistory => 'Нет истории оплат';

  @override
  String showMoreCount(int count) {
    return 'Показать ещё ($count)';
  }

  @override
  String get permanentScheduleSection => 'Постоянное расписание';

  @override
  String get noPermanentSchedule => 'Нет постоянного расписания';

  @override
  String get addScheduleSlot => 'Добавить слот';

  @override
  String get createLessonsFromSchedule => 'Создать занятия из расписания';

  @override
  String get repeatGroupsSection => 'Серии занятий';

  @override
  String get noRepeatGroups => 'Нет серий занятий';

  @override
  String get lessonHistorySection => 'История занятий';

  @override
  String get manageLessonsTitle => 'Управление занятиями';

  @override
  String get archivedSection => 'Архивированные';

  @override
  String get archived => 'Архивировано';

  @override
  String inRoom(String room) {
    return 'в каб. $room';
  }

  @override
  String temporaryRoomUntil(String room, String date) {
    return 'Временно $room до $date';
  }

  @override
  String schedulePausedUntil(String date) {
    return 'Приостановлено до $date';
  }

  @override
  String get resumeScheduleAction => 'Возобновить';

  @override
  String get pauseScheduleAction => 'Приостановить';

  @override
  String get clearReplacementRoom => 'Снять замену кабинета';

  @override
  String get temporaryRoomReplacementAction => 'Временная замена кабинета';

  @override
  String get archiveSchedule => 'Архивировать';

  @override
  String get unarchiveSchedule => 'Разархивировать';

  @override
  String get deleteScheduleAction => 'Удалить';

  @override
  String get scheduleResumedMessage => 'Расписание возобновлено';

  @override
  String get pauseScheduleTitle => 'Приостановить расписание';

  @override
  String get pauseScheduleUntilQuestion => 'До какой даты приостановить?';

  @override
  String get resumeDate => 'Дата возобновления';

  @override
  String get selectDatePlaceholder => 'Выберите дату';

  @override
  String get pauseAction => 'Приостановить';

  @override
  String schedulePausedUntilMessage(String date) {
    return 'Расписание приостановлено до $date';
  }

  @override
  String get replacementRoomCleared => 'Замена кабинета снята';

  @override
  String get temporaryRoomReplacementTitle => 'Временная замена кабинета';

  @override
  String get untilDateLabel => 'До какой даты';

  @override
  String get replacementRoomSet => 'Замена кабинета установлена';

  @override
  String get archiveScheduleQuestion => 'Архивировать расписание?';

  @override
  String get archiveScheduleMessage =>
      'Слот будет перемещён в архив. Вы сможете разархивировать его позже.';

  @override
  String get scheduleArchivedMessage => 'Расписание архивировано';

  @override
  String get scheduleUnarchivedMessage => 'Расписание разархивировано';

  @override
  String get deleteScheduleQuestion => 'Удалить расписание?';

  @override
  String get deleteScheduleMessage =>
      'Этот слот будет удалён навсегда. Это действие нельзя отменить.';

  @override
  String get scheduleDeletedMessage => 'Расписание удалено';

  @override
  String get editScheduleTitle => 'Редактировать расписание';

  @override
  String get startTimeLabel => 'Время начала';

  @override
  String get endTimeLabel => 'Время окончания';

  @override
  String get roomFieldLabel => 'Кабинет';

  @override
  String get scheduleUpdatedMessage => 'Расписание обновлено';

  @override
  String get scheduleUpdateError =>
      'Ошибка обновления (возможно конфликт времени)';

  @override
  String lessonsInSeries(int count) {
    return '$count занятий в серии';
  }

  @override
  String seriesStartDate(String date) {
    return 'Начало: $date';
  }

  @override
  String get editAction => 'Редактировать';

  @override
  String get deleteSeriesAction => 'Удалить серию';

  @override
  String get editSeriesSheetTitle => 'Редактировать серию';

  @override
  String get deleteSeriesQuestion => 'Удалить серию?';

  @override
  String deleteSeriesMessage(int count) {
    return 'Будет удалено $count занятий из расписания. Это действие нельзя отменить.';
  }

  @override
  String get seriesDeleted => 'Серия удалена';

  @override
  String get deletionError => 'Ошибка удаления';

  @override
  String get seriesUpdated => 'Серия обновлена';

  @override
  String get updateError => 'Ошибка обновления';

  @override
  String get createLessonsFromScheduleTitle => 'Создать занятия из расписания';

  @override
  String get createLessonsDescription =>
      'Будут созданы занятия на основе постоянного расписания ученика.';

  @override
  String get fromDateField => 'С даты';

  @override
  String get toDateField => 'По дату';

  @override
  String get oneWeek => '1 неделя';

  @override
  String get twoWeeks => '2 недели';

  @override
  String get checkConflicts => 'Проверить конфликты';

  @override
  String get noConflictsMessage => 'Конфликтов не найдено';

  @override
  String conflictsFoundCount(int count) {
    return 'Найдено конфликтов: $count';
  }

  @override
  String get datesWillBeSkipped => 'Эти даты будут пропущены:';

  @override
  String andMoreCount(int count) {
    return '...и ещё $count';
  }

  @override
  String get createLessonsAction => 'Создать занятия';

  @override
  String get creatingLessons => 'Создание...';

  @override
  String lessonsCreatedSkipped(int success, int skipped) {
    return 'Создано занятий: $success, пропущено: $skipped';
  }

  @override
  String get addPermanentScheduleTitle => 'Добавить постоянное расписание';

  @override
  String get selectDaysAndTimeDescription =>
      'Выберите дни недели и время занятий';

  @override
  String get daysOfWeek => 'Дни недели';

  @override
  String get timeAndRooms => 'Время и кабинеты';

  @override
  String get validFromField => 'Действует с';

  @override
  String get teacherRequired => 'Преподаватель *';

  @override
  String get selectTeacherValidation => 'Выберите преподавателя';

  @override
  String get subjectOptional => 'Предмет (опционально)';

  @override
  String get notSpecifiedOption => 'Не указано';

  @override
  String get lessonTypeOptional => 'Тип занятия (опционально)';

  @override
  String get checkingConflictsStatus => 'Проверка конфликтов...';

  @override
  String conflictsCountChange(int count) {
    return 'Конфликты: $count (измените время)';
  }

  @override
  String get hasConflicts => 'Есть конфликты';

  @override
  String get selectRoomsValidation => 'Выберите кабинеты';

  @override
  String createSchedulesCountAction(int count) {
    return 'Создать $count занятий';
  }

  @override
  String get createScheduleAction => 'Создать расписание';

  @override
  String get selectAtLeastOneDayValidation =>
      'Выберите хотя бы один день недели';

  @override
  String get selectRoomForEachDayValidation =>
      'Выберите кабинет для каждого дня';

  @override
  String schedulesCreatedCount(int count) {
    return 'Создано $count записей расписания';
  }

  @override
  String get scheduleCreated => 'Расписание создано';

  @override
  String get conflictTimeMessage => 'Конфликт! Время занято';

  @override
  String get manageLessonsSection => 'Управление занятиями';

  @override
  String futureLessonsFound(int count) {
    return 'Найдено $count будущих занятий';
  }

  @override
  String get noScheduledLessonsMessage => 'Нет запланированных занятий';

  @override
  String loadingErrorMessage(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get reassignTeacherTitle => 'Переназначить преподавателя';

  @override
  String get reassignTeacherSubtitle =>
      'Выбрать нового преподавателя для всех занятий';

  @override
  String get deleteAllFutureLessonsTitle => 'Удалить все занятия';

  @override
  String get deleteAllFutureLessonsSubtitle =>
      'Баланс абонементов не изменится';

  @override
  String get deleteAllLessonsQuestion => 'Удалить все занятия?';

  @override
  String deleteAllLessonsMessage(int count, String name) {
    return 'Вы уверены, что хотите удалить $count будущих занятий \"$name\"?\n\nБаланс абонементов не изменится.';
  }

  @override
  String deletedLessonsCount(int count) {
    return 'Удалено $count занятий';
  }

  @override
  String get noAvailableTeachersMessage => 'Нет доступных преподавателей';

  @override
  String get selectTeacherTitle => 'Выберите преподавателя';

  @override
  String reassignedSlotsCount(int count) {
    return 'Переназначено $count слотов';
  }

  @override
  String pausedSlotsCount(int count) {
    return 'Приостановлено $count слотов';
  }

  @override
  String get deactivateScheduleQuestion => 'Деактивировать расписание?';

  @override
  String deactivateSlotsMessage(int count) {
    return 'Деактивировать $count слотов постоянного расписания?\n\nСлоты останутся в архиве и могут быть восстановлены.';
  }

  @override
  String get deactivateAction => 'Деактивировать';

  @override
  String deactivatedSlotsCount(int count) {
    return 'Деактивировано $count слотов';
  }

  @override
  String scheduleSlotsDays(int count, String slots) {
    return '$count $slots';
  }

  @override
  String get slotWord => 'слот';

  @override
  String get slotsWordFew => 'слота';

  @override
  String get slotsWordMany => 'слотов';

  @override
  String get pauseAllSlots => 'Приостановить';

  @override
  String get pauseAllSlotsSubtitle => 'Временно приостановить все слоты';

  @override
  String get deactivateAllSlots => 'Деактивировать';

  @override
  String get deactivateAllSlotsSubtitle => 'Отключить постоянное расписание';

  @override
  String get newTeacherLabel => 'Новый преподаватель';

  @override
  String allLessonsCanBeReassigned(int count) {
    return 'Все $count занятий можно переназначить';
  }

  @override
  String canReassignCount(int count) {
    return 'Можно переназначить: $count занятий';
  }

  @override
  String reassignCount(int count) {
    return 'Переназначить $count занятий';
  }

  @override
  String get reassignAllLessons => 'Переназначить все занятия';

  @override
  String get noCompletedLessons => 'Нет завершённых занятий';

  @override
  String get noSubjectLabel => 'Без предмета';

  @override
  String get showMore => 'Показать ещё';

  @override
  String get editStudentTitle => 'Редактировать';

  @override
  String get basicInfoSection => 'Основная информация';

  @override
  String get fullNameField => 'ФИО';

  @override
  String get phoneField => 'Телефон';

  @override
  String get commentField => 'Комментарий';

  @override
  String get legacyBalanceSection => 'Остаток занятий';

  @override
  String get currentBalance => 'Текущий остаток';

  @override
  String balanceLessonsCount(int count) {
    return '$count занятий';
  }

  @override
  String get changeBalance => 'Изменить';

  @override
  String get changeBalanceTitle => 'Изменить остаток';

  @override
  String get quantityField => 'Количество';

  @override
  String get quantityHint => '+5 или -3';

  @override
  String get reasonOptional => 'Причина (опционально)';

  @override
  String get applyAction => 'Применить';

  @override
  String get saveChangesAction => 'Сохранить изменения';

  @override
  String lessonsAddedCount(int count) {
    return 'Добавлено $count занятий';
  }

  @override
  String lessonsDeductedCount(int count) {
    return 'Списано $count занятий';
  }

  @override
  String get addLessonsTitle => 'Добавить занятия';

  @override
  String legacyBalanceLabel(int count) {
    return 'Остаток занятий: $count';
  }

  @override
  String get lessonsQuantityField => 'Количество занятий';

  @override
  String get quantityPlaceholder => 'Положительное или отрицательное число';

  @override
  String get enterQuantity => 'Введите количество';

  @override
  String get enterInteger => 'Введите целое число';

  @override
  String get quantityCannotBeZero => 'Количество не может быть 0';

  @override
  String get commentOptionalField => 'Комментарий (необязательно)';

  @override
  String get commentHint => 'Например: Перенос с другого абонемента';

  @override
  String get archiveStudentQuestion => 'Архивировать ученика?';

  @override
  String archiveStudentMessage(String name) {
    return 'Ученик \"$name\" будет перемещён в архив. Вы сможете восстановить его позже.';
  }

  @override
  String get restoreStudentQuestion => 'Восстановить ученика?';

  @override
  String restoreStudentMessage(String name) {
    return 'Ученик \"$name\" будет восстановлен из архива.';
  }

  @override
  String get deleteStudentQuestion => 'Удалить ученика навсегда?';

  @override
  String deleteStudentMessage(String name) {
    return 'Ученик \"$name\" будет удалён навсегда вместе со всеми данными (занятия, оплаты, абонементы).\n\nЭто действие НЕЛЬЗЯ отменить!';
  }

  @override
  String get teacherDefault => 'Преподаватель';

  @override
  String get unknownName => 'Неизвестный';

  @override
  String get roomDefault => 'Кабинет';

  @override
  String get checking => 'Проверка...';

  @override
  String get freezeSubscription => 'Заморозить абонемент';

  @override
  String get freezeSubscriptionDescription =>
      'При заморозке срок действия абонемента приостанавливается. После разморозки срок будет продлён на количество дней заморозки.';

  @override
  String get daysCount => 'Количество дней';

  @override
  String get enterQuantityValidation => 'Введите количество';

  @override
  String get enterNumberFrom1To90 => 'Введите число от 1 до 90';

  @override
  String get freeze => 'Заморозить';

  @override
  String get subscriptionFrozen => 'Абонемент заморожен';

  @override
  String subscriptionUnfrozen(String date) {
    return 'Абонемент разморожен. Срок продлён до $date';
  }

  @override
  String get extendSubscription => 'Продлить срок';

  @override
  String currentTermUntil(String date) {
    return 'Текущий срок: до $date';
  }

  @override
  String get extendForDays => 'Продлить на дней';

  @override
  String get enterNumberFrom1To365 => 'Введите число от 1 до 365';

  @override
  String get extend => 'Продлить';

  @override
  String termExtendedUntil(String date) {
    return 'Срок продлён до $date';
  }

  @override
  String subscriptionBalanceLabel(int count) {
    return 'Абонементы: $count';
  }

  @override
  String legacyBalanceShort(int count) {
    return 'Остаток: $count';
  }

  @override
  String get addLessonsAction => 'Добавить занятия';

  @override
  String get avgCost => 'СР. СТОИМОСТЬ';

  @override
  String get avgCostApprox => 'СР. СТОИМОСТЬ ≈';

  @override
  String get noDataAvailable => 'нет данных';

  @override
  String get perLesson => 'за занятие';

  @override
  String get manageLessonsAction => 'Управление';

  @override
  String get conductedLabel => 'Проведено';

  @override
  String get cancelledLabel => 'Отменено';

  @override
  String get discountLabel => 'Скидка';

  @override
  String get correctionLabel => 'Корр.';

  @override
  String get legacyBalanceTitle => 'Остаток занятий';

  @override
  String get exhaustedStatus => 'Исчерпан';

  @override
  String get expiringSoon => 'Скоро истекает';

  @override
  String get groupSubscription => 'Групповой';

  @override
  String frozenUntilDate(String date) {
    return 'Заморожен до $date';
  }

  @override
  String expiredDate(String date) {
    return 'Истёк $date';
  }

  @override
  String validUntilDate(String date) {
    return 'Действует до $date';
  }

  @override
  String get unfreezeAction => 'Разморозить';

  @override
  String get teachersSection => 'Преподаватели';

  @override
  String get addTeacherTooltip => 'Добавить преподавателя';

  @override
  String get noLinkedTeachers => 'Нет привязанных преподавателей';

  @override
  String get addTeacherTitle => 'Добавить преподавателя';

  @override
  String get allTeachersAdded => 'Все преподаватели уже добавлены';

  @override
  String get teacherAdded => 'Преподаватель добавлен';

  @override
  String get removeTeacherQuestion => 'Удалить преподавателя?';

  @override
  String get removeTeacherMessage =>
      'Преподаватель будет отвязан от этого ученика.';

  @override
  String get teacherRemoved => 'Преподаватель удалён';

  @override
  String get subjectsSection => 'Предметы';

  @override
  String get noLinkedSubjects => 'Нет привязанных предметов';

  @override
  String get addSubjectTitle => 'Добавить предмет';

  @override
  String get allSubjectsAdded => 'Все предметы уже добавлены';

  @override
  String get subjectAdded => 'Предмет добавлен';

  @override
  String get removeSubjectQuestion => 'Удалить предмет?';

  @override
  String get removeSubjectMessage => 'Предмет будет отвязан от этого ученика.';

  @override
  String get subjectRemoved => 'Предмет удалён';

  @override
  String get lessonTypesSection => 'Типы занятий';

  @override
  String get noLinkedLessonTypes => 'Нет привязанных типов занятий';

  @override
  String get addLessonTypeTitle => 'Добавить тип занятия';

  @override
  String get allLessonTypesAdded => 'Все типы занятий уже добавлены';

  @override
  String get lessonTypeAdded => 'Тип занятия добавлен';

  @override
  String get removeLessonTypeQuestion => 'Удалить тип занятия?';

  @override
  String get removeLessonTypeMessage =>
      'Тип занятия будет отвязан от этого ученика.';

  @override
  String get lessonTypeRemoved => 'Тип занятия удалён';

  @override
  String get mergeWithAction => 'Объединить с...';

  @override
  String selectStudentsToMerge(String name) {
    return 'Выберите учеников для объединения с \"$name\"';
  }

  @override
  String get searchStudentsHint => 'Поиск учеников...';

  @override
  String get noStudentsToMerge => 'Нет учеников для объединения';

  @override
  String balanceValue(int count) {
    return 'Баланс: $count';
  }

  @override
  String get selectStudentsValidation => 'Выберите учеников';

  @override
  String nextWithCount(int count) {
    return 'Далее ($count)';
  }

  @override
  String get groupCard => 'Групповая карточка';

  @override
  String get failedToLoadNames => 'Не удалось загрузить имена';

  @override
  String archiveSlots(int count) {
    return 'Архив ($count)';
  }

  @override
  String get replacementRoom => 'Замена';

  @override
  String pauseUntilDateFormat(String date) {
    return 'Пауза до $date';
  }

  @override
  String get onPause => 'На паузе';

  @override
  String get mondayShort2 => 'Пн';

  @override
  String get tuesdayShort2 => 'Вт';

  @override
  String get wednesdayShort2 => 'Ср';

  @override
  String get thursdayShort2 => 'Чт';

  @override
  String get fridayShort2 => 'Пт';

  @override
  String get saturdayShort2 => 'Сб';

  @override
  String get sundayShort2 => 'Вс';

  @override
  String get mondayFull => 'Понедельник';

  @override
  String get tuesdayFull => 'Вторник';

  @override
  String get wednesdayFull => 'Среда';

  @override
  String get thursdayFull => 'Четверг';

  @override
  String get fridayFull => 'Пятница';

  @override
  String get saturdayFull => 'Суббота';

  @override
  String get sundayFull => 'Воскресенье';

  @override
  String seriesStartDateLabel(String date) {
    return 'Начало: $date';
  }

  @override
  String get editSeriesAction => 'Редактировать';

  @override
  String deleteSeriesLessons(int count) {
    return 'Будет удалено $count занятий из расписания. Это действие нельзя отменить.';
  }

  @override
  String get saveSeries => 'Сохранить';

  @override
  String get invalidTimeError => 'Некорректно';

  @override
  String get roomFieldHint => 'Кабинет';

  @override
  String get pauseScheduleUntilDate => 'До какой даты приостановить?';

  @override
  String get resumeDateLabel => 'Дата возобновления';

  @override
  String get selectDateHint => 'Выберите дату';

  @override
  String get pauseUntilMessage => 'Приостановить до';

  @override
  String get selectRoomLabel => 'Новый кабинет';

  @override
  String get untilDateQuestion => 'До какой даты';

  @override
  String get applyRoomReplacement => 'Применить';

  @override
  String get archiveScheduleConfirm =>
      'Слот будет перемещён в архив. Вы сможете разархивировать его позже.';

  @override
  String get deleteScheduleConfirm =>
      'Этот слот будет удалён навсегда. Это действие нельзя отменить.';

  @override
  String errorWithParam(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get createLessonsFromScheduleDescription =>
      'Будут созданы занятия на основе постоянного расписания ученика.';

  @override
  String get toDateLabel2 => 'По дату';

  @override
  String get checkConflictsAction => 'Проверить конфликты';

  @override
  String get noConflictsFoundMessage => 'Конфликтов не найдено';

  @override
  String conflictsCountMessage(int count) {
    return 'Найдено конфликтов: $count';
  }

  @override
  String get datesWillBeSkippedMessage => 'Эти даты будут пропущены:';

  @override
  String andMoreLabel(int count) {
    return '...и ещё $count';
  }

  @override
  String get creatingMessage => 'Создание...';

  @override
  String lessonsCreatedResult(int count) {
    return 'Создано занятий: $count';
  }

  @override
  String get addPermanentScheduleDescription =>
      'Выберите дни недели и время занятий';

  @override
  String get timeAndRoomsLabel => 'Время и кабинеты';

  @override
  String get validFromLabel => 'Действует с';

  @override
  String get teacherRequiredLabel => 'Преподаватель *';

  @override
  String get selectTeacherError => 'Выберите преподавателя';

  @override
  String get subjectOptionalLabel => 'Предмет (опционально)';

  @override
  String get notSpecifiedLabel => 'Не указано';

  @override
  String get lessonTypeOptionalLabel => 'Тип занятия (опционально)';

  @override
  String conflictsChangeTime(int count) {
    return 'Конфликты: $count (измените время)';
  }

  @override
  String get hasConflictsError => 'Есть конфликты';

  @override
  String get selectRoomsError => 'Выберите кабинеты';

  @override
  String get checkingLabel => 'Проверка...';

  @override
  String createCountSchedules(int count) {
    return 'Создать $count занятий';
  }

  @override
  String get createScheduleLabel => 'Создать расписание';

  @override
  String get selectAtLeastOneDay => 'Выберите хотя бы один день недели';

  @override
  String get selectRoomForEachDay => 'Выберите кабинет для каждого дня';

  @override
  String get scheduleCreatedMessage => 'Расписание создано';

  @override
  String schedulesCreatedMessage(int count) {
    return 'Создано $count записей расписания';
  }

  @override
  String get conflictTimeOccupiedMessage => 'Конфликт! Время занято';

  @override
  String deleteAllLessonsConfirm(int count, String name) {
    return 'Вы уверены, что хотите удалить $count будущих занятий \"$name\"?\n\nБаланс абонементов не изменится.';
  }

  @override
  String deletedCountLessons(int count) {
    return 'Удалено $count занятий';
  }

  @override
  String get noAvailableTeachersError => 'Нет доступных преподавателей';

  @override
  String get selectTeacherLabel => 'Выберите преподавателя';

  @override
  String get noNameLabel => 'Без имени';

  @override
  String reassignedSlotsMessage(int count) {
    return 'Переназначено $count слотов';
  }

  @override
  String pausedSlotsMessage(int count) {
    return 'Приостановлено $count слотов';
  }

  @override
  String deactivateScheduleConfirm(int count) {
    return 'Деактивировать $count слотов постоянного расписания?\n\nСлоты останутся в архиве и могут быть восстановлены.';
  }

  @override
  String deactivatedSlotsMessage(int count) {
    return 'Деактивировано $count слотов';
  }

  @override
  String get manageLessonsHeader => 'Управление занятиями';

  @override
  String loadingErrorLabel(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get noScheduledLessonsLabel => 'Нет запланированных занятий';

  @override
  String foundFutureLessons(int count) {
    return 'Найдено $count будущих занятий';
  }

  @override
  String get reassignTeacherSubtitleLabel =>
      'Выбрать нового преподавателя для всех занятий';

  @override
  String get deleteAllLessonsLabel => 'Удалить все занятия';

  @override
  String get subscriptionBalanceWontChange => 'Баланс абонементов не изменится';

  @override
  String get permanentScheduleLabel => 'Постоянное расписание';

  @override
  String slotsCountLabel(int count, String slots) {
    return '$count $slots';
  }

  @override
  String get forAllScheduleSlots => 'Для всех слотов расписания';

  @override
  String get temporaryPauseAllSlots => 'Временно приостановить все слоты';

  @override
  String get disablePermanentSchedule => 'Отключить постоянное расписание';

  @override
  String get noLessonsToReassignError => 'Нет занятий для переназначения';

  @override
  String reassignedLessonsMessage(int count) {
    return 'Переназначено $count занятий';
  }

  @override
  String get reassignTeacherHeader => 'Переназначить преподавателя';

  @override
  String get newTeacherFieldLabel => 'Новый преподаватель';

  @override
  String allLessonsCanReassign(int count) {
    return 'Все $count занятий можно переназначить';
  }

  @override
  String foundConflictsCount(int count) {
    return 'Найдено конфликтов: $count';
  }

  @override
  String canReassignLessons(int count) {
    return 'Можно переназначить: $count занятий';
  }

  @override
  String reassignLessonsCount(int count) {
    return 'Переназначить $count занятий';
  }

  @override
  String get reassignAllLessonsLabel => 'Переназначить все занятия';

  @override
  String get lessonHistoryHeader => 'История занятий';

  @override
  String get noCompletedLessonsLabel => 'Нет завершённых занятий';

  @override
  String get showMoreAction => 'Показать ещё';

  @override
  String get noSubjectPlaceholder => 'Без предмета';

  @override
  String get studentUpdatedMessage => 'Ученик обновлен';

  @override
  String get enterLessonsCountValidation => 'Введите количество занятий';

  @override
  String lessonsAddedMessage(int count) {
    return 'Добавлено $count занятий';
  }

  @override
  String lessonsDeductedMessage(int count) {
    return 'Списано $count занятий';
  }

  @override
  String get editStudentHeader => 'Редактировать';

  @override
  String get basicInfoHeader => 'Основная информация';

  @override
  String get fullNameFieldLabel => 'ФИО';

  @override
  String get enterNameError => 'Введите имя';

  @override
  String get phoneFieldLabel => 'Телефон';

  @override
  String get commentFieldLabel => 'Комментарий';

  @override
  String get legacyBalanceHeader => 'Остаток занятий';

  @override
  String get currentBalanceLabel => 'Текущий остаток';

  @override
  String get changeBalanceAction => 'Изменить';

  @override
  String get changeBalanceHeader => 'Изменить остаток';

  @override
  String get quantityFieldLabel => 'Количество';

  @override
  String get reasonOptionalLabel => 'Причина (опционально)';

  @override
  String get applyChangeAction => 'Применить';

  @override
  String get quantityCannotBeZeroError => 'Количество занятий не может быть 0';

  @override
  String get addLessonsHeader => 'Добавить занятия';

  @override
  String legacyBalanceDisplay(int count) {
    return 'Остаток занятий: $count';
  }

  @override
  String get lessonsQuantityFieldLabel => 'Количество занятий';

  @override
  String get positiveOrNegativeHint => 'Положительное или отрицательное число';

  @override
  String get enterQuantityError => 'Введите количество';

  @override
  String get enterIntegerError => 'Введите целое число';

  @override
  String get commentOptionalLabel => 'Комментарий (необязательно)';

  @override
  String get transferFromSubscriptionHint =>
      'Например: Перенос с другого абонемента';

  @override
  String get saveAction => 'Сохранить';

  @override
  String lessonWillNotShowOnDate(String date) {
    return 'Занятие не будет отображаться на $date.\n\nЭто не создаст запись в истории занятий.';
  }

  @override
  String get lessonDeletedWithPayment =>
      'Занятие будет удалено из истории.\nОплата за занятие также будет удалена.';

  @override
  String get lessonDeletedWithReturn =>
      'Занятие будет удалено из истории.\nСписанное занятие будет возвращено на баланс ученика.';

  @override
  String get lessonDeletedCompletely =>
      'Занятие будет полностью удалено из истории.';

  @override
  String get lessonPaymentDefault => 'Оплата занятия';

  @override
  String get lessonWillBeCancelledNoDeduction =>
      'Занятие будет отменено и архивировано без списания с баланса';

  @override
  String get deductedLessonWillBeReturned =>
      'Списанное при проведении занятие будет автоматически возвращено на баланс.';

  @override
  String get whoToDeductLesson => 'Кому списать занятие:';

  @override
  String lessonIsPartOfSeries(int count) {
    return 'Это занятие является частью серии ($count шт.)';
  }

  @override
  String get deductionAppliesToTodayOnly =>
      'Списание применится только к сегодняшнему занятию';

  @override
  String get allSeriesLessonsWillBeArchived =>
      'Все занятия серии будут архивированы без списания';

  @override
  String get cancelLessonAction => 'Отменить занятие';

  @override
  String get lessonSeriesCancelled => 'Серия занятий отменена';

  @override
  String get lessonCancelledAndDeducted =>
      'Занятие отменено и списано с баланса';

  @override
  String get lessonIsPartOfPermanentSchedule =>
      'Это занятие является частью постоянного расписания';

  @override
  String get participantsLabel => 'Участники';

  @override
  String get paymentLabel => 'Оплата';

  @override
  String paymentErrorMessage(String error) {
    return 'Ошибка оплаты: $error';
  }

  @override
  String removeStudentFromLessonConfirm(String name) {
    return 'Убрать $name из этого занятия?';
  }

  @override
  String get removeParticipantFromLesson =>
      'Убрать участника из этого занятия?';

  @override
  String get allStudentsAlreadyAdded => 'Все ученики уже добавлены';

  @override
  String get roomLabel2 => 'Кабинет';

  @override
  String roomWithNumberLabel(String number) {
    return 'Кабинет $number';
  }

  @override
  String get studentFieldLabel => 'Ученик';

  @override
  String get notSelectedOption => 'Не выбран';

  @override
  String get repeatNone => 'Без повтора';

  @override
  String get repeatDaily => 'Каждый день';

  @override
  String get repeatWeeklyOption => 'Каждую неделю';

  @override
  String get repeatWeekdays => 'По дням недели';

  @override
  String get repeatCustom => 'Ручной выбор дат';

  @override
  String get editScopeThisOnly => 'Только это занятие';

  @override
  String get editScopeThisAndFollowing => 'Это и последующие';

  @override
  String get editScopeAll => 'Все занятия серии';

  @override
  String get editScopeSelected => 'Выбранные';

  @override
  String roomAddedMessage(String name) {
    return 'Кабинет \"$name\" добавлен';
  }

  @override
  String get roomNameOptionalLabel => 'Название (опционально)';

  @override
  String get roomNameHintExample => 'Например: Фортепианный';

  @override
  String get createRoomAction => 'Создать кабинет';

  @override
  String get noOwnStudentsMessage => 'У вас нет своих учеников';

  @override
  String showAllStudents(int count) {
    return 'Показать всех ($count)';
  }

  @override
  String get otherStudentsSection => 'Остальные ученики';

  @override
  String get hideAction => 'Скрыть';

  @override
  String get quickAddMessage => 'Быстрое добавление';

  @override
  String get createStudentAction => 'Создать ученика';

  @override
  String get addSubjectForLessons => 'Добавьте предмет для занятий';

  @override
  String get createSubjectAction => 'Создать предмет';

  @override
  String get configureLessonParams => 'Настройте параметры занятия';

  @override
  String get enterNameRequired => 'Введите название';

  @override
  String get minutesUnit => 'мин';

  @override
  String get createTypeAction => 'Создать тип';

  @override
  String get teachersFilter => 'Преподаватели';

  @override
  String get lessonTypesFilter => 'Типы занятий';

  @override
  String get directionsFilter => 'Направления';

  @override
  String get applyFiltersAction => 'Применить фильтры';

  @override
  String get showAllAction => 'Показать все';

  @override
  String get studentsFilter => 'Ученики';

  @override
  String get deletedLabel => 'Удалён';

  @override
  String get temporarilyShowingAll => 'Временно показаны все';

  @override
  String get allRoomsLabel => 'Все кабинеты';

  @override
  String get noDataLabel => 'Нет данных';

  @override
  String get selectDatesTitle => 'Выберите даты';

  @override
  String get lessonSegment => 'Занятие';

  @override
  String get bookingSegment => 'Бронь';

  @override
  String get roomRequired => 'Кабинет *';

  @override
  String get noRoomsMessage => 'Нет кабинетов';

  @override
  String get addRoomTooltip => 'Добавить кабинет';

  @override
  String get roomsLabel => 'Кабинеты';

  @override
  String roomAbbr(String number) {
    return 'Каб. $number';
  }

  @override
  String get studentSegment => 'Ученик';

  @override
  String get groupSegment => 'Группа';

  @override
  String get selectStudentHint => 'Выберите ученика';

  @override
  String get noGroupsMessage => 'Нет групп';

  @override
  String get addSubjectTooltip2 => 'Добавить предмет';

  @override
  String get addLessonTypeTooltip2 => 'Добавить тип занятия';

  @override
  String get lessonsCountQuestion => 'Количество занятий:';

  @override
  String get mondayAbbr => 'Пн';

  @override
  String get tuesdayAbbr => 'Вт';

  @override
  String get wednesdayAbbr => 'Ср';

  @override
  String get thursdayAbbr => 'Чт';

  @override
  String get fridayAbbr => 'Пт';

  @override
  String get saturdayAbbr => 'Сб';

  @override
  String get sundayAbbr => 'Вс';

  @override
  String get checkingConflictsLabel => 'Проверка конфликтов...';

  @override
  String willCreateLessonsCount(int count) {
    return 'Будет создано $count занятий';
  }

  @override
  String get createLessonLabel => 'Создать занятие';

  @override
  String get roomsBookedMessage => 'Кабинеты забронированы';

  @override
  String get invalidLabel => 'Некорректно';

  @override
  String get minLessonDurationMessage =>
      'Минимальная длительность занятия — 15 минут';

  @override
  String lessonsCreatedSkippedCount(int created, int skipped) {
    return 'Создано $created занятий (пропущено: $skipped)';
  }

  @override
  String get bookedLabel => 'Забронировано';

  @override
  String get deleteBookingAction => 'Удалить бронь';

  @override
  String get selectMinOneRoom => 'Выберите минимум один кабинет';

  @override
  String get descriptionHintExample => 'Например: Репетиция, Мероприятие';

  @override
  String temporaryRoomUntilMessage(String room, String date) {
    return 'Временно в кабинете $room до $date';
  }

  @override
  String slotWillNotWorkOnDateFull(String date) {
    return 'Слот не будет действовать $date.\n\nЭто позволит создать другое занятие в это время.';
  }

  @override
  String get exceptionAddedMessage => 'Исключение добавлено';

  @override
  String get slotResumedMessage => 'Слот возобновлён';

  @override
  String get slotDeactivateConfirm =>
      'Слот будет полностью отключён и не будет отображаться в расписании.\n\nВы сможете активировать его снова в карточке ученика.';

  @override
  String get slotDeactivatedMessage => 'Слот деактивирован';

  @override
  String studentNameLabel(String name) {
    return 'Ученик: $name';
  }

  @override
  String willBeCreatedCount(int count) {
    return 'Будет создано: $count занятий';
  }

  @override
  String createdLessonsCount(int count) {
    return 'Создано $count занятий';
  }

  @override
  String get applyChangesAction => 'Применить изменения';

  @override
  String get changeScopeLabel => 'Область изменений';

  @override
  String seriesLessonsTitle(int count) {
    return 'Занятия серии ($count)';
  }

  @override
  String selectedLabel(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get changesLabel => 'Изменения';

  @override
  String updatedLessonsSkipped(int updated, int skipped) {
    return 'Обновлено $updated занятий (пропущено: $skipped)';
  }

  @override
  String updatedLessonsCount(int count) {
    return 'Обновлено $count занятий';
  }

  @override
  String get allRoomsDisplayed => 'Отображаются все кабинеты';

  @override
  String selectedRoomsCount(int count) {
    return 'Выбрано кабинетов: $count';
  }

  @override
  String get defaultRoomsLabel => 'Кабинеты по умолчанию';

  @override
  String get roomSetupFirstTimeHint =>
      'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.';

  @override
  String get roomSetupHint =>
      'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.';

  @override
  String get selectRoomsAction => 'Выберите кабинеты';

  @override
  String saveCountAction(int count) {
    return 'Сохранить ($count)';
  }

  @override
  String get virtualLessonLabel => 'Виртуальное занятие';

  @override
  String lessonWillNotShowMessage(String date) {
    return 'Занятие не будет отображаться на $date.\n\nЭто не создаст запись в истории занятий.';
  }

  @override
  String get schedulePausedMessage => 'Расписание приостановлено';

  @override
  String get scheduleResumedSuccessMessage => 'Расписание возобновлено';

  @override
  String get scheduleDeactivatedMessage => 'Расписание деактивировано';

  @override
  String conflictsLabel(int count) {
    return 'Конфликты: $count';
  }

  @override
  String willBeChangedCount(int count) {
    return 'Будет изменено: $count занятий';
  }

  @override
  String conflictsWillBeSkippedLabel(int count) {
    return 'Конфликты: $count (будут пропущены)';
  }

  @override
  String errorFormat(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get theseDatesWillBeSkipped => 'Эти даты будут пропущены:';

  @override
  String andMore(int count) {
    return '...и ещё $count';
  }

  @override
  String get enabledForAdmin => 'Включено для администратора';

  @override
  String get teacherSubjectsLabel => 'НАПРАВЛЕНИЯ';

  @override
  String get teacherSubjectsHint => 'Предметы, которые ведёт преподаватель';

  @override
  String get noDirectionsHint =>
      'Направления не указаны.\nДобавьте предметы, которые ведёт преподаватель.';

  @override
  String get unknownSubject => 'Неизвестный';

  @override
  String get addDirectionTitle => 'Добавить направление';

  @override
  String selectSubjectFor(String name) {
    return 'Выберите предмет для $name';
  }

  @override
  String directionAdded(String name) {
    return 'Направление \"$name\" добавлено';
  }

  @override
  String get addSubjectDescription => 'Добавьте предмет для занятий';

  @override
  String get subjectNameField => 'Название предмета';

  @override
  String get nameField => 'Название';

  @override
  String get minSuffix => 'мин';

  @override
  String get priceOptional => 'Цена (необязательно)';

  @override
  String get showAll => 'Показать все';

  @override
  String get deleted => 'Удалён';

  @override
  String studentAddedAsGuest(String name) {
    return '$name добавлен как гость';
  }

  @override
  String roomWithNumberDefault(String number) {
    return 'Кабинет $number';
  }

  @override
  String showAllStudentsCount(int count) {
    return 'Показать всех ($count)';
  }

  @override
  String get otherStudentsLabel => 'Остальные ученики';

  @override
  String studentNameAddedMessage(String name) {
    return 'Ученик \"$name\" добавлен';
  }

  @override
  String subjectNameAddedMessage(String name) {
    return 'Предмет \"$name\" добавлен';
  }

  @override
  String lessonTypeNameAddedMessage(String name) {
    return 'Тип занятия \"$name\" добавлен';
  }

  @override
  String durationMinutesLabel(int minutes) {
    return '$minutes мин';
  }

  @override
  String lessonTypeDurationFormat(String name, int duration) {
    return '$name ($duration мин)';
  }

  @override
  String groupMembersCount(String name, int count) {
    return '$name ($count уч.)';
  }

  @override
  String get roomSetupFirstTimeDescription =>
      'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.';

  @override
  String get roomSetupDescription =>
      'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.';

  @override
  String saveWithCountLabel(int count) {
    return 'Сохранить ($count)';
  }

  @override
  String get allRoomsDisplayedMessage => 'Отображаются все кабинеты';

  @override
  String selectedRoomsCountMessage(int count) {
    return 'Выбрано кабинетов: $count';
  }

  @override
  String get temporarilyShowingAllRooms => 'Временно показаны все';

  @override
  String get notConfiguredRooms => 'Не настроено';

  @override
  String get allRoomsDefault => 'Все кабинеты';

  @override
  String get noDataAvailableMessage => 'Нет данных';

  @override
  String get januaryMonth => 'Январь';

  @override
  String get februaryMonth => 'Февраль';

  @override
  String get marchMonth => 'Март';

  @override
  String get aprilMonth => 'Апрель';

  @override
  String get mayMonth => 'Май';

  @override
  String get juneMonth => 'Июнь';

  @override
  String get julyMonth => 'Июль';

  @override
  String get augustMonth => 'Август';

  @override
  String get septemberMonth => 'Сентябрь';

  @override
  String get octoberMonth => 'Октябрь';

  @override
  String get novemberMonth => 'Ноябрь';

  @override
  String get decemberMonth => 'Декабрь';

  @override
  String get selectDatesLabel => 'Выберите даты';

  @override
  String get lessonTabLabel => 'Занятие';

  @override
  String get bookingTabLabel => 'Бронь';

  @override
  String get noRoomsAvailableMessage => 'Нет кабинетов';

  @override
  String roomAbbreviation(String number) {
    return 'Каб. $number';
  }

  @override
  String get descriptionOptionalField => 'Описание (необязательно)';

  @override
  String get eventMeetingHint => 'Мероприятие, встреча и т.д.';

  @override
  String get studentTabLabel => 'Ученик';

  @override
  String get groupTabLabel => 'Группа';

  @override
  String get noStudentsAvailableMessage => 'Нет учеников';

  @override
  String get selectStudentLabel => 'Выберите ученика';

  @override
  String get noGroupsAvailableMessage => 'Нет групп';

  @override
  String get lessonTimeTitle => 'Время занятий';

  @override
  String get selectDatesInCalendarLabel => 'Выбрать даты в календаре';

  @override
  String selectedDatesCountLabel(int count) {
    return 'Выбрано: $count дат';
  }

  @override
  String get checkingConflictsProgress => 'Проверка конфликтов...';

  @override
  String willCreateLessonsCountMessage(int count) {
    return 'Будет создано $count занятий';
  }

  @override
  String conflictsWillBeSkippedMessage(int count) {
    return 'Конфликты: $count (будут пропущены)';
  }

  @override
  String createSchedulesCountLabel(int count) {
    return 'Создать $count расписаний';
  }

  @override
  String get createScheduleActionLabel => 'Создать расписание';

  @override
  String createLessonsCountLabel(int count) {
    return 'Создать $count занятий';
  }

  @override
  String get createLessonActionLabel => 'Создать занятие';

  @override
  String get minBookingDurationError =>
      'Минимальная длительность брони — 15 минут';

  @override
  String get roomsBookedSuccess => 'Кабинеты забронированы';

  @override
  String durationHoursMinutesFormat(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String durationHoursOnlyFormat(int hours) {
    return '$hours ч';
  }

  @override
  String durationMinutesOnlyFormat(int minutes) {
    return '$minutes мин';
  }

  @override
  String get invalidTimeLabel => 'Некорректно';

  @override
  String dayStartTimeHelpText(String day) {
    return '$day: Начало занятия';
  }

  @override
  String dayEndTimeHelpText(String day) {
    return '$day: Конец занятия';
  }

  @override
  String get minLessonDurationError =>
      'Минимальная длительность занятия — 15 минут';

  @override
  String permanentSchedulesCreatedMessage(int count) {
    return 'Создано $count постоянных расписаний';
  }

  @override
  String get permanentScheduleCreatedMessage => 'Постоянное расписание создано';

  @override
  String get allDatesOccupiedError => 'Все даты заняты';

  @override
  String lessonsCreatedSkippedMessage(int created, int skipped) {
    return 'Создано $created занятий (пропущено: $skipped)';
  }

  @override
  String lessonsCreatedSuccessMessage(int count) {
    return 'Создано $count занятий';
  }

  @override
  String get groupLessonCreatedMessage => 'Групповое занятие создано';

  @override
  String get lessonCreatedSuccessMessage => 'Занятие создано';

  @override
  String get enterGroupName => 'Введите название';

  @override
  String get unknownUserLabel => 'Неизвестный пользователь';

  @override
  String get deletingProgress => 'Удаление...';

  @override
  String get deleteBookingActionLabel => 'Удалить бронь';

  @override
  String get bookingWillBeDeletedMessage =>
      'Бронирование будет удалено и кабинеты освободятся.';

  @override
  String get bookingDeletedSuccess => 'Бронь удалена';

  @override
  String get deletionErrorMessage => 'Ошибка при удалении';

  @override
  String get bookRoomsLabel => 'Забронировать кабинеты';

  @override
  String get selectMinOneRoomMessage => 'Выберите минимум один кабинет';

  @override
  String get bookingErrorMessage => 'Ошибка бронирования';

  @override
  String slotExceptionMessage(String date) {
    return 'Слот не будет действовать $date.\n\nЭто позволит создать другое занятие в это время.';
  }

  @override
  String get exceptionAddedSuccess => 'Исключение добавлено';

  @override
  String get pauseUntilHelpText => 'Приостановить до';

  @override
  String slotPausedUntilMessage(String date) {
    return 'Слот приостановлен до $date';
  }

  @override
  String get slotResumedSuccess => 'Слот возобновлён';

  @override
  String get slotDeactivateMessage =>
      'Слот будет полностью отключён и не будет отображаться в расписании.\n\nВы сможете активировать его снова в карточке ученика.';

  @override
  String get slotDeactivatedSuccess => 'Слот деактивирован';

  @override
  String studentLabelWithName(String name) {
    return 'Ученик: $name';
  }

  @override
  String get toDateLabelSchedule => 'По дату';

  @override
  String willBeCreatedCountMessage(int count) {
    return 'Будет создано: $count занятий';
  }

  @override
  String get creatingProgress => 'Создание...';

  @override
  String get createLessonsActionLabel => 'Создать занятия';

  @override
  String get noDatesToCreateError => 'Нет дат для создания';

  @override
  String get roomNotSpecifiedError => 'Не указан кабинет';

  @override
  String get editSeriesLabel => 'Редактировать серию';

  @override
  String get savingProgress => 'Сохранение...';

  @override
  String get byWeekdaysFilterLabel => 'По дням недели';

  @override
  String get allLessonsLabel => 'Все';

  @override
  String seriesLessonsLabel(int count) {
    return 'Занятия серии ($count)';
  }

  @override
  String selectedCountLabel(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get timeChangeLabel => 'Время';

  @override
  String get roomChangeLabel => 'Кабинет';

  @override
  String get studentChangeLabel => 'Ученик';

  @override
  String get subjectChangeLabel => 'Предмет';

  @override
  String get lessonTypeChangeLabel => 'Тип занятия';

  @override
  String get currentValueLabel => 'текущий';

  @override
  String willBeChangedCountMessage(int count) {
    return 'Будет изменено: $count занятий';
  }

  @override
  String get noLessonsToUpdateError =>
      'Нет занятий для обновления (все имеют конфликты)';

  @override
  String updatedLessonsSkippedMessage(int updated, int skipped) {
    return 'Обновлено $updated занятий (пропущено: $skipped)';
  }

  @override
  String updatedLessonsSuccessMessage(int count) {
    return 'Обновлено $count занятий';
  }

  @override
  String lessonSchedulePaused(String date) {
    return 'Приостановлено до $date';
  }

  @override
  String get lessonScheduleIndefinitePause => 'Бессрочная пауза';

  @override
  String temporaryRoomReplacementInfo(String room, String date) {
    return 'Временно в кабинете $room до $date';
  }

  @override
  String createLessonOnDateLabel(String date) {
    return 'Создать занятие на $date';
  }

  @override
  String completeLessonOnDateLabel(String date) {
    return 'Провести занятие на $date';
  }

  @override
  String cancelLessonOnDateLabel(String date) {
    return 'Отменить занятие на $date';
  }

  @override
  String get lessonCompletedSuccess => 'Занятие проведено';

  @override
  String get dateSkippedSuccess => 'Дата пропущена';

  @override
  String get schedulePausedSuccess => 'Расписание приостановлено';

  @override
  String get scheduleResumedSuccess => 'Расписание возобновлено';

  @override
  String get scheduleDeactivatedSuccess => 'Расписание деактивировано';

  @override
  String get january => 'Январь';

  @override
  String get february => 'Февраль';

  @override
  String get march => 'Март';

  @override
  String get april => 'Апрель';

  @override
  String get may => 'Май';

  @override
  String get june => 'Июнь';

  @override
  String get july => 'Июль';

  @override
  String get august => 'Август';

  @override
  String get september => 'Сентябрь';

  @override
  String get october => 'Октябрь';

  @override
  String get november => 'Ноябрь';

  @override
  String get december => 'Декабрь';

  @override
  String get changes => 'Изменения';

  @override
  String get editSeries => 'Редактировать серию';

  @override
  String get saving => 'Сохранение...';

  @override
  String get applyChanges => 'Применить изменения';

  @override
  String get byDaysOfWeek => 'По дням недели';

  @override
  String get current => 'текущий';

  @override
  String seriesLessonsCount(int count) {
    return 'Занятия серии ($count)';
  }

  @override
  String willBeChangedLessons(int count) {
    return 'Будет изменено: $count занятий';
  }

  @override
  String get creating => 'Создание...';

  @override
  String get createLessonsButton => 'Создать занятия';

  @override
  String willBeCreatedLessons(int count) {
    return 'Будет создано: $count занятий';
  }

  @override
  String get fromDate => 'С даты';

  @override
  String get toDate => 'По дату';

  @override
  String get bookRooms => 'Забронировать кабинеты';

  @override
  String get selectRooms => 'Выберите кабинеты';

  @override
  String get selectAtLeastOneRoomValidation => 'Выберите минимум один кабинет';

  @override
  String createLessonOn(String date) {
    return 'Создать занятие на $date';
  }

  @override
  String exceptionMessage(String date) {
    return 'Слот не будет действовать $date.\n\nЭто позволит создать другое занятие в это время.';
  }

  @override
  String temporaryRoomMessage(String room, String date) {
    return 'Временно в кабинете $room до $date';
  }

  @override
  String get deleting => 'Удаление...';

  @override
  String get deleteError => 'Ошибка при удалении';

  @override
  String get roomSetupDefaultDescription =>
      'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.';

  @override
  String get selectRoomsPlaceholder => 'Выберите кабинеты';

  @override
  String completeLessonOn(String date) {
    return 'Провести занятие на $date';
  }

  @override
  String cancelLessonOn(String date) {
    return 'Отменить занятие на $date';
  }

  @override
  String paymentLessonsWithDate(int count, String date) {
    return '$count занятий • $date';
  }

  @override
  String subscriptionLessonsProgress(int remaining, int total) {
    return '$remaining / $total занятий';
  }

  @override
  String daysRemainingShort(int days) {
    return '($days дн.)';
  }
}
