/// Строковые константы приложения (русский язык)
class AppStrings {
  AppStrings._();

  // Общие
  static const String appName = 'Kabinet';
  static const String loading = 'Загрузка...';
  static const String error = 'Ошибка';
  static const String retry = 'Повторить';
  static const String cancel = 'Отмена';
  static const String save = 'Сохранить';
  static const String delete = 'Удалить';
  static const String archive = 'Архивировать';
  static const String restore = 'Восстановить';
  static const String edit = 'Редактировать';
  static const String add = 'Добавить';
  static const String create = 'Создать';
  static const String search = 'Поиск';
  static const String noData = 'Нет данных';
  static const String confirm = 'Подтвердить';
  static const String yes = 'Да';
  static const String no = 'Нет';

  // Auth
  static const String login = 'Войти';
  static const String register = 'Зарегистрироваться';
  static const String logout = 'Выйти';
  static const String email = 'Email';
  static const String password = 'Пароль';
  static const String confirmPassword = 'Подтвердите пароль';
  static const String fullName = 'Полное имя';
  static const String forgotPassword = 'Забыли пароль?';
  static const String resetPassword = 'Восстановить пароль';
  static const String resetPasswordTitle = 'Восстановление пароля';
  static const String resetPasswordMessage = 'Введите email, указанный при регистрации. Мы отправим вам ссылку для сброса пароля.';
  static const String resetPasswordSuccess = 'Письмо отправлено! Проверьте свою почту.';
  static const String noAccount = 'Нет аккаунта?';
  static const String hasAccount = 'Уже есть аккаунт?';
  static const String loginWithGoogle = 'Войти через Google';
  static const String loginWithApple = 'Войти через Apple';

  // Institution
  static const String institutions = 'Заведения';
  static const String createInstitution = 'Создать заведение';
  static const String joinInstitution = 'Присоединиться';
  static const String institutionName = 'Название заведения';
  static const String inviteCode = 'Код приглашения';
  static const String owner = 'Владелец';
  static const String member = 'Участник';

  // Navigation
  static const String dashboard = 'Главная';
  static const String rooms = 'Кабинеты';
  static const String students = 'Ученики';
  static const String payments = 'Оплаты';
  static const String more = 'Ещё';
  static const String settings = 'Настройки';
  static const String statistics = 'Статистика';
  static const String groups = 'Группы';

  // Rooms
  static const String room = 'Кабинет';
  static const String roomName = 'Название кабинета';
  static const String roomNumber = 'Номер кабинета';
  static const String addRoom = 'Добавить кабинет';

  // Schedule
  static const String schedule = 'Расписание';
  static const String today = 'Сегодня';
  static const String lesson = 'Занятие';
  static const String newLesson = 'Новое занятие';
  static const String lessonType = 'Тип занятия';
  static const String subject = 'Предмет';
  static const String date = 'Дата';
  static const String time = 'Время';
  static const String startTime = 'Начало';
  static const String endTime = 'Окончание';
  static const String duration = 'Длительность';
  static const String minutes = 'мин';
  static const String comment = 'Комментарий';

  // Lesson statuses
  static const String scheduled = 'Запланировано';
  static const String completed = 'Проведено';
  static const String cancelled = 'Отменено';
  static const String rescheduled = 'Перенесено';
  static const String markCompleted = 'Отметить проведённым';
  static const String markCancelled = 'Отменить занятие';
  static const String unmarkedLessons = 'Неотмеченные занятия';
  static const String noUnmarkedLessons = 'Нет неотмеченных занятий';

  // Students
  static const String student = 'Ученик';
  static const String studentName = 'Имя ученика';
  static const String phone = 'Телефон';
  static const String addStudent = 'Добавить ученика';
  static const String prepaidLessons = 'Предоплаченных занятий';
  static const String debt = 'Долг';
  static const String individualLesson = 'Индивидуальное';
  static const String groupLesson = 'Групповое';

  // Groups
  static const String group = 'Группа';
  static const String groupName = 'Название группы';
  static const String addGroup = 'Добавить группу';
  static const String members = 'Участники';
  static const String addMember = 'Добавить участника';

  // Payments
  static const String payment = 'Оплата';
  static const String addPayment = 'Добавить оплату';
  static const String amount = 'Сумма';
  static const String lessonsCount = 'Количество занятий';
  static const String paymentPlan = 'Тариф';
  static const String paidAt = 'Дата оплаты';
  static const String correction = 'Корректировка';
  static const String correctionReason = 'Причина корректировки';

  // Settings
  static const String profile = 'Профиль';
  static const String subjects = 'Предметы';
  static const String lessonTypes = 'Типы занятий';
  static const String paymentPlans = 'Тарифы оплаты';
  static const String teamMembers = 'Участники';
  static const String inviteMembers = 'Пригласить участника';

  // Errors
  static const String errorOccurred = 'Произошла ошибка';
  static const String networkError = 'Ошибка сети. Проверьте подключение.';
  static const String unknownError = 'Неизвестная ошибка';
  static const String invalidEmail = 'Некорректный email';
  static const String weakPassword = 'Пароль слишком простой';
  static const String emailInUse = 'Email уже используется';
  static const String invalidCredentials = 'Неверный email или пароль';
  static const String fieldRequired = 'Это поле обязательно';
  static const String passwordsDoNotMatch = 'Пароли не совпадают';
  static const String minPasswordLength = 'Минимум 8 символов';
  static const String passwordNeedsUppercase = 'Нужна хотя бы одна заглавная буква';
  static const String passwordNeedsSpecialChar = 'Нужен хотя бы один спецсимвол (!@#\$%^&*)';
}
