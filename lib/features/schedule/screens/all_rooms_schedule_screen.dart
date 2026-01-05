import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/utils/date_utils.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/institution/providers/subject_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/ios_time_picker.dart';
import 'package:kabinet/core/widgets/color_picker_field.dart';
import 'package:kabinet/core/widgets/shimmer_loading.dart';
import 'package:kabinet/features/bookings/models/booking.dart';
import 'package:kabinet/features/bookings/providers/booking_provider.dart';

/// Класс для хранения состояния фильтров расписания
class ScheduleFilters {
  final Set<String> teacherIds;
  final Set<String> studentIds;
  final Set<String> lessonTypeIds;
  final Set<String> subjectIds;

  const ScheduleFilters({
    this.teacherIds = const {},
    this.studentIds = const {},
    this.lessonTypeIds = const {},
    this.subjectIds = const {},
  });

  bool get isEmpty =>
      teacherIds.isEmpty &&
      studentIds.isEmpty &&
      lessonTypeIds.isEmpty &&
      subjectIds.isEmpty;

  int get activeCount =>
      (teacherIds.isNotEmpty ? 1 : 0) +
      (studentIds.isNotEmpty ? 1 : 0) +
      (lessonTypeIds.isNotEmpty ? 1 : 0) +
      (subjectIds.isNotEmpty ? 1 : 0);

  ScheduleFilters copyWith({
    Set<String>? teacherIds,
    Set<String>? studentIds,
    Set<String>? lessonTypeIds,
    Set<String>? subjectIds,
  }) {
    return ScheduleFilters(
      teacherIds: teacherIds ?? this.teacherIds,
      studentIds: studentIds ?? this.studentIds,
      lessonTypeIds: lessonTypeIds ?? this.lessonTypeIds,
      subjectIds: subjectIds ?? this.subjectIds,
    );
  }

  /// Проверяет, подходит ли занятие под фильтры
  bool matchesLesson(Lesson lesson) {
    // Если фильтр пустой - пропускаем все
    if (teacherIds.isNotEmpty && !teacherIds.contains(lesson.teacherId)) {
      return false;
    }
    if (studentIds.isNotEmpty) {
      // Для индивидуальных занятий проверяем studentId
      if (lesson.studentId != null && !studentIds.contains(lesson.studentId)) {
        return false;
      }
      // Если нет studentId (групповое занятие без привязки) - не фильтруем по ученикам
    }
    if (lessonTypeIds.isNotEmpty &&
        lesson.lessonTypeId != null &&
        !lessonTypeIds.contains(lesson.lessonTypeId)) {
      return false;
    }
    if (subjectIds.isNotEmpty &&
        lesson.subjectId != null &&
        !subjectIds.contains(lesson.subjectId)) {
      return false;
    }
    return true;
  }
}

/// Режим просмотра расписания
enum ScheduleViewMode {
  day,
  week,
}

/// Экран расписания всех кабинетов
class AllRoomsScheduleScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const AllRoomsScheduleScreen({
    super.key,
    required this.institutionId,
  });

  @override
  ConsumerState<AllRoomsScheduleScreen> createState() => _AllRoomsScheduleScreenState();
}

class _AllRoomsScheduleScreenState extends ConsumerState<AllRoomsScheduleScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  String? _selectedRoomId; // null = все кабинеты
  double? _savedScrollOffset; // Сохранённая позиция скролла для восстановления
  ScheduleFilters _filters = const ScheduleFilters();
  ScheduleViewMode _viewMode = ScheduleViewMode.day;
  int _scrollResetKey = 0; // Ключ для принудительного сброса скролла

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Предзагружаем соседние даты при первом входе
    _preloadAdjacentDates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Обновляем данные когда приложение возвращается из фона
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(lessonsByInstitutionStreamProvider(
        InstitutionDateParams(widget.institutionId, _selectedDate),
      ));
    }
  }

  /// Переход к сегодняшней дате с прокруткой к началу
  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _savedScrollOffset = null;
      _scrollResetKey++; // Принудительный сброс скролла сетки
    });
    _preloadAdjacentDates();
  }

  /// Предзагрузка данных для соседних дат (±3 дня)
  void _preloadAdjacentDates() {
    // Используем addPostFrameCallback чтобы не блокировать текущий build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Загружаем данные для дат от -3 до +3 дней (исключая текущую)
      for (int i = -3; i <= 3; i++) {
        if (i == 0) continue; // Текущая дата уже загружается через watch

        final adjacentDate = _selectedDate.add(Duration(days: i));
        final params = InstitutionDateParams(widget.institutionId, adjacentDate);

        // Используем read() для фоновой загрузки без rebuild
        ref.read(lessonsByInstitutionStreamProvider(params).future).catchError((error) {
          // Игнорируем ошибки предзагрузки
          return <Lesson>[];
        });

        ref.read(bookingsByInstitutionDateProvider(params).future).catchError((error) {
          // Игнорируем ошибки предзагрузки
          return <Booking>[];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final lessonsAsync = ref.watch(
      lessonsByInstitutionStreamProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
    );
    final bookingsAsync = ref.watch(
      bookingsByInstitutionDateProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
    );

    // Получаем права пользователя (используем StreamProvider для realtime обновления)
    final institutionAsync = ref.watch(currentInstitutionStreamProvider(widget.institutionId));
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final isOwner = institutionAsync.maybeWhen(
      data: (inst) => inst.ownerId == currentUserId,
      orElse: () => false,
    );
    final canManageRooms = isOwner || (permissions?.manageRooms ?? false);

    // Получаем рабочее время из заведения
    final workStartHour = institutionAsync.valueOrNull?.workStartHour ?? 8;
    final workEndHour = institutionAsync.valueOrNull?.workEndHour ?? 22;

    // Получаем цвета преподавателей
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
    final teacherColors = membersAsync.maybeWhen(
      data: (members) => {
        for (final m in members) m.userId: m.color,
      },
      orElse: () => <String, String?>{},
    );

    // Получаем название выбранного кабинета для заголовка
    String title = 'Расписание';
    if (_selectedRoomId != null) {
      roomsAsync.whenData((rooms) {
        final room = rooms.where((r) => r.id == _selectedRoomId).firstOrNull;
        if (room != null) {
          title = room.number != null ? 'Кабинет ${room.number}' : room.name;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedRoomId != null ? title : 'Расписание'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterSheet,
                tooltip: 'Фильтры',
              ),
              if (!_filters.isEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_filters.activeCount}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDate,
          ),
          TextButton(
            onPressed: _goToToday,
            child: const Text(AppStrings.today),
          ),
        ],
      ),
      body: Column(
        children: [
          // Вкладки День/Неделя
          _ViewModeTabs(
            viewMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
          // Селектор даты (только для дневного режима)
          if (_viewMode == ScheduleViewMode.day)
            _WeekDaySelector(
              selectedDate: _selectedDate,
              scrollToTodayKey: _scrollResetKey,
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
                _preloadAdjacentDates();
              },
            ),
          // Селектор недели (для недельного режима)
          if (_viewMode == ScheduleViewMode.week)
            _WeekSelector(
              selectedDate: _selectedDate,
              onWeekChanged: (weekStart) {
                setState(() => _selectedDate = weekStart);
              },
            ),
          const Divider(height: 1),
          Expanded(
            child: _viewMode == ScheduleViewMode.day
                ? _buildDayView(roomsAsync, lessonsAsync, bookingsAsync, canManageRooms, workStartHour, workEndHour, teacherColors)
                : _buildWeekView(roomsAsync, canManageRooms, workStartHour, workEndHour, teacherColors),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(
        isOwner: isOwner,
        permissions: permissions,
        rooms: roomsAsync.valueOrNull ?? [],
      ),
    );
  }

  Widget _buildDayView(
    AsyncValue<List<Room>> roomsAsync,
    AsyncValue<List<Lesson>> lessonsAsync,
    AsyncValue<List<Booking>> bookingsAsync,
    bool canManageRooms,
    int workStartHour,
    int workEndHour,
    Map<String, String?> teacherColors,
  ) {
    // Используем valueOrNull для предотвращения моргания при смене даты
    final rooms = roomsAsync.valueOrNull;
    final lessons = lessonsAsync.valueOrNull;

    // Показываем shimmer-скелетон при первой загрузке кабинетов
    if (rooms == null) {
      return ScheduleSkeletonLoader(
        roomCount: 3,
        startHour: workStartHour,
        endHour: workEndHour,
      );
    }

    // Показываем shimmer при загрузке занятий (смена даты)
    if (lessonsAsync.isLoading && lessons == null) {
      return ScheduleSkeletonLoader(
        roomCount: rooms.length.clamp(1, 5),
        startHour: workStartHour,
        endHour: workEndHour,
      );
    }

    // Для занятий: показываем пустой список если данные ещё загружаются
    // Это предотвращает ошибку "Нет соединения" при смене даты
    final lessonsList = lessons ?? [];

    // Получаем брони (пустой список при загрузке/ошибке)
    final bookings = bookingsAsync.valueOrNull ?? [];

    final filteredLessons = _filters.isEmpty
        ? lessonsList
        : lessonsList.where((l) => _filters.matchesLesson(l)).toList();

    // Вычисляем эффективные часы с учётом занятий и броней вне рабочего времени
    final effectiveHours = _calculateEffectiveHours(
      lessons: lessonsList,
      bookings: bookings,
      workStartHour: workStartHour,
      workEndHour: workEndHour,
    );

    return _AllRoomsTimeGrid(
      key: ValueKey('grid_$_scrollResetKey'), // Для принудительного сброса скролла
      rooms: _selectedRoomId != null
          ? rooms.where((r) => r.id == _selectedRoomId).toList()
          : rooms,
      allRooms: rooms,
      lessons: filteredLessons,
      bookings: bookings,
      selectedDate: _selectedDate,
      institutionId: widget.institutionId,
      selectedRoomId: _selectedRoomId,
      restoreScrollOffset: _savedScrollOffset,
      canManageRooms: canManageRooms,
      startHour: effectiveHours.$1,
      endHour: effectiveHours.$2,
      teacherColors: teacherColors,
      onLessonTap: _showLessonDetail,
      onBookingTap: _showBookingDetail,
      onRoomTap: (roomId, currentOffset) {
        setState(() {
          // Всегда сохраняем текущую позицию скролла
          _savedScrollOffset = currentOffset;
          if (_selectedRoomId == roomId) {
            // Возвращаемся к общему виду
            _selectedRoomId = null;
          } else {
            // Переходим к одному кабинету
            _selectedRoomId = roomId;
          }
        });
      },
      onAddLesson: (room, hour, minute) => _showAddLessonSheet(room, hour, minute, allRooms: rooms),
      onAddRoom: _showAddRoomBottomSheet,
    );
  }

  /// Вычисляет эффективные часы отображения сетки
  /// Расширяет диапазон, если есть занятия вне рабочего времени
  (int, int) _calculateEffectiveHours({
    required List<Lesson> lessons,
    List<Booking> bookings = const [],
    required int workStartHour,
    required int workEndHour,
  }) {
    int effectiveStart = workStartHour;
    int effectiveEnd = workEndHour;

    for (final lesson in lessons) {
      // Час начала занятия
      final lessonStartHour = lesson.startTime.hour;
      // Час окончания занятия (если минуты > 0, нужен следующий час)
      final lessonEndHour = lesson.endTime.minute > 0
          ? lesson.endTime.hour + 1
          : lesson.endTime.hour;

      if (lessonStartHour < effectiveStart) {
        effectiveStart = lessonStartHour;
      }
      if (lessonEndHour > effectiveEnd) {
        effectiveEnd = lessonEndHour;
      }
    }

    // Учитываем брони
    for (final booking in bookings) {
      final bookingStartHour = booking.startTime.hour;
      final bookingEndHour = booking.endTime.minute > 0
          ? booking.endTime.hour + 1
          : booking.endTime.hour;

      if (bookingStartHour < effectiveStart) {
        effectiveStart = bookingStartHour;
      }
      if (bookingEndHour > effectiveEnd) {
        effectiveEnd = bookingEndHour;
      }
    }

    // Ограничиваем разумными пределами (0-24)
    effectiveStart = effectiveStart.clamp(0, 23);
    effectiveEnd = effectiveEnd.clamp(1, 24);

    return (effectiveStart, effectiveEnd);
  }

  Widget _buildWeekView(
    AsyncValue<List<Room>> roomsAsync,
    bool canManageRooms,
    int workStartHour,
    int workEndHour,
    Map<String, String?> teacherColors,
  ) {
    final weekStart = InstitutionWeekParams.getWeekStart(_selectedDate);
    final weekParams = InstitutionWeekParams(widget.institutionId, weekStart);
    final weekLessonsAsync = ref.watch(lessonsByInstitutionWeekProvider(weekParams));

    // Используем valueOrNull для предотвращения ошибки при смене недели
    final rooms = roomsAsync.valueOrNull;
    final lessonsByDay = weekLessonsAsync.valueOrNull;

    // Показываем shimmer-скелетон при первой загрузке кабинетов
    if (rooms == null) {
      return const WeekScheduleSkeletonLoader(dayCount: 7);
    }

    // Показываем shimmer при загрузке занятий недели (смена недели)
    if (weekLessonsAsync.isLoading && lessonsByDay == null) {
      return const WeekScheduleSkeletonLoader(dayCount: 7);
    }

    // Для занятий: показываем пустой map если данные ещё загружаются
    final lessonsMap = lessonsByDay ?? <DateTime, List<Lesson>>{};

    // Применяем фильтры к занятиям каждого дня
    final filteredLessonsByDay = <DateTime, List<Lesson>>{};
    for (final entry in lessonsMap.entries) {
      filteredLessonsByDay[entry.key] = _filters.isEmpty
          ? entry.value
          : entry.value.where((l) => _filters.matchesLesson(l)).toList();
    }

    // Вычисляем эффективные часы для всей недели
    final allLessons = lessonsMap.values.expand((list) => list).toList();
    final effectiveHours = _calculateEffectiveHours(
      lessons: allLessons,
      workStartHour: workStartHour,
      workEndHour: workEndHour,
    );

    return _WeekTimeGrid(
      key: ValueKey('week_grid_$_scrollResetKey'), // Для принудительного сброса скролла
      rooms: _selectedRoomId != null
          ? rooms.where((r) => r.id == _selectedRoomId).toList()
          : rooms,
      allRooms: rooms,
      lessonsByDay: filteredLessonsByDay,
      weekStart: weekStart,
      institutionId: widget.institutionId,
      selectedRoomId: _selectedRoomId,
      restoreScrollOffset: _savedScrollOffset,
      canManageRooms: canManageRooms,
      startHour: effectiveHours.$1,
      endHour: effectiveHours.$2,
      teacherColors: teacherColors,
      onRoomTap: (roomId, currentOffset) {
        setState(() {
          // Всегда сохраняем текущую позицию скролла
          _savedScrollOffset = currentOffset;
          if (_selectedRoomId == roomId) {
            // Возвращаемся к общему виду
            _selectedRoomId = null;
          } else {
            // Переходим к одному кабинету
            _selectedRoomId = roomId;
          }
        });
      },
      onCellTap: (room, date) {
        // Переключаемся на дневной вид с выбранной датой и кабинетом
        setState(() {
          _selectedDate = date;
          _selectedRoomId = room.id;
          _viewMode = ScheduleViewMode.day;
        });
      },
      onAddRoom: _showAddRoomBottomSheet,
    );
  }

  void _showLessonDetail(Lesson lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LessonDetailSheet(
        lesson: lesson,
        institutionId: widget.institutionId,
        onUpdated: () {
          // Инвалидируем оба провайдера для гарантированного обновления
          ref.invalidate(lessonsByInstitutionProvider(
            InstitutionDateParams(widget.institutionId, _selectedDate),
          ));
          ref.invalidate(lessonsByInstitutionStreamProvider(
            InstitutionDateParams(widget.institutionId, _selectedDate),
          ));
        },
      ),
    );
  }

  void _showBookingDetail(Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BookingDetailSheet(
        booking: booking,
        institutionId: widget.institutionId,
        onUpdated: () {
          ref.invalidate(bookingsByInstitutionDateProvider(
            InstitutionDateParams(widget.institutionId, _selectedDate),
          ));
        },
      ),
    );
  }

  void _showAddLessonSheet(Room room, int hour, int minute, {List<Room>? allRooms}) {
    // Инвалидируем кеш справочников для получения актуальных данных
    ref.invalidate(subjectsProvider(widget.institutionId));
    ref.invalidate(lessonTypesProvider(widget.institutionId));

    final rooms = allRooms ?? [room];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuickAddLessonSheet(
        rooms: rooms,
        initialDate: _selectedDate,
        institutionId: widget.institutionId,
        preselectedRoom: room,
        preselectedStartHour: hour,
        preselectedStartMinute: minute,
        onCreated: (DateTime createdDate) {
          // Инвалидируем оба провайдера для гарантированного обновления
          ref.invalidate(lessonsByInstitutionProvider(
            InstitutionDateParams(widget.institutionId, createdDate),
          ));
          ref.invalidate(lessonsByInstitutionStreamProvider(
            InstitutionDateParams(widget.institutionId, createdDate),
          ));
          // Также инвалидируем для текущей выбранной даты
          if (createdDate != _selectedDate) {
            ref.invalidate(lessonsByInstitutionProvider(
              InstitutionDateParams(widget.institutionId, _selectedDate),
            ));
            ref.invalidate(lessonsByInstitutionStreamProvider(
              InstitutionDateParams(widget.institutionId, _selectedDate),
            ));
          }
          // Инвалидируем бронирования
          ref.invalidate(bookingsByInstitutionDateProvider(
            InstitutionDateParams(widget.institutionId, _selectedDate),
          ));
        },
      ),
    );
  }

  /// Создаёт FAB с меню (занятие или бронь)
  Widget? _buildFAB({
    required bool isOwner,
    required MemberPermissions? permissions,
    required List<Room> rooms,
  }) {
    // Не показываем FAB если нет кабинетов - сначала нужно создать кабинет
    if (rooms.isEmpty) return null;

    final canCreateLessons = isOwner || (permissions?.createLessons ?? false);
    final canCreateBookings = isOwner || (permissions?.createBookings ?? false);

    if (!canCreateLessons && !canCreateBookings) return null;

    // Открываем единую форму с переключателем режима
    return FloatingActionButton(
      onPressed: () => _showQuickAddLessonSheet(rooms),
      tooltip: 'Добавить',
      child: const Icon(Icons.add),
    );
  }

  /// Показывает форму быстрого добавления занятия (из FAB)
  void _showQuickAddLessonSheet(List<Room> rooms) {
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте кабинет'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Инвалидируем кеш справочников для получения актуальных данных
    ref.invalidate(subjectsProvider(widget.institutionId));
    ref.invalidate(lessonTypesProvider(widget.institutionId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuickAddLessonSheet(
        rooms: rooms,
        initialDate: _selectedDate,
        institutionId: widget.institutionId,
        onCreated: (DateTime createdDate) {
          // Инвалидируем провайдеры для выбранной даты
          ref.invalidate(lessonsByInstitutionProvider(
            InstitutionDateParams(widget.institutionId, createdDate),
          ));
          ref.invalidate(lessonsByInstitutionStreamProvider(
            InstitutionDateParams(widget.institutionId, createdDate),
          ));
          // Также инвалидируем для текущей выбранной даты
          if (createdDate != _selectedDate) {
            ref.invalidate(lessonsByInstitutionProvider(
              InstitutionDateParams(widget.institutionId, _selectedDate),
            ));
            ref.invalidate(lessonsByInstitutionStreamProvider(
              InstitutionDateParams(widget.institutionId, _selectedDate),
            ));
          }
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _preloadAdjacentDates();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        institutionId: widget.institutionId,
        currentFilters: _filters,
        onApply: (filters) {
          setState(() => _filters = filters);
        },
      ),
    );
  }

  void _showAddRoomBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _QuickAddRoomSheet(
        institutionId: widget.institutionId,
        onRoomCreated: (room) {
          ref.invalidate(roomsProvider(widget.institutionId));
        },
      ),
    );
  }
}

/// Вкладки переключения режима просмотра
class _ViewModeTabs extends StatelessWidget {
  final ScheduleViewMode viewMode;
  final ValueChanged<ScheduleViewMode> onChanged;

  const _ViewModeTabs({
    required this.viewMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<ScheduleViewMode>(
        segments: const [
          ButtonSegment(
            value: ScheduleViewMode.day,
            label: Text('День'),
            icon: Icon(Icons.view_day),
          ),
          ButtonSegment(
            value: ScheduleViewMode.week,
            label: Text('Неделя'),
            icon: Icon(Icons.view_week),
          ),
        ],
        selected: {viewMode},
        onSelectionChanged: (selected) {
          onChanged(selected.first);
        },
        showSelectedIcon: false,
      ),
    );
  }
}

/// Селектор недели
class _WeekSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onWeekChanged;

  const _WeekSelector({
    required this.selectedDate,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = InstitutionWeekParams.getWeekStart(selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              onWeekChanged(weekStart.subtract(const Duration(days: 7)));
            },
          ),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                onWeekChanged(InstitutionWeekParams.getWeekStart(date));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${AppDateUtils.formatDayMonth(weekStart)} — ${AppDateUtils.formatDayMonth(weekEnd)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              onWeekChanged(weekStart.add(const Duration(days: 7)));
            },
          ),
        ],
      ),
    );
  }
}

class _WeekDaySelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int scrollToTodayKey;

  const _WeekDaySelector({
    required this.selectedDate,
    required this.onDateSelected,
    this.scrollToTodayKey = 0,
  });

  @override
  State<_WeekDaySelector> createState() => _WeekDaySelectorState();
}

class _WeekDaySelectorState extends State<_WeekDaySelector> {
  static const int _daysRange = 365; // Дней в каждую сторону
  static const double _itemWidth = 56.0; // Ширина элемента + отступы

  late ScrollController _scrollController;
  late DateTime _baseDate;

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now();
    _scrollController = ScrollController(
      initialScrollOffset: _calculateOffset(widget.selectedDate),
    );
  }

  @override
  void didUpdateWidget(_WeekDaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Прокручиваем к сегодня при нажатии кнопки "Сегодня" (scrollToTodayKey изменился)
    // или при изменении даты на сегодняшнюю
    final keyChanged = oldWidget.scrollToTodayKey != widget.scrollToTodayKey;
    final dateChangedToToday = !AppDateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate) &&
        AppDateUtils.isToday(widget.selectedDate);

    if (keyChanged || dateChangedToToday) {
      // Плавно прокручиваем к сегодня
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _calculateOffset(widget.selectedDate),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  double _calculateOffset(DateTime date) {
    final diff = date.difference(_baseDate).inDays;
    // Центрируем выбранную дату (учитываем диапазон + смещение к центру экрана)
    return (_daysRange + diff) * _itemWidth;
  }

  DateTime _getDateForIndex(int index) {
    return _baseDate.add(Duration(days: index - _daysRange));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: _daysRange * 2 + 1, // 365 назад + сегодня + 365 вперёд
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final date = _getDateForIndex(index);
          final isSelected = AppDateUtils.isSameDay(date, widget.selectedDate);
          final isToday = AppDateUtils.isToday(date);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: InkWell(
              onTap: () => widget.onDateSelected(date),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : null,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  border: isToday && !isSelected
                      ? Border.all(color: AppColors.primary)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppDateUtils.formatShortWeekday(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AllRoomsTimeGrid extends StatefulWidget {
  final List<Room> rooms; // Отфильтрованные кабинеты для отображения в сетке
  final List<Room> allRooms; // Все кабинеты для заголовков
  final List<Lesson> lessons;
  final List<Booking> bookings;
  final DateTime selectedDate;
  final String institutionId;
  final String? selectedRoomId;
  final double? restoreScrollOffset; // Позиция скролла для восстановления
  final bool canManageRooms; // Может ли пользователь управлять кабинетами
  final int startHour;
  final int endHour;
  final Map<String, String?> teacherColors; // userId → hex color
  final void Function(Lesson) onLessonTap;
  final void Function(Booking) onBookingTap;
  final void Function(String roomId, double currentOffset) onRoomTap;
  final void Function(Room room, int hour, int minute) onAddLesson;
  final VoidCallback? onAddRoom;

  const _AllRoomsTimeGrid({
    super.key,
    required this.rooms,
    required this.allRooms,
    required this.lessons,
    required this.bookings,
    required this.selectedDate,
    required this.institutionId,
    required this.onLessonTap,
    required this.onBookingTap,
    required this.onRoomTap,
    required this.onAddLesson,
    required this.startHour,
    required this.endHour,
    required this.teacherColors,
    this.selectedRoomId,
    this.restoreScrollOffset,
    this.canManageRooms = false,
    this.onAddRoom,
  });

  static const hourHeight = 100.0; // 15 мин = 25px, время скрывается для коротких
  static const roomColumnWidth = 120.0; // Базовая ширина для многих кабинетов

  @override
  State<_AllRoomsTimeGrid> createState() => _AllRoomsTimeGridState();
}

class _AllRoomsTimeGridState extends State<_AllRoomsTimeGrid> {
  late ScrollController _headerScrollController;
  late ScrollController _gridScrollController;
  bool _isSyncing = false;
  double _lastScrollOffset = 0.0; // Храним последнюю позицию скролла

  @override
  void initState() {
    super.initState();
    // Создаём контроллеры с начальной позицией только если показываем все кабинеты
    // При просмотре одного кабинета скролл не нужен (initialOffset = 0)
    final initialOffset = (widget.selectedRoomId == null && widget.restoreScrollOffset != null)
        ? widget.restoreScrollOffset!
        : 0.0;
    _headerScrollController = ScrollController(initialScrollOffset: initialOffset);
    _gridScrollController = ScrollController(initialScrollOffset: initialOffset);
    // Синхронизация заголовков -> сетка
    _headerScrollController.addListener(_syncGridFromHeader);
    // Синхронизация сетки -> заголовки
    _gridScrollController.addListener(_syncHeaderFromGrid);
  }

  @override
  void didUpdateWidget(covariant _AllRoomsTimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если вернулись из одиночного режима и есть сохранённая позиция
    if (oldWidget.selectedRoomId != null &&
        widget.selectedRoomId == null &&
        widget.restoreScrollOffset != null) {
      // Пересоздаём контроллеры с правильным offset для избежания визуального прыжка
      _recreateControllersWithOffset(widget.restoreScrollOffset!);
    }
  }

  void _recreateControllersWithOffset(double offset) {
    // Удаляем старые listeners
    _headerScrollController.removeListener(_syncGridFromHeader);
    _gridScrollController.removeListener(_syncHeaderFromGrid);

    // Dispose старых контроллеров
    _headerScrollController.dispose();
    _gridScrollController.dispose();

    // Создаём новые контроллеры с нужным offset
    _headerScrollController = ScrollController(initialScrollOffset: offset);
    _gridScrollController = ScrollController(initialScrollOffset: offset);

    // Добавляем listeners обратно
    _headerScrollController.addListener(_syncGridFromHeader);
    _gridScrollController.addListener(_syncHeaderFromGrid);
  }

  void _syncGridFromHeader() {
    if (_isSyncing) return;
    // Не синхронизируем когда выбран один кабинет (разные ширины)
    if (widget.selectedRoomId != null) return;
    _isSyncing = true;
    _lastScrollOffset = _headerScrollController.offset; // Сохраняем позицию
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(_headerScrollController.offset);
    }
    _isSyncing = false;
  }

  void _syncHeaderFromGrid() {
    if (_isSyncing) return;
    // Не синхронизируем когда выбран один кабинет (разные ширины)
    if (widget.selectedRoomId != null) return;
    _isSyncing = true;
    _lastScrollOffset = _gridScrollController.offset; // Сохраняем позицию
    if (_headerScrollController.hasClients) {
      _headerScrollController.jumpTo(_gridScrollController.offset);
    }
    _isSyncing = false;
  }

  @override
  void dispose() {
    _headerScrollController.removeListener(_syncGridFromHeader);
    _gridScrollController.removeListener(_syncHeaderFromGrid);
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.rooms;
    final lessons = widget.lessons;
    final bookings = widget.bookings;
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.meeting_room_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет кабинетов',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (widget.canManageRooms && widget.onAddRoom != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddRoom,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить кабинет'),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final totalHeight = (widget.endHour - widget.startHour + 1) * _AllRoomsTimeGrid.hourHeight;

    // Если выбран один кабинет - используем всю доступную ширину
    return LayoutBuilder(builder: (context, constraints) {
      // Доступная ширина для колонки кабинета (минус ширина временной шкалы)
      final availableWidth = constraints.maxWidth - AppSizes.timeGridWidth;

      // Проверяем, помещаются ли все кабинеты на экран с фиксированной шириной
      final fitsOnScreen = rooms.length * _AllRoomsTimeGrid.roomColumnWidth <= availableWidth;

      // Расширяем колонки на весь экран если:
      // 1. Выбран один кабинет (через фильтр)
      // 2. ИЛИ все кабинеты помещаются на экран
      final isSingleRoom = widget.selectedRoomId != null && rooms.length == 1;
      final shouldExpandColumns = isSingleRoom || fitsOnScreen;

      final roomColumnWidth = shouldExpandColumns
          ? availableWidth / rooms.length
          : _AllRoomsTimeGrid.roomColumnWidth;

    return Column(
      children: [
        // Заголовки кабинетов
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Row(
            children: [
              // Пустое место над временной шкалой
              SizedBox(width: AppSizes.timeGridWidth),
              // Заголовки кабинетов (кликабельные для фильтрации)
              Expanded(
                child: shouldExpandColumns
                    ? Row(
                        children: [
                          for (int index = 0; index < rooms.length; index++)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  widget.onRoomTap(rooms[index].id, _lastScrollOffset);
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: widget.selectedRoomId == rooms[index].id
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : null,
                                    border: Border(
                                      left: BorderSide(
                                        color: index == 0 ? Colors.transparent : AppColors.border,
                                        width: 0.5,
                                      ),
                                      bottom: widget.selectedRoomId == rooms[index].id
                                          ? BorderSide(color: AppColors.primary, width: 2)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Text(
                                    rooms[index].number != null
                                        ? '№${rooms[index].number}'
                                        : rooms[index].name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: widget.selectedRoomId == rooms[index].id
                                          ? AppColors.primary
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : SingleChildScrollView(
                        controller: _headerScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: rooms.length * roomColumnWidth,
                          child: Row(
                            children: [
                              for (int index = 0; index < widget.rooms.length; index++)
                                GestureDetector(
                                  onTap: () {
                                    // Сохраняем текущую позицию перед переключением
                                    if (_headerScrollController.hasClients) {
                                      _lastScrollOffset = _headerScrollController.offset;
                                    }
                                    widget.onRoomTap(widget.rooms[index].id, _lastScrollOffset);
                                  },
                                  child: Container(
                                    // Заголовки используют вычисленную ширину
                                    width: roomColumnWidth,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: widget.selectedRoomId == widget.rooms[index].id
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : null,
                                      border: Border(
                                        left: BorderSide(
                                          color: index == 0 ? Colors.transparent : AppColors.border,
                                          width: 0.5,
                                        ),
                                        bottom: widget.selectedRoomId == widget.rooms[index].id
                                            ? BorderSide(color: AppColors.primary, width: 2)
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Text(
                                      widget.rooms[index].number != null
                                          ? '№${widget.rooms[index].number}'
                                          : widget.rooms[index].name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: widget.selectedRoomId == widget.rooms[index].id
                                            ? AppColors.primary
                                            : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        // Сетка расписания
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: totalHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Временная шкала слева
                  SizedBox(
                    width: AppSizes.timeGridWidth,
                    child: Column(
                      children: [
                        for (int hour = widget.startHour; hour <= widget.endHour; hour++)
                          SizedBox(
                            height: _AllRoomsTimeGrid.hourHeight,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Колонки кабинетов
                  Expanded(
                    child: shouldExpandColumns
                        ? Stack(
                            children: [
                              // Сетка с кликабельными ячейками
                              Row(
                                children: [
                                  for (int i = 0; i < rooms.length; i++)
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: i == 0 ? Colors.transparent : AppColors.border,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            for (int hour = widget.startHour; hour <= widget.endHour; hour++)
                                              _buildCell(rooms[i], hour, lessons, bookings),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // Занятия
                              ...lessons.map((lesson) => _buildLessonBlock(context, lesson, roomColumnWidth)),
                              // Брони
                              ...bookings.expand((booking) => _buildBookingBlocks(context, booking, rooms, roomColumnWidth)),
                            ],
                          )
                        : SingleChildScrollView(
                            controller: _gridScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: rooms.length * roomColumnWidth,
                              child: Stack(
                                children: [
                                  // Сетка с кликабельными ячейками
                                  Row(
                                    children: [
                                      for (int i = 0; i < rooms.length; i++)
                                        Container(
                                          width: roomColumnWidth,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: i == 0 ? Colors.transparent : AppColors.border,
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              for (int hour = widget.startHour; hour <= widget.endHour; hour++)
                                                _buildCell(rooms[i], hour, lessons, bookings),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Занятия
                                  ...lessons.map((lesson) => _buildLessonBlock(context, lesson, roomColumnWidth)),
                                  // Брони
                                  ...bookings.expand((booking) => _buildBookingBlocks(context, booking, rooms, roomColumnWidth)),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    }); // LayoutBuilder
  }

  /// Находит наибольший свободный промежуток в ячейке часа
  /// Возвращает (startMinuteInHour, endMinuteInHour) или null если нет свободного места >= 15 мин
  ({int start, int end})? _findLargestGapInHour(Room room, int hour, List<Lesson> lessons, List<Booking> bookings) {
    const minGapMinutes = 15;
    final hourStart = hour * 60;
    final hourEnd = (hour + 1) * 60;

    // Собираем занятые интервалы в этом часе
    final occupiedIntervals = <({int start, int end})>[];

    for (final lesson in lessons) {
      if (lesson.roomId != room.id) continue;

      final lessonStart = lesson.startTime.hour * 60 + lesson.startTime.minute;
      final lessonEnd = lesson.endTime.hour * 60 + lesson.endTime.minute;

      // Пересекается ли занятие с этим часом?
      if (lessonEnd > hourStart && lessonStart < hourEnd) {
        occupiedIntervals.add((
          start: lessonStart.clamp(hourStart, hourEnd),
          end: lessonEnd.clamp(hourStart, hourEnd),
        ));
      }
    }

    // Добавляем брони как занятые интервалы
    for (final booking in bookings) {
      // Проверяем, относится ли бронь к этому кабинету
      final hasRoom = booking.rooms.any((r) => r.id == room.id);
      if (!hasRoom) continue;

      final bookingStart = booking.startTime.hour * 60 + booking.startTime.minute;
      final bookingEnd = booking.endTime.hour * 60 + booking.endTime.minute;

      // Пересекается ли бронь с этим часом?
      if (bookingEnd > hourStart && bookingStart < hourEnd) {
        occupiedIntervals.add((
          start: bookingStart.clamp(hourStart, hourEnd),
          end: bookingEnd.clamp(hourStart, hourEnd),
        ));
      }
    }

    if (occupiedIntervals.isEmpty) {
      // Весь час свободен
      return (start: 0, end: 60);
    }

    // Сортируем по времени начала
    occupiedIntervals.sort((a, b) => a.start.compareTo(b.start));

    // Находим промежутки
    final gaps = <({int start, int end})>[];

    // До первого занятия
    if (occupiedIntervals.first.start > hourStart) {
      gaps.add((start: 0, end: occupiedIntervals.first.start - hourStart));
    }

    // Между занятиями
    for (int i = 0; i < occupiedIntervals.length - 1; i++) {
      final gapStart = occupiedIntervals[i].end;
      final gapEnd = occupiedIntervals[i + 1].start;
      if (gapEnd > gapStart) {
        gaps.add((start: gapStart - hourStart, end: gapEnd - hourStart));
      }
    }

    // После последнего занятия
    if (occupiedIntervals.last.end < hourEnd) {
      gaps.add((start: occupiedIntervals.last.end - hourStart, end: 60));
    }

    // Находим наибольший промежуток >= minGapMinutes
    ({int start, int end})? largest;
    int largestSize = 0;

    for (final gap in gaps) {
      final size = gap.end - gap.start;
      if (size >= minGapMinutes && size > largestSize) {
        largestSize = size;
        largest = gap;
      }
    }

    return largest;
  }

  Widget _buildCell(Room room, int hour, List<Lesson> lessons, List<Booking> bookings) {
    final gap = _findLargestGapInHour(room, hour, lessons, bookings);

    if (gap == null) {
      // Нет свободного места >= 15 мин
      return Container(
        height: _AllRoomsTimeGrid.hourHeight,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
      );
    }

    // Вычисляем позицию "+" в центре свободного промежутка
    final gapCenterMinute = (gap.start + gap.end) / 2;
    final buttonTopOffset = gapCenterMinute / 60 * _AllRoomsTimeGrid.hourHeight - 8;

    return GestureDetector(
      onTap: () => widget.onAddLesson(room, hour, gap.start),
      child: Container(
        height: _AllRoomsTimeGrid.hourHeight,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: buttonTopOffset.clamp(0, _AllRoomsTimeGrid.hourHeight - 16),
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonBlock(BuildContext context, Lesson lesson, double roomColumnWidth) {
    final roomIndex = widget.rooms.indexWhere((r) => r.id == lesson.roomId);
    if (roomIndex == -1) return const SizedBox.shrink();

    final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final startOffset = (startMinutes - widget.startHour * 60) / 60 * _AllRoomsTimeGrid.hourHeight;
    final duration = durationMinutes / 60 * _AllRoomsTimeGrid.hourHeight;

    // Показываем время только для занятий >= 30 минут
    final showTime = durationMinutes >= 30;

    final color = _getLessonColor(lesson);
    final participant = lesson.student?.name ?? lesson.group?.name ?? 'Занятие';

    // Для коротких занятий уменьшаем padding
    final isShort = durationMinutes < 30;
    final verticalPadding = isShort ? 2.0 : 4.0;
    final horizontalPadding = isShort ? 3.0 : 4.0;
    final fontSize = isShort ? 9.0 : 10.0;
    final iconSize = isShort ? 10.0 : 12.0;

    return Positioned(
      top: startOffset,
      left: roomIndex * roomColumnWidth + 2,
      width: roomColumnWidth - 4,
      child: GestureDetector(
        onTap: () => widget.onLessonTap(lesson),
        child: Container(
          height: duration,
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: horizontalPadding,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        participant,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (lesson.isRepeating)
                      Icon(Icons.repeat, size: iconSize, color: AppColors.textSecondary),
                    if (lesson.status == LessonStatus.completed)
                      Icon(Icons.check_circle, size: iconSize, color: AppColors.success),
                    if (lesson.status == LessonStatus.cancelled)
                      Icon(Icons.cancel, size: iconSize, color: AppColors.error),
                  ],
                ),
              ),
              if (showTime)
                Text(
                  '${_formatTime(lesson.startTime)}-${_formatTime(lesson.endTime)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Возвращает основной цвет занятия (цвет преподавателя или fallback)
  Color _getLessonColor(Lesson lesson) {
    // Цвет преподавателя (если есть)
    final teacherColor = widget.teacherColors[lesson.teacherId];
    if (teacherColor != null && teacherColor.isNotEmpty) {
      try {
        return Color(int.parse('FF${teacherColor.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    // Fallback на старую логику
    if (lesson.group != null) {
      return AppColors.lessonGroup;
    }
    return AppColors.lessonIndividual;
  }

  /// Создаёт блоки для брони (один блок на каждый кабинет)
  List<Widget> _buildBookingBlocks(
    BuildContext context,
    Booking booking,
    List<Room> rooms,
    double roomColumnWidth,
  ) {
    final widgets = <Widget>[];

    for (final room in booking.rooms) {
      final roomIndex = rooms.indexWhere((r) => r.id == room.id);
      if (roomIndex == -1) continue;

      final startMinutes = booking.startTime.hour * 60 + booking.startTime.minute;
      final endMinutes = booking.endTime.hour * 60 + booking.endTime.minute;
      final durationMinutes = endMinutes - startMinutes;
      final startOffset = (startMinutes - widget.startHour * 60) / 60 * _AllRoomsTimeGrid.hourHeight;
      final duration = durationMinutes / 60 * _AllRoomsTimeGrid.hourHeight;

      // Показываем время только для броней >= 30 минут
      final showTime = durationMinutes >= 30;

      // Для коротких броней уменьшаем padding
      final isShort = durationMinutes < 30;
      final verticalPadding = isShort ? 2.0 : 4.0;
      final horizontalPadding = isShort ? 3.0 : 4.0;
      final fontSize = isShort ? 9.0 : 10.0;
      final iconSize = isShort ? 10.0 : 12.0;

      widgets.add(
        Positioned(
          top: startOffset,
          left: roomIndex * roomColumnWidth + 2,
          width: roomColumnWidth - 4,
          child: GestureDetector(
            onTap: () => widget.onBookingTap(booking),
            child: Container(
              height: duration,
              clipBehavior: Clip.hardEdge,
              padding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: horizontalPadding,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                border: Border.all(color: Colors.grey, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: iconSize, color: Colors.grey[700]),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            booking.description ?? 'Забронировано',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showTime)
                    Text(
                      booking.creator?.fullName ?? '',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isShort ? 8.0 : 9.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

/// Сетка расписания на неделю
class _WeekTimeGrid extends StatefulWidget {
  final List<Room> rooms;
  final List<Room> allRooms;
  final Map<DateTime, List<Lesson>> lessonsByDay;
  final DateTime weekStart;
  final String institutionId;
  final String? selectedRoomId;
  final double? restoreScrollOffset; // Позиция скролла для восстановления
  final bool canManageRooms; // Может ли пользователь управлять кабинетами
  final int startHour;
  final int endHour;
  final Map<String, String?> teacherColors; // userId → hex color
  final void Function(String roomId, double currentOffset) onRoomTap;
  final void Function(Room room, DateTime date) onCellTap;
  final VoidCallback? onAddRoom;

  const _WeekTimeGrid({
    super.key,
    required this.rooms,
    required this.allRooms,
    required this.lessonsByDay,
    required this.weekStart,
    required this.institutionId,
    required this.onRoomTap,
    required this.onCellTap,
    required this.startHour,
    required this.endHour,
    required this.teacherColors,
    this.selectedRoomId,
    this.restoreScrollOffset,
    this.canManageRooms = false,
    this.onAddRoom,
  });

  static const minRoomColumnWidth = 100.0;
  static const dayLabelWidth = 60.0;
  static const lessonItemHeight = 20.0; // Высота одного занятия
  static const minRowHeight = 50.0; // Минимальная высота строки

  @override
  State<_WeekTimeGrid> createState() => _WeekTimeGridState();
}

class _WeekTimeGridState extends State<_WeekTimeGrid> {
  late ScrollController _headerScrollController;
  late List<ScrollController> _dayControllers;
  bool _isSyncing = false;
  double _lastScrollOffset = 0.0; // Храним последнюю позицию скролла

  static const _weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    // Создаём контроллеры с начальной позицией только если показываем все кабинеты
    // При просмотре одного кабинета скролл не нужен (initialOffset = 0)
    final initialOffset = (widget.selectedRoomId == null && widget.restoreScrollOffset != null)
        ? widget.restoreScrollOffset!
        : 0.0;
    _headerScrollController = ScrollController(initialScrollOffset: initialOffset);
    _dayControllers = List.generate(
      7,
      (_) => ScrollController(initialScrollOffset: initialOffset),
    );
    // Добавляем listeners для всех контроллеров дней
    for (int i = 0; i < _dayControllers.length; i++) {
      _dayControllers[i].addListener(() => _syncFromDay(i));
    }
    // Добавляем listener для заголовка
    _headerScrollController.addListener(_syncFromHeader);
  }

  @override
  void didUpdateWidget(covariant _WeekTimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если вернулись из одиночного режима и есть сохранённая позиция
    if (oldWidget.selectedRoomId != null &&
        widget.selectedRoomId == null &&
        widget.restoreScrollOffset != null) {
      // Пересоздаём контроллеры с правильным offset для избежания визуального прыжка
      _recreateControllersWithOffset(widget.restoreScrollOffset!);
    }
  }

  void _recreateControllersWithOffset(double offset) {
    // Удаляем старые listeners
    _headerScrollController.removeListener(_syncFromHeader);
    for (int i = 0; i < _dayControllers.length; i++) {
      _dayControllers[i].removeListener(() => _syncFromDay(i));
    }

    // Dispose старых контроллеров
    _headerScrollController.dispose();
    for (final controller in _dayControllers) {
      controller.dispose();
    }

    // Создаём новые контроллеры с нужным offset
    _headerScrollController = ScrollController(initialScrollOffset: offset);
    _dayControllers = List.generate(
      7,
      (_) => ScrollController(initialScrollOffset: offset),
    );

    // Добавляем listeners обратно
    for (int i = 0; i < _dayControllers.length; i++) {
      _dayControllers[i].addListener(() => _syncFromDay(i));
    }
    _headerScrollController.addListener(_syncFromHeader);
  }

  void _syncFromHeader() {
    if (_isSyncing) return;
    if (!_headerScrollController.hasClients) return;

    _isSyncing = true;

    final offset = _headerScrollController.offset;
    _lastScrollOffset = offset; // Сохраняем позицию

    // Синхронизируем все дни с заголовком
    for (int i = 0; i < _dayControllers.length; i++) {
      if (_dayControllers[i].hasClients) {
        _dayControllers[i].jumpTo(offset);
      }
    }

    _isSyncing = false;
  }

  void _syncFromDay(int sourceIndex) {
    if (_isSyncing) return;
    if (!_dayControllers[sourceIndex].hasClients) return;

    _isSyncing = true;

    final offset = _dayControllers[sourceIndex].offset;
    _lastScrollOffset = offset; // Сохраняем позицию

    // Синхронизируем заголовок
    if (_headerScrollController.hasClients) {
      _headerScrollController.jumpTo(offset);
    }

    // Синхронизируем все остальные дни
    for (int i = 0; i < _dayControllers.length; i++) {
      if (i != sourceIndex && _dayControllers[i].hasClients) {
        _dayControllers[i].jumpTo(offset);
      }
    }

    _isSyncing = false;
  }

  @override
  void dispose() {
    // Удаляем listeners от всех контроллеров
    for (final controller in _dayControllers) {
      controller.dispose();
    }
    _headerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.rooms;
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.meeting_room_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет кабинетов',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (widget.canManageRooms && widget.onAddRoom != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddRoom,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить кабинет'),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Вычисляем высоту каждой строки на основе максимального количества занятий
        final baseRowHeights = <int, double>{};
        for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
          final date = widget.weekStart.add(Duration(days: dayIndex));
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final dayLessons = widget.lessonsByDay[normalizedDate] ?? [];

          int maxLessons = 0;
          for (final room in rooms) {
            final count = dayLessons.where((l) => l.roomId == room.id).length;
            if (count > maxLessons) maxLessons = count;
          }

          baseRowHeights[dayIndex] = maxLessons > 0
              ? (maxLessons * _WeekTimeGrid.lessonItemHeight + 8).clamp(_WeekTimeGrid.minRowHeight, double.infinity)
              : _WeekTimeGrid.minRowHeight;
        }

        // Вычисляем доступную высоту для строк дней (минус заголовок 40px)
        const headerHeight = 40.0;
        final availableHeight = constraints.maxHeight - headerHeight;
        final totalMinHeight = baseRowHeights.values.fold(0.0, (sum, h) => sum + h);

        // Если контента мало - растягиваем строки на всю доступную высоту
        final rowHeights = <int, double>{};
        if (totalMinHeight < availableHeight) {
          // Масштабируем пропорционально базовой высоте каждого дня
          final scale = availableHeight / totalMinHeight;
          for (var i = 0; i < 7; i++) {
            rowHeights[i] = baseRowHeights[i]! * scale;
          }
        } else {
          rowHeights.addAll(baseRowHeights);
        }

        // Проверяем, помещаются ли все кабинеты на экран
        final availableWidth = constraints.maxWidth - _WeekTimeGrid.dayLabelWidth;
        final fitsOnScreen = rooms.length * _WeekTimeGrid.minRoomColumnWidth <= availableWidth;

        // Расширяем колонки если все помещаются
        final roomColumnWidth = fitsOnScreen
            ? availableWidth / rooms.length
            : _WeekTimeGrid.minRoomColumnWidth;
        final totalWidth = rooms.length * roomColumnWidth;

        return Column(
          children: [
            // Заголовки кабинетов (всегда показываем все, как в режиме День)
            Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Row(
                children: [
                  // Пустой угол
                  Container(
                    width: _WeekTimeGrid.dayLabelWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Text(
                      'Неделя',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Заголовки кабинетов
                  Expanded(
                    child: fitsOnScreen
                        ? _buildRoomHeaders(widget.rooms, roomColumnWidth, expandColumns: true)
                        : SingleChildScrollView(
                            controller: _headerScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: totalWidth,
                              child: _buildRoomHeaders(widget.rooms, roomColumnWidth),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // Сетка дней и занятий
            Expanded(
              child: _buildDaysGrid(
                rooms: rooms,
                rowHeights: rowHeights,
                totalMinHeight: totalMinHeight,
                availableHeight: availableHeight,
                fitsOnScreen: fitsOnScreen,
                roomColumnWidth: roomColumnWidth,
                totalWidth: totalWidth,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDaysGrid({
    required List<Room> rooms,
    required Map<int, double> rowHeights,
    required double totalMinHeight,
    required double availableHeight,
    required bool fitsOnScreen,
    required double roomColumnWidth,
    required double totalWidth,
  }) {
    final needsVerticalScroll = totalMinHeight > availableHeight;

    Widget buildDayRow(int dayIndex) {
      final date = widget.weekStart.add(Duration(days: dayIndex));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dayLessons = widget.lessonsByDay[normalizedDate] ?? [];
      final isToday = AppDateUtils.isToday(date);
      final rowHeight = rowHeights[dayIndex] ?? _WeekTimeGrid.minRowHeight;

      return Container(
        height: needsVerticalScroll ? rowHeight : null,
        decoration: BoxDecoration(
          color: isToday ? AppColors.primary.withValues(alpha: 0.05) : null,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // День недели слева
            Container(
              width: _WeekTimeGrid.dayLabelWidth,
              height: needsVerticalScroll ? rowHeight : null,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? AppColors.primary.withValues(alpha: 0.1) : null,
                border: const Border(
                  right: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekDays[dayIndex],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isToday ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Ячейки с занятиями
            Expanded(
              child: fitsOnScreen
                  ? _buildDayCells(rooms, dayLessons, date, roomColumnWidth, expandColumns: true)
                  : SingleChildScrollView(
                      controller: _dayControllers[dayIndex],
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: totalWidth,
                        child: _buildDayCells(rooms, dayLessons, date, roomColumnWidth),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    // Если контент не помещается - скроллируемый Column с минимальными высотами
    if (needsVerticalScroll) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: List.generate(7, buildDayRow),
        ),
      );
    }

    // Если помещается - используем рассчитанные высоты (уже с доп. пространством)
    return Column(
      children: List.generate(7, (dayIndex) {
        final date = widget.weekStart.add(Duration(days: dayIndex));
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final dayLessons = widget.lessonsByDay[normalizedDate] ?? [];
        final isToday = AppDateUtils.isToday(date);
        final rowHeight = rowHeights[dayIndex]!;

        return SizedBox(
          height: rowHeight,
          child: Container(
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary.withValues(alpha: 0.05) : null,
              border: const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // День недели слева
                Container(
                  width: _WeekTimeGrid.dayLabelWidth,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary.withValues(alpha: 0.1) : null,
                    border: const Border(
                      right: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekDays[dayIndex],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isToday ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isToday ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Ячейки с занятиями
                Expanded(
                  child: fitsOnScreen
                      ? _buildDayCells(rooms, dayLessons, date, roomColumnWidth, expandColumns: true)
                      : SingleChildScrollView(
                          controller: _dayControllers[dayIndex],
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: totalWidth,
                            child: _buildDayCells(rooms, dayLessons, date, roomColumnWidth),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRoomHeaders(List<Room> rooms, double roomColumnWidth, {bool expandColumns = false}) {
    return Row(
      children: rooms.map((room) {
        final isSelected = widget.selectedRoomId == room.id;
        final content = GestureDetector(
          onTap: () {
            // Сохраняем текущую позицию перед переключением
            if (_headerScrollController.hasClients) {
              _lastScrollOffset = _headerScrollController.offset;
            }
            widget.onRoomTap(room.id, _lastScrollOffset);
          },
          child: Container(
            width: expandColumns ? null : roomColumnWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
              border: Border(
                left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
            ),
            child: Text(
              room.number != null ? '№${room.number}' : room.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
        return expandColumns ? Expanded(child: content) : content;
      }).toList(),
    );
  }

  Widget _buildDayCells(List<Room> rooms, List<Lesson> dayLessons, DateTime date, double roomColumnWidth, {bool expandColumns = false}) {
    return Row(
      children: rooms.map((room) {
        final roomLessons = dayLessons
            .where((l) => l.roomId == room.id)
            .toList()
          ..sort((a, b) {
            final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
            final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
            return aMinutes.compareTo(bMinutes);
          });

        final content = GestureDetector(
          onTap: () => widget.onCellTap(room, date),
          child: Container(
            width: expandColumns ? null : roomColumnWidth,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: roomLessons.isEmpty
                ? const SizedBox.expand()
                : _buildLessonsList(roomLessons),
          ),
        );
        return expandColumns ? Expanded(child: content) : content;
      }).toList(),
    );
  }

  Widget _buildLessonsList(List<Lesson> lessons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: lessons.map((lesson) => Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: _getLessonColor(lesson),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${lesson.startTime.hour}:${lesson.startTime.minute.toString().padLeft(2, '0')} ${lesson.student?.name ?? lesson.group?.name ?? ''}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
    );
  }

  /// Возвращает основной цвет занятия (цвет преподавателя или fallback)
  Color _getLessonColor(Lesson lesson) {
    // Цвет преподавателя (если есть)
    final teacherColor = widget.teacherColors[lesson.teacherId];
    if (teacherColor != null && teacherColor.isNotEmpty) {
      try {
        return Color(int.parse('FF${teacherColor.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    // Fallback на старую логику
    if (lesson.group != null) {
      return AppColors.lessonGroup;
    }
    return AppColors.lessonIndividual;
  }
}

class _LessonDetailSheet extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String institutionId;
  final VoidCallback onUpdated;

  const _LessonDetailSheet({
    required this.lesson,
    required this.institutionId,
    required this.onUpdated,
  });

  @override
  ConsumerState<_LessonDetailSheet> createState() => _LessonDetailSheetState();
}

class _LessonDetailSheetState extends ConsumerState<_LessonDetailSheet> {
  late LessonStatus _currentStatus;
  bool _isPaid = false;
  bool _isLoading = false;
  bool _isLoadingPayment = true;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.lesson.status;
    _loadPaymentStatus();
    // Принудительно обновляем права при открытии
    Future.microtask(() {
      ref.invalidate(myMembershipProvider(widget.institutionId));
    });
  }

  /// Загружаем статус оплаты для этого занятия
  Future<void> _loadPaymentStatus() async {
    final paymentController = ref.read(paymentControllerProvider.notifier);
    final payment = await paymentController.findByLessonId(widget.lesson.id);
    if (mounted) {
      setState(() {
        _isPaid = payment != null;
        _isLoadingPayment = false;
      });
    }
  }

  bool get _isCompleted => _currentStatus == LessonStatus.completed;
  bool get _isCancelled => _currentStatus == LessonStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(lessonControllerProvider);
    final lesson = widget.lesson;
    final timeStr = '${_formatTime(lesson.startTime)} — ${_formatTime(lesson.endTime)}';

    // Проверяем есть ли цена у типа занятия
    final hasPrice = lesson.lessonType?.defaultPrice != null;
    final hasStudent = lesson.studentId != null;

    // Проверка прав на удаление (используем прямой доступ к userId для надёжности)
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final isOwner = institutionAsync.valueOrNull?.ownerId == currentUserId;
    final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final isOwnLesson = currentUserId != null && lesson.teacherId == currentUserId;
    final canDelete = hasFullAccess ||
                      (permissions?.deleteAllLessons ?? false) ||
                      (isOwnLesson && (permissions?.deleteOwnLessons ?? false));

    ref.listen(lessonControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    // Определяем цвет по статусу или преподавателю
    Color accentColor = AppColors.primary;
    if (_isCancelled) {
      accentColor = AppColors.error;
    } else if (_isCompleted) {
      accentColor = AppColors.success;
    }

    final participantName = lesson.student?.name ?? lesson.group?.name ?? 'Занятие';

    // Получаем имя преподавателя из списка участников
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
    final teacherName = membersAsync.maybeWhen(
      data: (members) {
        final teacher = members.where((m) => m.userId == lesson.teacherId).firstOrNull;
        return teacher?.profile?.fullName;
      },
      orElse: () => null,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок с аватаром
                Row(
                  children: [
                    // Аватар участника
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        lesson.group != null ? Icons.groups : Icons.person,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Имя и преподаватель
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            participantName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (teacherName != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.school, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    teacherName,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Кнопка закрытия
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.onUpdated();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Информационная карточка
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Время
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Время',
                        value: timeStr,
                      ),
                      // Кабинет
                      if (lesson.room != null)
                        _DetailRow(
                          icon: Icons.door_front_door_rounded,
                          label: 'Кабинет',
                          value: lesson.room!.number != null
                              ? '№${lesson.room!.number}'
                              : lesson.room!.name,
                        ),
                      // Предмет
                      if (lesson.subject != null)
                        _DetailRow(
                          icon: Icons.music_note_rounded,
                          label: 'Предмет',
                          value: lesson.subject!.name,
                        ),
                      // Тип занятия
                      if (lesson.lessonType != null)
                        _DetailRow(
                          icon: Icons.category_rounded,
                          label: 'Тип',
                          value: lesson.lessonType!.name,
                        ),
                      // Стоимость
                      if (hasPrice)
                        _DetailRow(
                          icon: Icons.payments_rounded,
                          label: 'Стоимость',
                          value: '${lesson.lessonType!.defaultPrice!.toStringAsFixed(0)} ₸',
                          valueColor: AppColors.primary,
                        ),
                      // Повторяющееся
                      if (lesson.isRepeating)
                        _DetailRow(
                          icon: Icons.repeat_rounded,
                          label: 'Повтор',
                          value: 'Да',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Статусы
                Row(
                  children: [
                    // Проведено
                    Expanded(
                      child: _StatusButton(
                        label: 'Проведено',
                        icon: Icons.check_circle_rounded,
                        isActive: _isCompleted,
                        color: AppColors.success,
                        isLoading: _isLoading || controllerState.isLoading,
                        onTap: () => _handleStatusChange(completed: !_isCompleted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Отменено
                    Expanded(
                      child: _StatusButton(
                        label: 'Отменено',
                        icon: Icons.cancel_rounded,
                        isActive: _isCancelled,
                        color: AppColors.error,
                        isLoading: _isLoading || controllerState.isLoading,
                        onTap: () => _handleStatusChange(cancelled: !_isCancelled),
                      ),
                    ),
                    // Оплачено (если есть цена и ученик)
                    if (hasPrice && hasStudent) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatusButton(
                          label: 'Оплачено',
                          icon: Icons.monetization_on_rounded,
                          isActive: _isPaid,
                          color: AppColors.primary,
                          isLoading: _isLoading || controllerState.isLoading || _isLoadingPayment,
                          onTap: () {
                            if (_isPaid) {
                              _handleRemovePayment();
                            } else {
                              _handlePayment();
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Кнопки действий
                Row(
                  children: [
                    // Редактировать
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controllerState.isLoading || _isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (ctx) => _EditLessonSheet(
                                    lesson: lesson,
                                    institutionId: widget.institutionId,
                                    onUpdated: widget.onUpdated,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Изменить'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    // Удалить (только если есть право)
                    if (canDelete) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controllerState.isLoading || _isLoading
                              ? null
                              : _deleteLesson,
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: const Text('Удалить'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (controllerState.isLoading || _isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusChange({bool? completed, bool? cancelled}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final lesson = widget.lesson;
    bool success = false;

    if (completed == true) {
      // Ставим "Проведено" — снимаем "Отменено"
      success = await controller.complete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.completed;
          _isLoading = false;
        });
      }
    } else if (completed == false && _isCompleted) {
      // Снимаем "Проведено" — возвращаем в "Запланировано"
      success = await controller.uncomplete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.scheduled;
          _isLoading = false;
        });
      }
    } else if (cancelled == true) {
      // Ставим "Отменено" — снимаем "Проведено"
      success = await controller.cancel(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.cancelled;
          _isLoading = false;
        });
      }
    } else if (cancelled == false && _isCancelled) {
      // Снимаем "Отменено" — возвращаем в "Запланировано"
      success = await controller.uncomplete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.scheduled;
          _isLoading = false;
        });
      }
    }

    if (!success && mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePayment() async {
    final lesson = widget.lesson;
    if (lesson.studentId == null || lesson.lessonType?.defaultPrice == null) return;

    setState(() => _isLoading = true);

    // Если занятие ещё не проведено — сначала помечаем как проведённое
    if (_currentStatus != LessonStatus.completed) {
      final lessonController = ref.read(lessonControllerProvider.notifier);
      await lessonController.complete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
    }

    // Создаём оплату с lessonId в comment
    // Формат: lesson:LESSON_ID|LESSON_TYPE_NAME
    final paymentController = ref.read(paymentControllerProvider.notifier);
    final lessonTypeName = lesson.lessonType?.name ?? 'Оплата занятия';
    await paymentController.create(
      institutionId: widget.institutionId,
      studentId: lesson.studentId!,
      amount: lesson.lessonType!.defaultPrice!,
      lessonsCount: 1,
      comment: 'lesson:${lesson.id}|$lessonTypeName',
    );

    if (mounted) {
      setState(() {
        _currentStatus = LessonStatus.completed;
        _isPaid = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Оплата добавлена'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleRemovePayment() async {
    final lesson = widget.lesson;

    setState(() => _isLoading = true);

    // Удаляем оплату по lessonId
    final paymentController = ref.read(paymentControllerProvider.notifier);
    final success = await paymentController.deleteByLessonId(
      lesson.id,
      studentId: lesson.studentId,
    );

    if (mounted) {
      setState(() {
        _isPaid = !success;
        _isLoading = false;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оплата удалена'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _deleteLesson() async {
    final lesson = widget.lesson;
    final controller = ref.read(lessonControllerProvider.notifier);

    // Если занятие часть серии — показываем расширенный диалог
    if (lesson.isRepeating) {
      final followingCount = await controller.getFollowingCount(
        lesson.repeatGroupId!,
        lesson.date,
      );

      if (!mounted) return;

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Удалить занятие?'),
          content: Text(
            followingCount > 1
                ? 'Это занятие является частью серии повторяющихся занятий.\n\n'
                    'Удалить только это занятие или это и все последующие ($followingCount шт.)?'
                : 'Занятие будет удалено безвозвратно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            if (followingCount > 1)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('following'),
                child: const Text('Это и все последующие', style: TextStyle(color: Colors.orange)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('single'),
              child: const Text('Только это', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      bool success;
      String message;

      if (result == 'following') {
        success = await controller.deleteFollowing(
          lesson.repeatGroupId!,
          lesson.date,
          lesson.roomId,
          widget.institutionId,
        );
        message = 'Удалено $followingCount занятий';
      } else {
        success = await controller.delete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
        message = 'Занятие удалено';
      }

      if (success && mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Обычное занятие
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Удалить занятие?'),
          content: const Text(
            'Занятие будет удалено безвозвратно. Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final success = await controller.delete(
          lesson.id,
          lesson.roomId,
          lesson.date,
          widget.institutionId,
        );

        if (success && mounted) {
          widget.onUpdated();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Занятие удалено'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Строка детальной информации в карточке занятия
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка статуса занятия (проведено/отменено/оплачено)
class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? color : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? color : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Форма редактирования занятия
class _EditLessonSheet extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String institutionId;
  final VoidCallback onUpdated;

  const _EditLessonSheet({
    required this.lesson,
    required this.institutionId,
    required this.onUpdated,
  });

  @override
  ConsumerState<_EditLessonSheet> createState() => _EditLessonSheetState();
}

class _EditLessonSheetState extends ConsumerState<_EditLessonSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late DateTime _date;
  String? _selectedStudentId;
  String? _selectedSubjectId;
  String? _selectedLessonTypeId;
  String? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    _startTime = widget.lesson.startTime;
    _endTime = widget.lesson.endTime;
    _date = widget.lesson.date;
    _selectedStudentId = widget.lesson.studentId;
    _selectedSubjectId = widget.lesson.subjectId;
    _selectedLessonTypeId = widget.lesson.lessonTypeId;
    _selectedRoomId = widget.lesson.roomId;
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final controllerState = ref.watch(lessonControllerProvider);

    ref.listen(lessonControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Редактировать занятие',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Дата
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(AppDateUtils.formatDayMonth(_date)),
              ),
            ),
            const SizedBox(height: 16),

            // Время
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showIosTimePicker(
                        context: context,
                        initialTime: _startTime,
                        minuteInterval: 5,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                          final endMinutes = time.hour * 60 + time.minute + 60;
                          _endTime = TimeOfDay(
                            hour: endMinutes ~/ 60,
                            minute: endMinutes % 60,
                          );
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Начало',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_formatTime(_startTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showIosTimePicker(
                        context: context,
                        initialTime: _endTime,
                        minuteInterval: 5,
                      );
                      if (time != null) {
                        setState(() => _endTime = time);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Конец',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_formatTime(_endTime)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Кабинет
            roomsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (rooms) {
                final selectedRoom = rooms.where((r) => r.id == _selectedRoomId).firstOrNull;
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Кабинет',
                    prefixIcon: Icon(Icons.door_front_door),
                  ),
                  value: selectedRoom?.id,
                  items: rooms.map((r) => DropdownMenuItem<String>(
                    value: r.id,
                    child: Text(r.number != null ? 'Кабинет ${r.number}' : r.name),
                  )).toList(),
                  onChanged: (roomId) {
                    setState(() => _selectedRoomId = roomId);
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Ученик
            studentsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => ErrorView.inline(e),
              data: (students) {
                final selectedStudent = students.where((s) => s.id == _selectedStudentId).firstOrNull;
                return DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Ученик',
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: selectedStudent?.id,
                  items: students.map((s) => DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text(s.name),
                  )).toList(),
                  onChanged: (studentId) {
                    setState(() => _selectedStudentId = studentId);
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Предмет
            subjectsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (subjects) {
                if (subjects.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Предмет',
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  value: _selectedSubjectId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Не выбран'),
                    ),
                    ...subjects.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.name),
                    )),
                  ],
                  onChanged: (subjectId) {
                    setState(() => _selectedSubjectId = subjectId);
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Тип занятия
            lessonTypesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (lessonTypes) {
                if (lessonTypes.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Тип занятия',
                    prefixIcon: Icon(Icons.category),
                  ),
                  value: _selectedLessonTypeId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Не выбран'),
                    ),
                    ...lessonTypes.map((lt) => DropdownMenuItem<String?>(
                      value: lt.id,
                      child: Text('${lt.name} (${lt.defaultDurationMinutes} мин)'),
                    )),
                  ],
                  onChanged: (lessonTypeId) {
                    setState(() {
                      _selectedLessonTypeId = lessonTypeId;
                      if (lessonTypeId != null) {
                        final lessonType = lessonTypes.where((lt) => lt.id == lessonTypeId).firstOrNull;
                        if (lessonType != null) {
                          final startMinutes = _startTime.hour * 60 + _startTime.minute;
                          final endMinutes = startMinutes + lessonType.defaultDurationMinutes;
                          _endTime = TimeOfDay(
                            hour: endMinutes ~/ 60,
                            minute: endMinutes % 60,
                          );
                        }
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Кнопка сохранения
            ElevatedButton.icon(
              onPressed: controllerState.isLoading ? null : _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить изменения'),
            ),

            if (controllerState.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _date = date);
    }
  }

  Future<void> _saveChanges() async {
    // Проверка минимальной длительности (15 минут)
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    if (durationMinutes < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Минимальная длительность занятия — 15 минут'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final controller = ref.read(lessonControllerProvider.notifier);
    final lesson = widget.lesson;

    // Проверяем, изменилось ли время
    final timeChanged = _startTime != lesson.startTime || _endTime != lesson.endTime;

    // Если занятие повторяющееся и время изменилось - спрашиваем
    if (lesson.isRepeating && timeChanged) {
      final followingCount = await controller.getFollowingCount(
        lesson.repeatGroupId!,
        lesson.date,
      );

      if (!mounted) return;

      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Изменить время'),
          content: Text(
            'Это занятие является частью серии.\n\n'
            'Всего последующих занятий: $followingCount\n\n'
            'Применить изменение времени к последующим занятиям?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'this'),
              child: const Text('Только это'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'following'),
              child: const Text('Это и последующие'),
            ),
          ],
        ),
      );

      if (result == null || result == 'cancel') return;

      bool success;
      String message;

      if (result == 'following') {
        success = await controller.updateFollowing(
          lesson.repeatGroupId!,
          lesson.date,
          lesson.roomId,
          widget.institutionId,
          startTime: _startTime,
          endTime: _endTime,
        );
        message = 'Обновлено $followingCount занятий';
      } else {
        success = await controller.update(
          lesson.id,
          roomId: lesson.roomId,
          date: lesson.date,
          institutionId: widget.institutionId,
          newRoomId: _selectedRoomId,
          newDate: _date,
          startTime: _startTime,
          endTime: _endTime,
          studentId: _selectedStudentId,
          subjectId: _selectedSubjectId,
          lessonTypeId: _selectedLessonTypeId,
        );
        message = 'Занятие обновлено';
      }

      if (success && mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } else {
      // Обычное обновление
      final success = await controller.update(
        lesson.id,
        roomId: lesson.roomId,
        date: lesson.date,
        institutionId: widget.institutionId,
        newRoomId: _selectedRoomId,
        newDate: _date,
        startTime: _startTime,
        endTime: _endTime,
        studentId: _selectedStudentId,
        subjectId: _selectedSubjectId,
        lessonTypeId: _selectedLessonTypeId,
      );

      if (success && mounted) {
        widget.onUpdated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Занятие обновлено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Форма создания нового занятия или бронирования
/// Режим формы: занятие или бронирование
enum _AddFormMode { lesson, booking }

/// Тип повтора занятий
enum RepeatType {
  none('Без повтора'),
  daily('Каждый день'),
  weekly('Каждую неделю'),
  weekdays('По дням недели'),
  custom('Ручной выбор дат');

  final String label;
  const RepeatType(this.label);
}

/// Быстрое добавление кабинета из формы занятия
class _QuickAddRoomSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final void Function(Room room) onRoomCreated;

  const _QuickAddRoomSheet({
    required this.institutionId,
    required this.onRoomCreated,
  });

  @override
  ConsumerState<_QuickAddRoomSheet> createState() => _QuickAddRoomSheetState();
}

class _QuickAddRoomSheetState extends ConsumerState<_QuickAddRoomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(roomControllerProvider.notifier);
      final room = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.isEmpty
            ? 'Кабинет ${_numberController.text}'
            : _nameController.text.trim(),
        number: _numberController.text.trim(),
      );

      if (room != null && mounted) {
        widget.onRoomCreated(room);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Кабинет "${room.number != null ? "№${room.number}" : room.name}" добавлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.meeting_room,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новый кабинет',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Заполните данные кабинета',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Номер кабинета
                TextFormField(
                  controller: _numberController,
                  decoration: InputDecoration(
                    labelText: 'Номер кабинета *',
                    hintText: 'Например: 101',
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  validator: (v) => v == null || v.isEmpty ? 'Введите номер кабинета' : null,
                ),
                const SizedBox(height: 16),

                // Название (опционально)
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название (опционально)',
                    hintText: 'Например: Фортепианный',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 28),

                // Кнопка создания
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createRoom,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Создать кабинет',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Быстрое добавление ученика из формы занятия
class _QuickAddStudentSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final void Function(Student student) onStudentCreated;

  const _QuickAddStudentSheet({
    required this.institutionId,
    required this.onStudentCreated,
  });

  @override
  ConsumerState<_QuickAddStudentSheet> createState() => _QuickAddStudentSheetState();
}

class _QuickAddStudentSheetState extends ConsumerState<_QuickAddStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(studentControllerProvider.notifier);
      final student = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
      );

      if (student != null && mounted) {
        widget.onStudentCreated(student);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ученик "${student.name}" добавлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новый ученик',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Быстрое добавление',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ФИО
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'ФИО *',
                    hintText: 'Иванов Иван Иванович',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Введите имя ученика' : null,
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // Телефон
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 (777) 123-45-67',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 28),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createStudent,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Создать ученика',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Быстрое добавление предмета
class _QuickAddSubjectSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final void Function(Subject subject) onSubjectCreated;

  const _QuickAddSubjectSheet({
    required this.institutionId,
    required this.onSubjectCreated,
  });

  @override
  ConsumerState<_QuickAddSubjectSheet> createState() => _QuickAddSubjectSheetState();
}

class _QuickAddSubjectSheetState extends ConsumerState<_QuickAddSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createSubject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(subjectControllerProvider.notifier);
      final subject = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        color: getRandomPresetColor(), // Случайный цвет
      );

      if (subject != null && mounted) {
        widget.onSubjectCreated(subject);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Предмет "${subject.name}" добавлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новый предмет',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Добавьте предмет для занятий',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Название
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название предмета',
                    hintText: 'Например: Фортепиано',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название предмета';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createSubject,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Создать предмет',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Быстрое добавление типа занятия
class _QuickAddLessonTypeSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final void Function(LessonType lessonType) onLessonTypeCreated;

  const _QuickAddLessonTypeSheet({
    required this.institutionId,
    required this.onLessonTypeCreated,
  });

  @override
  ConsumerState<_QuickAddLessonTypeSheet> createState() => _QuickAddLessonTypeSheetState();
}

class _QuickAddLessonTypeSheetState extends ConsumerState<_QuickAddLessonTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _customDurationController = TextEditingController();
  int _durationMinutes = 60;
  bool _isCustomDuration = false;
  bool _isGroup = false;
  bool _isLoading = false;

  static const _popularDurations = [30, 45, 60, 90, 120];

  int get _effectiveDuration {
    if (_isCustomDuration) {
      return int.tryParse(_customDurationController.text) ?? 60;
    }
    return _durationMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _createLessonType() async {
    if (!_formKey.currentState!.validate()) return;

    // Валидация кастомной длительности
    if (_isCustomDuration) {
      final customValue = int.tryParse(_customDurationController.text);
      if (customValue == null || customValue < 5 || customValue > 480) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Длительность должна быть от 5 до 480 минут'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(lessonTypeControllerProvider.notifier);
      final lessonType = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.trim(),
        defaultDurationMinutes: _effectiveDuration,
        defaultPrice: _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
        isGroup: _isGroup,
      );

      if (lessonType != null && mounted) {
        widget.onLessonTypeCreated(lessonType);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Тип занятия "${lessonType.name}" добавлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Заголовок
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.category,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новый тип занятия',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Настройте параметры занятия',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Название
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например: Индивидуальное занятие',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Длительность
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Длительность',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Популярные длительности (chips)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._popularDurations.map((duration) {
                      final isSelected = !_isCustomDuration && _durationMinutes == duration;
                      return ChoiceChip(
                        label: Text('$duration мин'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _durationMinutes = duration;
                            _isCustomDuration = false;
                            _customDurationController.clear();
                          });
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                        side: isSelected
                            ? const BorderSide(color: AppColors.primary, width: 1.5)
                            : null,
                        showCheckmark: false,
                      );
                    }),
                    // Chip "Другое"
                    ChoiceChip(
                      label: const Text('Другое'),
                      selected: _isCustomDuration,
                      onSelected: (_) {
                        setState(() => _isCustomDuration = true);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _isCustomDuration ? AppColors.primary : null,
                        fontWeight: _isCustomDuration ? FontWeight.bold : null,
                      ),
                      side: _isCustomDuration
                          ? const BorderSide(color: AppColors.primary, width: 1.5)
                          : null,
                      showCheckmark: false,
                    ),
                  ],
                ),

                // Поле ввода кастомной длительности
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _isCustomDuration
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            controller: _customDurationController,
                            decoration: InputDecoration(
                              labelText: 'Своя длительность',
                              hintText: 'Введите минуты',
                              suffixText: 'мин',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                            ),
                            keyboardType: TextInputType.number,
                            autofocus: true,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Цена
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Цена (необязательно)',
                    hintText: 'Например: 5000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: '₸',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Групповое занятие
                SwitchListTile(
                  title: const Text('Групповое занятие'),
                  subtitle: const Text('Для нескольких учеников'),
                  value: _isGroup,
                  onChanged: (value) {
                    setState(() => _isGroup = value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 28),

                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createLessonType,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Создать тип',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Фильтры расписания
class _FilterSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final ScheduleFilters currentFilters;
  final ValueChanged<ScheduleFilters> onApply;

  const _FilterSheet({
    required this.institutionId,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late Set<String> _selectedTeachers;
  late Set<String> _selectedStudents;
  late Set<String> _selectedLessonTypes;
  late Set<String> _selectedSubjects;
  bool _studentsExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedTeachers = Set.from(widget.currentFilters.teacherIds);
    _selectedStudents = Set.from(widget.currentFilters.studentIds);
    _selectedLessonTypes = Set.from(widget.currentFilters.lessonTypeIds);
    _selectedSubjects = Set.from(widget.currentFilters.subjectIds);
    // Раскрыть если есть выбранные ученики
    _studentsExpanded = _selectedStudents.isNotEmpty;
  }

  bool get _hasFilters =>
      _selectedTeachers.isNotEmpty ||
      _selectedStudents.isNotEmpty ||
      _selectedLessonTypes.isNotEmpty ||
      _selectedSubjects.isNotEmpty;

  void _clearAll() {
    setState(() {
      _selectedTeachers = {};
      _selectedStudents = {};
      _selectedLessonTypes = {};
      _selectedSubjects = {};
    });
  }

  void _apply() {
    widget.onApply(ScheduleFilters(
      teacherIds: _selectedTeachers,
      studentIds: _selectedStudents,
      lessonTypeIds: _selectedLessonTypes,
      subjectIds: _selectedSubjects,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Фильтры',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      if (_hasFilters)
                        TextButton(
                          onPressed: _clearAll,
                          child: const Text('Сбросить'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Содержимое
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Преподаватели
                  _buildSection(
                    title: 'Преподаватели',
                    icon: Icons.person,
                    child: membersAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView.inline(e),
                      data: (members) => _buildCheckboxList<InstitutionMember>(
                        items: members.where((m) => !m.isArchived).toList(),
                        selectedIds: _selectedTeachers,
                        getId: (m) => m.userId,
                        getLabel: (m) => m.profile?.fullName ?? 'Без имени',
                        onChanged: (ids) => setState(() => _selectedTeachers = ids),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ученики (раскрывающийся список)
                  _buildStudentsSection(studentsAsync),
                  const SizedBox(height: 16),

                  // Типы занятий
                  _buildSection(
                    title: 'Типы занятий',
                    icon: Icons.category,
                    child: lessonTypesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView.inline(e),
                      data: (types) => _buildCheckboxList<LessonType>(
                        items: types,
                        selectedIds: _selectedLessonTypes,
                        getId: (t) => t.id,
                        getLabel: (t) => t.name,
                        onChanged: (ids) => setState(() => _selectedLessonTypes = ids),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Направления
                  _buildSection(
                    title: 'Направления',
                    icon: Icons.music_note,
                    child: subjectsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView.inline(e),
                      data: (subjects) => _buildCheckboxList<Subject>(
                        items: subjects,
                        selectedIds: _selectedSubjects,
                        getId: (s) => s.id,
                        getLabel: (s) => s.name,
                        onChanged: (ids) => setState(() => _selectedSubjects = ids),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80), // Отступ для кнопки
                ],
              ),
            ),
            // Кнопка применить
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_hasFilters
                    ? 'Применить фильтры'
                    : 'Показать все'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection(AsyncValue<List<Student>> studentsAsync) {
    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView.inline(e),
      data: (students) {
        // Фильтруем только активных и сортируем по алфавиту
        final activeStudents = students
            .where((s) => s.archivedAt == null)
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (activeStudents.isEmpty) {
          return _buildSection(
            title: 'Ученики',
            icon: Icons.school,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Нет учеников', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с кнопкой раскрытия
            InkWell(
              onTap: () => setState(() => _studentsExpanded = !_studentsExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.school, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Ученики',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedStudents.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedStudents.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      _studentsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // Выбранные ученики (показываем всегда если есть)
            if (_selectedStudents.isNotEmpty && !_studentsExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedStudents.map((id) {
                    final student = activeStudents.where((s) => s.id == id).firstOrNull;
                    return Chip(
                      label: Text(student?.name ?? 'Удалён'),
                      onDeleted: () {
                        setState(() {
                          _selectedStudents = Set.from(_selectedStudents)..remove(id);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            // Раскрывающийся список
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _studentsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: activeStudents.length,
                  itemBuilder: (context, index) {
                    final student = activeStudents[index];
                    final isSelected = _selectedStudents.contains(student.id);

                    return CheckboxListTile(
                      dense: true,
                      title: Text(student.name),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          final newIds = Set<String>.from(_selectedStudents);
                          if (value == true) {
                            newIds.add(student.id);
                          } else {
                            newIds.remove(student.id);
                          }
                          _selectedStudents = newIds;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCheckboxList<T>({
    required List<T> items,
    required Set<String> selectedIds,
    required String Function(T) getId,
    required String Function(T) getLabel,
    required ValueChanged<Set<String>> onChanged,
  }) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Нет данных', style: TextStyle(color: Colors.grey)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        final id = getId(item);
        final isSelected = selectedIds.contains(id);

        return FilterChip(
          label: Text(getLabel(item)),
          selected: isSelected,
          onSelected: (selected) {
            final newIds = Set<String>.from(selectedIds);
            if (selected) {
              newIds.add(id);
            } else {
              newIds.remove(id);
            }
            onChanged(newIds);
          },
        );
      }).toList(),
    );
  }
}

/// Диалог мульти-выбора дат
class _MultiDatePickerDialog extends StatefulWidget {
  final Set<DateTime> selectedDates;
  final DateTime firstDate;
  final DateTime lastDate;

  const _MultiDatePickerDialog({
    required this.selectedDates,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_MultiDatePickerDialog> createState() => _MultiDatePickerDialogState();
}

class _MultiDatePickerDialogState extends State<_MultiDatePickerDialog> {
  late Set<DateTime> _selectedDates;
  late DateTime _currentMonth;

  static const _weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDates = Set.from(widget.selectedDates);
    _currentMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
  }

  /// Нормализует дату (убирает время)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Проверяет, выбрана ли дата
  bool _isSelected(DateTime date) {
    final normalized = _normalizeDate(date);
    return _selectedDates.any((d) =>
        d.year == normalized.year &&
        d.month == normalized.month &&
        d.day == normalized.day);
  }

  /// Переключает выбор даты
  void _toggleDate(DateTime date) {
    final normalized = _normalizeDate(date);
    setState(() {
      if (_isSelected(normalized)) {
        _selectedDates.removeWhere((d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day);
      } else {
        _selectedDates.add(normalized);
      }
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Выберите даты',
                    style: theme.textTheme.titleLarge,
                  ),
                  if (_selectedDates.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedDates.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Навигация по месяцам
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  Text(
                    '${_months[_currentMonth.month - 1]} ${_currentMonth.year}',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),
            // Заголовки дней недели
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekDays.map((day) => SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      day,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Сетка дней
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildMonthGrid(theme),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedDates.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedDates),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(ThemeData theme) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    // День недели первого дня (0 = Пн, 6 = Вс)
    int startWeekday = firstDayOfMonth.weekday - 1;

    final days = <Widget>[];

    // Пустые ячейки до первого дня
    for (int i = 0; i < startWeekday; i++) {
      days.add(const SizedBox(width: 40, height: 40));
    }

    // Дни месяца
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelected = _isSelected(date);
      final isEnabled = !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);

      days.add(
        GestureDetector(
          onTap: isEnabled ? () => _toggleDate(date) : null,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : isEnabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: days,
    );
  }
}

/// Форма быстрого добавления занятия (из FAB)
/// Позволяет выбрать кабинет, дату и время
class _QuickAddLessonSheet extends ConsumerStatefulWidget {
  final List<Room> rooms;
  final DateTime initialDate;
  final String institutionId;
  final void Function(DateTime createdDate) onCreated;
  /// Предзаполненный кабинет (при нажатии на ячейку)
  final Room? preselectedRoom;
  /// Предзаполненный час начала (при нажатии на ячейку)
  final int? preselectedStartHour;
  /// Предзаполненные минуты начала (при нажатии на ячейку)
  final int? preselectedStartMinute;

  const _QuickAddLessonSheet({
    required this.rooms,
    required this.initialDate,
    required this.institutionId,
    required this.onCreated,
    this.preselectedRoom,
    this.preselectedStartHour,
    this.preselectedStartMinute,
  });

  @override
  ConsumerState<_QuickAddLessonSheet> createState() => _QuickAddLessonSheetState();
}

class _QuickAddLessonSheetState extends ConsumerState<_QuickAddLessonSheet> {
  // Режим формы
  _AddFormMode _mode = _AddFormMode.lesson;

  late DateTime _selectedDate;
  late Room? _selectedRoom;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  Student? _selectedStudent;
  Subject? _selectedSubject;
  LessonType? _selectedLessonType;
  InstitutionMember? _selectedTeacher;

  // Для режима бронирования
  Set<String> _selectedRoomIds = {};
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    // Если передан предзаполненный кабинет — используем его
    if (widget.preselectedRoom != null) {
      _selectedRoom = widget.preselectedRoom;
    } else {
      _selectedRoom = widget.rooms.isNotEmpty ? widget.rooms.first : null;
    }

    // По умолчанию выбираем первый кабинет для бронирования
    if (_selectedRoom != null) {
      _selectedRoomIds = {_selectedRoom!.id};
    } else if (widget.rooms.isNotEmpty) {
      _selectedRoomIds = {widget.rooms.first.id};
    }

    // Если передано предзаполненное время — используем его
    if (widget.preselectedStartHour != null) {
      final minute = widget.preselectedStartMinute ?? 0;
      _startTime = TimeOfDay(hour: widget.preselectedStartHour!, minute: minute);
      _endTime = TimeOfDay(hour: widget.preselectedStartHour! + 1, minute: minute);
    } else {
      final now = TimeOfDay.now();
      // Округляем до ближайшего часа
      _startTime = TimeOfDay(hour: now.hour, minute: 0);
      _endTime = TimeOfDay(hour: now.hour + 1, minute: 0);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final controllerState = ref.watch(lessonControllerProvider);
    final bookingControllerState = ref.watch(bookingControllerProvider);

    final isLoading = _mode == _AddFormMode.lesson
        ? controllerState.isLoading
        : bookingControllerState.isLoading;

    ref.listen(lessonControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    ref.listen(bookingControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorView.getUserFriendlyMessage(next.error!)),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _mode == _AddFormMode.lesson ? 'Новое занятие' : 'Бронирование',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Переключатель режима: Занятие / Бронь
            SegmentedButton<_AddFormMode>(
              segments: const [
                ButtonSegment<_AddFormMode>(
                  value: _AddFormMode.lesson,
                  label: Text('Занятие'),
                  icon: Icon(Icons.school, size: 18),
                ),
                ButtonSegment<_AddFormMode>(
                  value: _AddFormMode.booking,
                  label: Text('Бронь'),
                  icon: Icon(Icons.lock_clock, size: 18),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<_AddFormMode> newSelection) {
                setState(() => _mode = newSelection.first);
              },
            ),
            const SizedBox(height: 16),

            // ========== РЕЖИМ ЗАНЯТИЯ ==========
            if (_mode == _AddFormMode.lesson) ...[
              // Кабинет
              Builder(
                builder: (context) {
                  final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
                  final rooms = roomsAsync.valueOrNull ?? widget.rooms;

                  // Проверяем, что выбранный кабинет есть в списке
                  if (_selectedRoom != null && !rooms.any((r) => r.id == _selectedRoom!.id)) {
                    _selectedRoom = rooms.isNotEmpty ? rooms.first : null;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: rooms.isEmpty
                            ? InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Кабинет *',
                                  prefixIcon: Icon(Icons.door_front_door),
                                ),
                                child: Text(
                                  'Нет кабинетов',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              )
                            : DropdownButtonFormField<Room>(
                                decoration: const InputDecoration(
                                  labelText: 'Кабинет *',
                                  prefixIcon: Icon(Icons.door_front_door),
                                ),
                                value: _selectedRoom,
                                items: rooms.map((r) => DropdownMenuItem<Room>(
                                  value: r,
                                  child: Text(r.number != null ? 'Кабинет ${r.number}' : r.name),
                                )).toList(),
                                onChanged: (room) {
                                  setState(() => _selectedRoom = room);
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton.filled(
                          onPressed: () => _showAddRoomDialog(),
                          icon: const Icon(Icons.add, size: 20),
                          tooltip: 'Добавить кабинет',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // ========== РЕЖИМ БРОНИРОВАНИЯ ==========
            if (_mode == _AddFormMode.booking) ...[
              // Выбор кабинетов (мультиселект)
              Text(
                'Кабинеты',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.rooms.map((room) {
                  final isSelected = _selectedRoomIds.contains(room.id);
                  final roomLabel = room.number != null
                      ? 'Каб. ${room.number}'
                      : room.name;
                  return FilterChip(
                    label: Text(roomLabel),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoomIds.add(room.id);
                        } else {
                          _selectedRoomIds.remove(room.id);
                        }
                      });
                    },
                    selectedColor: AppColors.warning.withValues(alpha: 0.3),
                    checkmarkColor: AppColors.warning,
                  );
                }).toList(),
              ),
              if (_selectedRoomIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Выберите хотя бы один кабинет',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Дата
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  // Предзагрузка не нужна — это локальное состояние формы
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(AppDateUtils.formatDayMonth(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Время
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showIosTimePicker(
                        context: context,
                        initialTime: _startTime,
                        minuteInterval: 5,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                          final endMinutes = time.hour * 60 + time.minute + 60;
                          _endTime = TimeOfDay(
                            hour: endMinutes ~/ 60,
                            minute: endMinutes % 60,
                          );
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Начало',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_formatTime(_startTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showIosTimePicker(
                        context: context,
                        initialTime: _endTime,
                        minuteInterval: 5,
                      );
                      if (time != null) {
                        setState(() => _endTime = time);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Конец',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_formatTime(_endTime)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ========== Продолжение РЕЖИМА БРОНИРОВАНИЯ ==========
            if (_mode == _AddFormMode.booking) ...[
              // Описание
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание (опционально)',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Мероприятие, встреча и т.д.',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Кнопка создания брони
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading || _selectedRoomIds.isEmpty
                    ? null
                    : _createBooking,
                icon: const Icon(Icons.lock),
                label: const Text('Забронировать'),
              ),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),

              const SizedBox(height: 8),
            ],

            // ========== Продолжение РЕЖИМА ЗАНЯТИЯ ==========
            if (_mode == _AddFormMode.lesson) ...[
              // Ученик
              studentsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => ErrorView.inline(e),
                data: (students) {
                  // Находим выбранного студента по ID в текущем списке
                  // (объекты могут быть разными после перезагрузки)
                  final currentStudent = _selectedStudent != null
                      ? students.where((s) => s.id == _selectedStudent!.id).firstOrNull
                      : null;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: students.isEmpty
                            ? InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Ученик *',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                child: Text(
                                  'Нет учеников',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              )
                            : DropdownButtonFormField<Student?>(
                                decoration: const InputDecoration(
                                  labelText: 'Ученик *',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                value: currentStudent,
                                items: students.map((s) => DropdownMenuItem<Student?>(
                                  value: s,
                                  child: Text(s.name),
                                )).toList(),
                                onChanged: (student) {
                                  setState(() => _selectedStudent = student);
                                  // Автозаполнение типа занятия из привязок ученика
                                  if (student != null) {
                                    _autoFillLessonTypeFromStudent(student.id);
                                  }
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton.filled(
                          onPressed: () => _showAddStudentDialog(),
                          icon: const Icon(Icons.add, size: 20),
                          tooltip: 'Добавить ученика',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Преподаватель (только для владельца/админа)
              membersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (members) {
                final activeMembers = members.where((m) => !m.isArchived).toList();
                if (activeMembers.length <= 1) return const SizedBox.shrink();

                // Установить текущего пользователя по умолчанию
                final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
                _selectedTeacher ??= activeMembers.where((m) => m.userId == currentUserId).firstOrNull;

                // Проверяем права: только владелец или админ может выбирать преподавателя
                final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
                final institution = institutionAsync.valueOrNull;
                final isOwner = institution != null && institution.ownerId == currentUserId;
                final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
                final canSelectTeacher = isOwner || isAdmin;

                // Если нет прав на выбор — не показываем dropdown
                // Но если institution ещё загружается — показываем (чтобы не мигало)
                if (!canSelectTeacher && institution != null) {
                  return const SizedBox.shrink();
                }

                return DropdownButtonFormField<InstitutionMember?>(
                  decoration: const InputDecoration(
                    labelText: 'Преподаватель',
                    prefixIcon: Icon(Icons.school),
                  ),
                  value: _selectedTeacher,
                  items: activeMembers.map((m) => DropdownMenuItem<InstitutionMember?>(
                    value: m,
                    child: Text(m.profile?.fullName ?? 'Без имени'),
                  )).toList(),
                  onChanged: (member) async {
                    setState(() => _selectedTeacher = member);

                    // Автозаполнение предмета если у преподавателя один привязанный
                    if (member != null) {
                      _autoFillSubjectFromTeacher(member.userId);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Предмет
            subjectsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (subjects) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Subject?>(
                        decoration: const InputDecoration(
                          labelText: 'Предмет',
                          prefixIcon: Icon(Icons.music_note),
                        ),
                        value: _selectedSubject,
                        items: [
                          const DropdownMenuItem<Subject?>(
                            value: null,
                            child: Text('Не выбран'),
                          ),
                          ...subjects.map((s) => DropdownMenuItem<Subject?>(
                            value: s,
                            child: Text(s.name),
                          )),
                        ],
                        onChanged: (subject) {
                          setState(() => _selectedSubject = subject);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton.filled(
                        onPressed: _showAddSubjectDialog,
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Добавить предмет',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Тип занятия
            lessonTypesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (lessonTypes) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<LessonType?>(
                        decoration: const InputDecoration(
                          labelText: 'Тип занятия',
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: _selectedLessonType,
                        items: [
                          const DropdownMenuItem<LessonType?>(
                            value: null,
                            child: Text('Не выбран'),
                          ),
                          ...lessonTypes.map((lt) => DropdownMenuItem<LessonType?>(
                            value: lt,
                            child: Text('${lt.name} (${lt.defaultDurationMinutes} мин)'),
                          )),
                        ],
                        onChanged: (lessonType) {
                          setState(() {
                            _selectedLessonType = lessonType;
                            if (lessonType != null) {
                              final startMinutes = _startTime.hour * 60 + _startTime.minute;
                              final endMinutes = startMinutes + lessonType.defaultDurationMinutes;
                              _endTime = TimeOfDay(
                                hour: endMinutes ~/ 60,
                                minute: endMinutes % 60,
                              );
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton.filled(
                        onPressed: _showAddLessonTypeDialog,
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Добавить тип занятия',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
              const SizedBox(height: 24),

              // Кнопка создания
              ElevatedButton.icon(
                onPressed: controllerState.isLoading || _selectedStudent == null || _selectedRoom == null
                    ? null
                    : _createLesson,
                icon: const Icon(Icons.add),
                label: const Text('Создать занятие'),
              ),

              if (controllerState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),

              const SizedBox(height: 8),
            ], // конец if (_mode == _AddFormMode.lesson)
          ],
        ),
      ),
    );
  }

  /// Создание бронирования
  Future<void> _createBooking() async {
    if (_selectedRoomIds.isEmpty) return;

    // Проверка минимальной длительности (15 минут)
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    if (durationMinutes < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Минимальная длительность брони — 15 минут'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final controller = ref.read(bookingControllerProvider.notifier);

    final booking = await controller.create(
      institutionId: widget.institutionId,
      roomIds: _selectedRoomIds.toList(),
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
    );

    if (booking != null && mounted) {
      widget.onCreated(_selectedDate);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Кабинеты забронированы'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _createLesson() async {
    if (_selectedStudent == null || _selectedRoom == null) return;

    // Проверка минимальной длительности (15 минут)
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    if (durationMinutes < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Минимальная длительность занятия — 15 минут'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    // Используем выбранного преподавателя или текущего пользователя
    final teacherId = _selectedTeacher?.userId ?? currentUserId;

    final controller = ref.read(lessonControllerProvider.notifier);

    final lesson = await controller.create(
      institutionId: widget.institutionId,
      roomId: _selectedRoom!.id,
      teacherId: teacherId,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      studentId: _selectedStudent!.id,
      subjectId: _selectedSubject?.id,
      lessonTypeId: _selectedLessonType?.id,
    );

    if (lesson != null && mounted) {
      // Автоматически создаём привязки ученик-преподаватель и ученик-предмет
      _createBindings(teacherId);

      widget.onCreated(_selectedDate);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Занятие создано'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Создаёт привязки ученик-преподаватель, ученик-предмет и ученик-тип занятия (upsert - не падает если уже есть)
  void _createBindings(String teacherId) {
    if (_selectedStudent == null) return;

    debugPrint('_createBindings:');
    debugPrint('  studentId: ${_selectedStudent!.id}');
    debugPrint('  lessonTypeId: ${_selectedLessonType?.id}');

    // Запускаем в фоне, не блокируем UI
    ref.read(studentBindingsControllerProvider.notifier).createBindingsFromLesson(
      studentId: _selectedStudent!.id,
      teacherId: teacherId,
      subjectId: _selectedSubject?.id,
      lessonTypeId: _selectedLessonType?.id,
      institutionId: widget.institutionId,
    );
  }

  /// Автозаполнение предмета из привязок преподавателя (если у него один предмет)
  Future<void> _autoFillSubjectFromTeacher(String userId) async {
    try {
      final teacherSubjects = await ref.read(
        teacherSubjectsProvider(TeacherSubjectsParams(
          userId: userId,
          institutionId: widget.institutionId,
        )).future,
      );

      // Если у преподавателя ровно один привязанный предмет — автозаполняем
      if (teacherSubjects.length == 1 && mounted) {
        final teacherSubject = teacherSubjects.first;
        if (teacherSubject.subjectId.isNotEmpty) {
          // Ищем предмет в общем списке по ID (важно для совпадения ссылок в dropdown)
          final allSubjects = await ref.read(subjectsProvider(widget.institutionId).future);
          final matchingSubject = allSubjects.where((s) => s.id == teacherSubject.subjectId).firstOrNull;
          if (matchingSubject != null && mounted) {
            setState(() => _selectedSubject = matchingSubject);
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки — это не критично
    }
  }

  /// Автозаполнение типа занятия из привязок ученика (если у него один тип)
  Future<void> _autoFillLessonTypeFromStudent(String studentId) async {
    try {
      final studentLessonTypes = await ref.read(
        studentLessonTypesProvider(studentId).future,
      );

      // Если у ученика ровно один привязанный тип занятия — автозаполняем
      if (studentLessonTypes.length == 1 && mounted) {
        final studentLessonType = studentLessonTypes.first;
        if (studentLessonType.lessonTypeId.isNotEmpty) {
          // Ищем тип в общем списке по ID (важно для совпадения ссылок в dropdown)
          final allLessonTypes = await ref.read(lessonTypesProvider(widget.institutionId).future);
          final matchingType = allLessonTypes.where((lt) => lt.id == studentLessonType.lessonTypeId).firstOrNull;
          if (matchingType != null && mounted) {
            setState(() {
              _selectedLessonType = matchingType;
              // Также обновляем время окончания на основе длительности типа
              final startMinutes = _startTime.hour * 60 + _startTime.minute;
              final endMinutes = startMinutes + matchingType.defaultDurationMinutes;
              _endTime = TimeOfDay(
                hour: endMinutes ~/ 60,
                minute: endMinutes % 60,
              );
            });
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки — это не критично
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showAddRoomDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _QuickAddRoomSheet(
        institutionId: widget.institutionId,
        onRoomCreated: (room) {
          ref.invalidate(roomsProvider(widget.institutionId));
          ref.read(roomsProvider(widget.institutionId).future).then((rooms) {
            final newRoom = rooms.where((r) => r.id == room.id).firstOrNull;
            if (mounted) {
              setState(() => _selectedRoom = newRoom);
            }
          });
        },
      ),
    );
  }

  void _showAddStudentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _QuickAddStudentSheet(
        institutionId: widget.institutionId,
        onStudentCreated: (student) {
          ref.invalidate(studentsProvider(widget.institutionId));
          ref.read(studentsProvider(widget.institutionId).future).then((students) {
            final newStudent = students.where((s) => s.id == student.id).firstOrNull;
            if (mounted) {
              setState(() => _selectedStudent = newStudent);
            }
          });
        },
      ),
    );
  }

  void _showAddSubjectDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _QuickAddSubjectSheet(
        institutionId: widget.institutionId,
        onSubjectCreated: (subject) {
          ref.invalidate(subjectsProvider(widget.institutionId));
          ref.read(subjectsProvider(widget.institutionId).future).then((subjects) {
            final newSubject = subjects.where((s) => s.id == subject.id).firstOrNull;
            if (mounted) {
              setState(() => _selectedSubject = newSubject);
            }
          });
        },
      ),
    );
  }

  void _showAddLessonTypeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _QuickAddLessonTypeSheet(
        institutionId: widget.institutionId,
        onLessonTypeCreated: (lessonType) {
          ref.invalidate(lessonTypesProvider(widget.institutionId));
          ref.read(lessonTypesProvider(widget.institutionId).future).then((lessonTypes) {
            final newLessonType = lessonTypes.where((lt) => lt.id == lessonType.id).firstOrNull;
            if (mounted) {
              setState(() {
                _selectedLessonType = newLessonType;
                // Обновляем время окончания по длительности нового типа
                if (newLessonType != null) {
                  final startMinutes = _startTime.hour * 60 + _startTime.minute;
                  final endMinutes = startMinutes + newLessonType.defaultDurationMinutes;
                  _endTime = TimeOfDay(
                    hour: endMinutes ~/ 60,
                    minute: endMinutes % 60,
                  );
                }
              });
            }
          });
        },
      ),
    );
  }
}

/// Детали бронирования
class _BookingDetailSheet extends ConsumerStatefulWidget {
  final Booking booking;
  final String institutionId;
  final VoidCallback onUpdated;

  const _BookingDetailSheet({
    required this.booking,
    required this.institutionId,
    required this.onUpdated,
  });

  @override
  ConsumerState<_BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends ConsumerState<_BookingDetailSheet> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final institutionAsync = ref.watch(currentInstitutionProvider(widget.institutionId));
    final isOwner = institutionAsync.valueOrNull?.ownerId == currentUserId;
    final isAdmin = ref.watch(isAdminProvider(widget.institutionId));
    final hasFullAccess = isOwner || isAdmin;
    final isCreator = booking.createdBy == currentUserId;
    final canDelete = hasFullAccess || isCreator;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSizes.paddingS),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingS),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSizes.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.description ?? 'Забронировано',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.roomNames,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Info
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: Column(
              children: [
                // Time
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                    const SizedBox(width: AppSizes.paddingM),
                    Text(
                      '${_formatTime(booking.startTime)} — ${_formatTime(booking.endTime)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Creator
                Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: AppSizes.paddingM),
                    Text(
                      booking.creator?.fullName ?? 'Неизвестный пользователь',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          if (canDelete) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _handleDelete,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(_isDeleting ? 'Удаление...' : 'Удалить бронь'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + AppSizes.paddingM),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить бронь?'),
        content: const Text('Бронирование будет удалено и кабинеты освободятся.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final controller = ref.read(bookingControllerProvider.notifier);
    final success = await controller.delete(
      widget.booking.id,
      widget.institutionId,
      widget.booking.date,
    );

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бронь удалена')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при удалении')),
        );
      }
    }
  }
}

/// Форма создания брони с мультиселектом кабинетов
class _AddBookingSheet extends ConsumerStatefulWidget {
  final List<Room> rooms;
  final DateTime initialDate;
  final String institutionId;
  final ValueChanged<DateTime> onCreated;

  const _AddBookingSheet({
    required this.rooms,
    required this.initialDate,
    required this.institutionId,
    required this.onCreated,
  });

  @override
  ConsumerState<_AddBookingSheet> createState() => _AddBookingSheetState();
}

class _AddBookingSheetState extends ConsumerState<_AddBookingSheet> {
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final Set<String> _selectedRoomIds = {};
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusL),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSizes.paddingS),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingS),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  const Text(
                    'Забронировать кабинеты',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSizes.paddingL),
                children: [
                  // Выбор кабинетов (чекбоксы)
                  const Text(
                    'Выберите кабинеты',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  ...widget.rooms.map((room) => CheckboxListTile(
                    title: Text(room.displayName),
                    value: _selectedRoomIds.contains(room.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedRoomIds.add(room.id);
                        } else {
                          _selectedRoomIds.remove(room.id);
                        }
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
                  if (_selectedRoomIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Выберите минимум один кабинет',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSizes.paddingL),

                  // Дата
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Дата'),
                    trailing: Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    onTap: _selectDate,
                  ),

                  const Divider(),

                  // Время начала
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text('Начало'),
                    trailing: Text(
                      _formatTime(_startTime),
                      style: const TextStyle(fontSize: 16),
                    ),
                    onTap: () => _selectTime(isStart: true),
                  ),

                  // Время окончания
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const SizedBox(width: 24),
                    title: const Text('Окончание'),
                    trailing: Text(
                      _formatTime(_endTime),
                      style: const TextStyle(fontSize: 16),
                    ),
                    onTap: () => _selectTime(isStart: false),
                  ),

                  const Divider(),

                  // Описание
                  const SizedBox(height: AppSizes.paddingS),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Описание (необязательно)',
                      hintText: 'Например: Репетиция, Мероприятие',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: AppSizes.paddingXL),

                  // Кнопка создания
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSave && !_isSaving ? _handleSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Забронировать'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave {
    if (_selectedRoomIds.isEmpty) return false;
    // end_time > start_time
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes > startMinutes;
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return '${weekdays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      // Предзагрузка не нужна — это локальное состояние формы
    }
  }

  Future<void> _selectTime({required bool isStart}) async {
    final picked = await showIosTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      minuteInterval: 5,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Автоматически сдвигаем endTime если start >= end
          final startMinutes = picked.hour * 60 + picked.minute;
          final endMinutes = _endTime.hour * 60 + _endTime.minute;
          if (startMinutes >= endMinutes) {
            _endTime = TimeOfDay(
              hour: (picked.hour + 1) % 24,
              minute: picked.minute,
            );
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      final booking = await controller.create(
        institutionId: widget.institutionId,
        roomIds: _selectedRoomIds.toList(),
        date: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        if (booking != null) {
          widget.onCreated(_selectedDate);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Кабинеты забронированы')),
          );
        } else {
          final error = ref.read(bookingControllerProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.error?.toString() ?? 'Ошибка бронирования'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
