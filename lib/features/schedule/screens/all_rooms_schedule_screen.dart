import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
import 'package:kabinet/features/subjects/providers/subject_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
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
import 'package:kabinet/features/bookings/repositories/booking_repository.dart';
import 'package:kabinet/features/groups/providers/group_provider.dart';
import 'package:kabinet/shared/models/student_group.dart';

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

/// Стиль дневного вида
enum DayViewStyle {
  compact,  // Компактный (как недельный)
  detailed, // Подробный (текущий)
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
  DayViewStyle _dayViewStyle = DayViewStyle.compact; // По умолчанию компактный
  int _scrollResetKey = 0; // Ключ для принудительного сброса скролла
  bool _roomSetupShown = false; // Промпт настройки кабинетов уже показан
  bool _showAllRoomsOverride = false; // Временный фильтр "показать все кабинеты"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Предзагружаем участников для цветов и соседние даты при первом входе
    _preloadData();
  }

  /// Предзагрузка данных для мгновенного отображения
  void _preloadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Предзагружаем участников (для цветов преподавателей)
      ref.read(membersStreamProvider(widget.institutionId).future).catchError((_) => <InstitutionMember>[]);
      // Предзагружаем соседние даты
      _preloadAdjacentDates();
      // Проверяем необходимость настройки кабинетов
      _checkRoomSetup();
    });
  }

  /// Проверка необходимости настройки кабинетов по умолчанию
  void _checkRoomSetup() {
    if (_roomSetupShown) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final needsSetup = ref.read(needsRoomSetupProvider(widget.institutionId));
      if (needsSetup) {
        _roomSetupShown = true;
        // Ждём загрузки кабинетов
        final rooms = await ref.read(roomsProvider(widget.institutionId).future).catchError((_) => <Room>[]);
        if (!mounted || rooms.isEmpty) return;

        _showRoomSetupSheet(rooms, isFirstTime: true);
      }
    });
  }

  /// Показать диалог настройки кабинетов
  void _showRoomSetupSheet(List<Room> rooms, {bool isFirstTime = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isFirstTime, // Нельзя закрыть тапом при первой настройке
      enableDrag: !isFirstTime,
      builder: (ctx) => _RoomSetupSheet(
        institutionId: widget.institutionId,
        rooms: rooms,
        isFirstTime: isFirstTime,
        onSaved: () {
          // Refresh после сохранения
          ref.invalidate(myMembershipProvider(widget.institutionId));
        },
      ),
    );
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
      // Инвалидируем дневной режим
      ref.invalidate(lessonsByInstitutionStreamProvider(
        InstitutionDateParams(widget.institutionId, _selectedDate),
      ));
      ref.invalidate(bookingsByInstitutionDateProvider(
        InstitutionDateParams(widget.institutionId, _selectedDate),
      ));

      // Инвалидируем недельный режим
      final weekStart = InstitutionWeekParams.getWeekStart(_selectedDate);
      final weekParams = InstitutionWeekParams(widget.institutionId, weekStart);
      ref.invalidate(lessonsByInstitutionWeekStreamProvider(weekParams));
      ref.invalidate(bookingsByInstitutionWeekStreamProvider(weekParams));
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

  /// Обработчик выбора даты
  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _savedScrollOffset = null;
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
    final allRoomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final lessonsAsync = ref.watch(
      lessonsByInstitutionStreamProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
    );
    final bookingsAsync = ref.watch(
      bookingsByInstitutionDateProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
    );

    // Получаем еженедельные бронирования (постоянные слоты) для выбранной даты
    final scheduleSlots = ref.watch(
      weeklyBookingsForDateProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
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

    // Получаем настройки кабинетов по умолчанию
    final membership = ref.watch(myMembershipProvider(widget.institutionId)).valueOrNull;
    final defaultRoomIds = membership?.defaultRoomIds;

    // Фильтруем кабинеты по настройкам
    // _showAllRoomsOverride = временно показать все (на сессию)
    // null = не настроено (показать все), [] = пропущено (показать все), [...] = выбранные
    final roomsAsync = allRoomsAsync.whenData((rooms) {
      if (_showAllRoomsOverride || defaultRoomIds == null || defaultRoomIds.isEmpty) {
        return rooms;
      }
      return rooms.where((r) => defaultRoomIds.contains(r.id)).toList();
    });

    // Получаем рабочее время из заведения
    final workStartHour = institutionAsync.valueOrNull?.workStartHour ?? 8;
    final workEndHour = institutionAsync.valueOrNull?.workEndHour ?? 22;

    // Получаем цвета преподавателей (используем StreamProvider + valueOrNull для кеширования)
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final members = membersAsync.valueOrNull ?? [];
    final teacherColors = {
      for (final m in members) m.userId: m.color,
    };

    // Получаем название выбранного кабинета для заголовка (из всех кабинетов)
    String title = 'Расписание';
    if (_selectedRoomId != null) {
      allRoomsAsync.whenData((rooms) {
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
          // Вкладки День/Неделя и стиль дневного вида
          _ViewModeTabs(
            viewMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
            dayViewStyle: _dayViewStyle,
            onDayViewStyleChanged: (style) => setState(() => _dayViewStyle = style),
          ),
          // Селектор даты (только для дневного режима)
          if (_viewMode == ScheduleViewMode.day)
            _WeekDaySelector(
              selectedDate: _selectedDate,
              scrollToTodayKey: _scrollResetKey,
              onDateSelected: _onDateSelected,
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
                ? _buildDayView(roomsAsync, allRoomsAsync, lessonsAsync, bookingsAsync, scheduleSlots, canManageRooms, workStartHour, workEndHour, teacherColors)
                : _buildWeekView(roomsAsync, allRoomsAsync, canManageRooms, workStartHour, workEndHour, teacherColors),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(
        isOwner: isOwner,
        permissions: permissions,
        rooms: allRoomsAsync.valueOrNull ?? [], // Все кабинеты для выбора
      ),
    );
  }

  Widget _buildDayView(
    AsyncValue<List<Room>> roomsAsync,
    AsyncValue<List<Room>> allRoomsAsync,
    AsyncValue<List<Lesson>> lessonsAsync,
    AsyncValue<List<Booking>> bookingsAsync,
    List<Booking> scheduleSlots,
    bool canManageRooms,
    int workStartHour,
    int workEndHour,
    Map<String, String?> teacherColors,
  ) {
    // Все кабинеты для диалогов создания занятий
    final allRooms = allRoomsAsync.valueOrNull ?? [];
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
    // Фильтруем: еженедельные брони с учеником показываются как scheduleSlots, не как обычные брони
    final allBookings = bookingsAsync.valueOrNull ?? [];
    final bookings = allBookings.where((b) {
      // Еженедельные брони с учеником — это слоты расписания, не показываем их как обычные брони
      if (b.isRecurring && b.studentId != null) return false;
      return true;
    }).toList();

    final filteredLessons = _filters.isEmpty
        ? lessonsList
        : lessonsList.where((l) => _filters.matchesLesson(l)).toList();

    // Фильтруем слоты — скрываем те, для которых уже создано занятие
    // (чтобы не было визуального наложения)
    final filteredSlots = scheduleSlots.where((slot) {
      final hasLesson = lessonsList.any((lesson) {
        if (lesson.studentId != slot.studentId) return false;
        final effectiveRoomId = slot.getEffectiveRoomId(_selectedDate);
        if (lesson.roomId != effectiveRoomId) return false;
        return slot.hasTimeOverlap(lesson.startTime, lesson.endTime);
      });
      return !hasLesson;
    }).toList();

    // Вычисляем эффективные часы с учётом занятий, броней и слотов вне рабочего времени
    final effectiveHours = _calculateEffectiveHours(
      lessons: lessonsList,
      bookings: bookings,
      scheduleSlots: filteredSlots,
      workStartHour: workStartHour,
      workEndHour: workEndHour,
    );

    // Выбираем виджет в зависимости от стиля дневного вида
    if (_dayViewStyle == DayViewStyle.compact) {
      return _CompactDayGrid(
        key: ValueKey('compact_grid_$_scrollResetKey'),
        rooms: _selectedRoomId != null
            ? rooms.where((r) => r.id == _selectedRoomId).toList()
            : rooms,
        allRooms: allRooms,
        lessons: filteredLessons,
        bookings: bookings,
        scheduleSlots: filteredSlots,
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
        onScheduleSlotTap: _showScheduleSlotDetail,
        onRoomTap: (roomId, currentOffset) {
          setState(() {
            _savedScrollOffset = currentOffset;
            if (_selectedRoomId == roomId) {
              _selectedRoomId = null;
            } else {
              _selectedRoomId = roomId;
            }
          });
        },
        onAddLesson: (room, hour, minute) => _showAddLessonSheet(room, hour, minute, allRooms: allRooms),
        onAddRoom: _showAddRoomBottomSheet,
      );
    }

    return _AllRoomsTimeGrid(
      key: ValueKey('grid_$_scrollResetKey'), // Для принудительного сброса скролла
      rooms: _selectedRoomId != null
          ? rooms.where((r) => r.id == _selectedRoomId).toList()
          : rooms,
      allRooms: allRooms,
      lessons: filteredLessons,
      bookings: bookings,
      scheduleSlots: filteredSlots,
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
      onScheduleSlotTap: _showScheduleSlotDetail,
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
      onAddLesson: (room, hour, minute) => _showAddLessonSheet(room, hour, minute, allRooms: allRooms),
      onAddRoom: _showAddRoomBottomSheet,
    );
  }

  /// Вычисляет эффективные часы отображения сетки
  /// Расширяет диапазон, если есть занятия/брони/слоты вне рабочего времени
  (int, int) _calculateEffectiveHours({
    required List<Lesson> lessons,
    List<Booking> bookings = const [],
    List<Booking> scheduleSlots = const [],
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

    // Учитываем постоянные слоты
    for (final slot in scheduleSlots) {
      final slotStartHour = slot.startTime.hour;
      final slotEndHour = slot.endTime.minute > 0
          ? slot.endTime.hour + 1
          : slot.endTime.hour;

      if (slotStartHour < effectiveStart) {
        effectiveStart = slotStartHour;
      }
      if (slotEndHour > effectiveEnd) {
        effectiveEnd = slotEndHour;
      }
    }

    // Ограничиваем разумными пределами (0-24)
    effectiveStart = effectiveStart.clamp(0, 23);
    effectiveEnd = effectiveEnd.clamp(1, 24);

    return (effectiveStart, effectiveEnd);
  }

  Widget _buildWeekView(
    AsyncValue<List<Room>> roomsAsync,
    AsyncValue<List<Room>> allRoomsAsync,
    bool canManageRooms,
    int workStartHour,
    int workEndHour,
    Map<String, String?> teacherColors,
  ) {
    final weekStart = InstitutionWeekParams.getWeekStart(_selectedDate);
    final weekParams = InstitutionWeekParams(widget.institutionId, weekStart);
    // Используем StreamProvider для realtime обновлений недельного расписания
    final weekLessonsAsync = ref.watch(lessonsByInstitutionWeekStreamProvider(weekParams));

    // Загружаем брони за неделю (с realtime)
    final weekBookingsAsync = ref.watch(bookingsByInstitutionWeekStreamProvider(weekParams));

    // Загружаем все постоянные слоты заведения (для фильтрации по дням)
    final allScheduleSlotsAsync = ref.watch(weeklyBookingsByInstitutionProvider(widget.institutionId));

    // Все кабинеты для диалогов создания занятий
    final allRooms = allRoomsAsync.valueOrNull ?? [];
    // Используем valueOrNull для предотвращения ошибки при смене недели
    final rooms = roomsAsync.valueOrNull;
    final lessonsByDay = weekLessonsAsync.valueOrNull;
    final weekBookings = weekBookingsAsync.valueOrNull;
    final allScheduleSlots = allScheduleSlotsAsync.valueOrNull;

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

    // Формируем map броней по дням (используем пустой map если ещё загружается)
    // Фильтруем: еженедельные брони с учеником показываются как слоты, не как обычные брони
    final rawBookingsMap = weekBookings ?? <DateTime, List<Booking>>{};
    final bookingsMap = <DateTime, List<Booking>>{};
    for (final entry in rawBookingsMap.entries) {
      bookingsMap[entry.key] = entry.value.where((b) {
        if (b.isRecurring && b.studentId != null) return false;
        return true;
      }).toList();
    }

    // Формируем map постоянных слотов по дням
    // Скрываем слоты, для которых уже создано занятие (чтобы не было наложения)
    final slotsByDay = <DateTime, List<Booking>>{};
    if (allScheduleSlots != null) {
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final dayLessons = lessonsMap[normalizedDate] ?? [];

        slotsByDay[normalizedDate] = allScheduleSlots
            .where((slot) {
              if (!slot.isValidForDate(date)) return false;
              // Скрываем слот если есть занятие того же ученика с пересечением времени
              final hasLesson = dayLessons.any((lesson) {
                if (lesson.studentId != slot.studentId) return false;
                final effectiveRoomId = slot.getEffectiveRoomId(date);
                if (lesson.roomId != effectiveRoomId) return false;
                return slot.hasTimeOverlap(lesson.startTime, lesson.endTime);
              });
              return !hasLesson;
            })
            .toList()
          ..sort((a, b) {
            final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
            final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
            return aMinutes.compareTo(bMinutes);
          });
      }
    }

    // Вычисляем эффективные часы для всей недели (с учётом броней и слотов)
    final allLessons = lessonsMap.values.expand((list) => list).toList();
    final allBookings = bookingsMap.values.expand((list) => list).toList();
    final allSlots = slotsByDay.values.expand((list) => list).toList();
    final effectiveHours = _calculateEffectiveHours(
      lessons: allLessons,
      bookings: allBookings,
      scheduleSlots: allSlots,
      workStartHour: workStartHour,
      workEndHour: workEndHour,
    );

    return _WeekTimeGrid(
      key: ValueKey('week_grid_$_scrollResetKey'), // Для принудительного сброса скролла
      rooms: _selectedRoomId != null
          ? rooms.where((r) => r.id == _selectedRoomId).toList()
          : rooms,
      allRooms: allRooms,
      lessonsByDay: filteredLessonsByDay,
      bookingsByDay: bookingsMap,
      slotsByDay: slotsByDay,
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

  void _showScheduleSlotDetail(Booking slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ScheduleSlotDetailSheet(
        slot: slot,
        selectedDate: _selectedDate,
        institutionId: widget.institutionId,
        onUpdated: () {
          ref.invalidate(weeklyBookingsByInstitutionProvider(widget.institutionId));
        },
        onCreateLesson: () {
          Navigator.pop(context);
          // Открываем форму создания занятия с данными из слота
          _showAddLessonFromSlot(slot);
        },
      ),
    );
  }

  /// Открывает форму создания занятия с данными из постоянного слота
  void _showAddLessonFromSlot(Booking slot) {
    final roomsAsync = ref.read(roomsProvider(widget.institutionId));
    final rooms = roomsAsync.valueOrNull ?? [];
    if (rooms.isEmpty) return;

    // Находим кабинет слота
    final slotRoom = rooms.firstWhere(
      (r) => r.id == slot.getEffectiveRoomId(_selectedDate),
      orElse: () => rooms.first,
    );

    // Инвалидируем кеш справочников
    ref.invalidate(subjectsProvider(widget.institutionId));
    ref.invalidate(lessonTypesProvider(widget.institutionId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _QuickAddLessonSheet(
        rooms: rooms,
        initialDate: _selectedDate,
        institutionId: widget.institutionId,
        preselectedRoom: slotRoom,
        preselectedStartHour: slot.startTime.hour,
        preselectedStartMinute: slot.startTime.minute,
        preselectedEndHour: slot.endTime.hour,
        preselectedEndMinute: slot.endTime.minute,
        preselectedStudent: slot.student,
        preselectedSubject: slot.subject,
        preselectedLessonType: slot.lessonType,
        onCreated: (DateTime createdDate) {
          ref.invalidate(lessonsByInstitutionProvider(
            InstitutionDateParams(widget.institutionId, createdDate),
          ));
          ref.invalidate(lessonsByInstitutionStreamProvider(
            InstitutionDateParams(widget.institutionId, createdDate),
          ));
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
        showAllRoomsOverride: _showAllRoomsOverride,
        onApply: (filters) {
          setState(() => _filters = filters);
        },
        onShowAllRoomsChanged: (value) {
          setState(() => _showAllRoomsOverride = value);
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
  final DayViewStyle dayViewStyle;
  final ValueChanged<DayViewStyle> onDayViewStyleChanged;

  const _ViewModeTabs({
    required this.viewMode,
    required this.onChanged,
    required this.dayViewStyle,
    required this.onDayViewStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Переключатель стиля дневного вида (только для режима "День")
          if (viewMode == ScheduleViewMode.day) ...[
            SegmentedButton<DayViewStyle>(
              segments: const [
                ButtonSegment(
                  value: DayViewStyle.compact,
                  label: Text('Компакт.'),
                ),
                ButtonSegment(
                  value: DayViewStyle.detailed,
                  label: Text('Подробн.'),
                ),
              ],
              selected: {dayViewStyle},
              onSelectionChanged: (selected) {
                onDayViewStyleChanged(selected.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Переключатель День/Неделя
          Expanded(
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
          ),
        ],
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
  final List<Booking> scheduleSlots; // Постоянные слоты (weekly bookings)
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
  final void Function(Booking) onScheduleSlotTap;
  final void Function(String roomId, double currentOffset) onRoomTap;
  final void Function(Room room, int hour, int minute) onAddLesson;
  final VoidCallback? onAddRoom;

  const _AllRoomsTimeGrid({
    super.key,
    required this.rooms,
    required this.allRooms,
    required this.lessons,
    required this.bookings,
    required this.scheduleSlots,
    required this.selectedDate,
    required this.institutionId,
    required this.onLessonTap,
    required this.onBookingTap,
    required this.onScheduleSlotTap,
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
              const SizedBox(width: AppSizes.timeGridWidth),
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
                                          ? const BorderSide(color: AppColors.primary, width: 2)
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
                                            ? const BorderSide(color: AppColors.primary, width: 2)
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
                              // Постоянные слоты (фоновые)
                              ...widget.scheduleSlots.map((slot) => _buildScheduleSlotBlock(context, slot, roomColumnWidth)),
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
                                  // Постоянные слоты (фоновые)
                                  ...widget.scheduleSlots.map((slot) => _buildScheduleSlotBlock(context, slot, roomColumnWidth)),
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
                    // Иконка группы для групповых занятий
                    if (lesson.isGroupLesson) ...[
                      Icon(Icons.groups, size: iconSize, color: color),
                      SizedBox(width: isShort ? 1 : 2),
                    ],
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

  /// Создаёт блок постоянного слота расписания
  Widget _buildScheduleSlotBlock(
    BuildContext context,
    Booking slot,
    double roomColumnWidth,
  ) {
    // Получаем актуальный кабинет на выбранную дату (с учётом замены)
    final effectiveRoomId = slot.getEffectiveRoomId(widget.selectedDate);
    final roomIndex = widget.rooms.indexWhere((r) => r.id == effectiveRoomId);
    if (roomIndex == -1) return const SizedBox.shrink();

    final startMinutes = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMinutes = slot.endTime.hour * 60 + slot.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    final startOffset = (startMinutes - widget.startHour * 60) / 60 * _AllRoomsTimeGrid.hourHeight;
    final duration = durationMinutes / 60 * _AllRoomsTimeGrid.hourHeight;

    // Показываем время только для слотов >= 30 минут
    final showTime = durationMinutes >= 30;

    // Цвет преподавателя (полупрозрачный)
    final teacherColor = _getTeacherColor(slot.teacherId);

    // Для коротких слотов уменьшаем padding
    final isShort = durationMinutes < 30;
    final verticalPadding = isShort ? 2.0 : 4.0;
    final horizontalPadding = isShort ? 3.0 : 4.0;
    final fontSize = isShort ? 9.0 : 10.0;
    final iconSize = isShort ? 10.0 : 12.0;

    // Имя ученика
    final studentName = slot.student?.name ?? 'Ученик';

    // Пометка о замене кабинета
    final hasReplacement = slot.hasReplacement &&
        slot.replacementUntil != null &&
        !widget.selectedDate.isAfter(slot.replacementUntil!);

    return Positioned(
      top: startOffset,
      left: roomIndex * roomColumnWidth + 2,
      width: roomColumnWidth - 4,
      child: GestureDetector(
        onTap: () => widget.onScheduleSlotTap(slot),
        child: Container(
          height: duration,
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: horizontalPadding,
          ),
          decoration: BoxDecoration(
            // Полупрозрачный фон (15% opacity)
            color: teacherColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            // Пунктирная рамка
            border: Border.all(
              color: teacherColor.withValues(alpha: 0.6),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: teacherColor.withValues(alpha: 0.6),
              strokeWidth: 1.5,
              dashWidth: 4,
              dashSpace: 3,
              radius: AppSizes.radiusS,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      // Иконка постоянного расписания
                      Icon(Icons.repeat, size: iconSize, color: teacherColor),
                      SizedBox(width: isShort ? 1 : 2),
                      Expanded(
                        child: Text(
                          studentName,
                          style: TextStyle(
                            // Обычный (не жирный) текст
                            fontWeight: FontWeight.normal,
                            fontSize: fontSize,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // Иконка замены кабинета
                      if (hasReplacement)
                        Icon(Icons.swap_horiz, size: iconSize, color: AppColors.warning),
                    ],
                  ),
                ),
                if (showTime)
                  Text(
                    slot.timeRange,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: isShort ? 8.0 : 9.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Возвращает цвет преподавателя
  Color _getTeacherColor(String? teacherId) {
    if (teacherId == null) return AppColors.primary;
    final teacherColor = widget.teacherColors[teacherId];
    if (teacherColor != null && teacherColor.isNotEmpty) {
      try {
        return Color(int.parse('FF${teacherColor.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    // Fallback цвет
    return AppColors.primary;
  }
}

/// Painter для пунктирной рамки
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    // Рисуем пунктирную линию
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Тип элемента в недельной сетке
enum _ItemType { lesson, booking, slot }

/// Вспомогательный класс для сортировки элементов в недельной сетке
class _ScheduleItem {
  final int startMinutes;
  final _ItemType type;
  final Lesson? lesson;
  final Booking? booking;
  final Booking? slot;

  _ScheduleItem({
    required this.startMinutes,
    required this.type,
    this.lesson,
    this.booking,
    this.slot,
  });
}

/// Компактная сетка расписания на день (аналог недельного вида)
class _CompactDayGrid extends StatefulWidget {
  final List<Room> rooms;
  final List<Room> allRooms;
  final List<Lesson> lessons;
  final List<Booking> bookings;
  final List<Booking> scheduleSlots;
  final DateTime selectedDate;
  final String institutionId;
  final String? selectedRoomId;
  final double? restoreScrollOffset;
  final bool canManageRooms;
  final int startHour;
  final int endHour;
  final Map<String, String?> teacherColors;
  final void Function(Lesson) onLessonTap;
  final void Function(Booking) onBookingTap;
  final void Function(Booking) onScheduleSlotTap;
  final void Function(String roomId, double currentOffset) onRoomTap;
  final void Function(Room room, int hour, int minute) onAddLesson;
  final VoidCallback? onAddRoom;

  const _CompactDayGrid({
    super.key,
    required this.rooms,
    required this.allRooms,
    required this.lessons,
    required this.bookings,
    required this.scheduleSlots,
    required this.selectedDate,
    required this.institutionId,
    required this.onLessonTap,
    required this.onBookingTap,
    required this.onScheduleSlotTap,
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

  static const minRoomColumnWidth = 100.0;
  static const hourLabelWidth = 50.0;
  static const compactHourHeight = 40.0; // Фиксированная высота часа для Stack-based layout

  @override
  State<_CompactDayGrid> createState() => _CompactDayGridState();
}

class _CompactDayGridState extends State<_CompactDayGrid> {
  late ScrollController _headerScrollController;
  late ScrollController _gridScrollController;
  bool _isSyncing = false;
  double _lastScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    final initialOffset = (widget.selectedRoomId == null && widget.restoreScrollOffset != null)
        ? widget.restoreScrollOffset!
        : 0.0;
    _headerScrollController = ScrollController(initialScrollOffset: initialOffset);
    _gridScrollController = ScrollController(initialScrollOffset: initialOffset);
    _headerScrollController.addListener(_syncFromHeader);
    _gridScrollController.addListener(_syncFromGrid);
  }

  @override
  void didUpdateWidget(covariant _CompactDayGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoomId != null &&
        widget.selectedRoomId == null &&
        widget.restoreScrollOffset != null) {
      _recreateControllersWithOffset(widget.restoreScrollOffset!);
    }
  }

  void _recreateControllersWithOffset(double offset) {
    _headerScrollController.removeListener(_syncFromHeader);
    _gridScrollController.removeListener(_syncFromGrid);
    _headerScrollController.dispose();
    _gridScrollController.dispose();

    _headerScrollController = ScrollController(initialScrollOffset: offset);
    _gridScrollController = ScrollController(initialScrollOffset: offset);
    _headerScrollController.addListener(_syncFromHeader);
    _gridScrollController.addListener(_syncFromGrid);
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _headerScrollController.removeListener(_syncFromHeader);
    _gridScrollController.removeListener(_syncFromGrid);
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  void _syncFromHeader() {
    if (_isSyncing) return;
    _isSyncing = true;
    final offset = _headerScrollController.offset;
    _lastScrollOffset = offset;
    if (_gridScrollController.hasClients && _gridScrollController.offset != offset) {
      _gridScrollController.jumpTo(offset);
    }
    _isSyncing = false;
  }

  void _syncFromGrid() {
    if (_isSyncing) return;
    _isSyncing = true;
    final offset = _gridScrollController.offset;
    _lastScrollOffset = offset;
    if (_headerScrollController.hasClients && _headerScrollController.offset != offset) {
      _headerScrollController.jumpTo(offset);
    }
    _isSyncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.rooms;
    final hoursCount = widget.endHour - widget.startHour;

    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.meeting_room_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Нет кабинетов', style: Theme.of(context).textTheme.titleMedium),
            if (widget.canManageRooms && widget.onAddRoom != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onAddRoom,
                icon: const Icon(Icons.add),
                label: const Text('Добавить кабинет'),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Проверяем, помещаются ли все кабинеты на экран
        final availableWidth = constraints.maxWidth - _CompactDayGrid.hourLabelWidth;
        final fitsOnScreen = rooms.length * _CompactDayGrid.minRoomColumnWidth <= availableWidth;
        final roomColumnWidth = fitsOnScreen
            ? availableWidth / rooms.length
            : _CompactDayGrid.minRoomColumnWidth;
        final totalWidth = rooms.length * roomColumnWidth;

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
                  // Пустой угол
                  Container(
                    width: _CompactDayGrid.hourLabelWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Text(
                      'Час',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Заголовки кабинетов
                  Expanded(
                    child: fitsOnScreen
                        ? _buildRoomHeaders(rooms, roomColumnWidth, expandColumns: true)
                        : SingleChildScrollView(
                            controller: _headerScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: totalWidth,
                              child: _buildRoomHeaders(rooms, roomColumnWidth),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // Сетка часов со Stack-based позиционированием
            Expanded(
              child: _buildHoursGrid(
                rooms: rooms,
                hoursCount: hoursCount,
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

  Widget _buildRoomHeaders(List<Room> rooms, double columnWidth, {bool expandColumns = false}) {
    return Row(
      children: rooms.map((room) {
        final content = GestureDetector(
          onTap: () => widget.onRoomTap(room.id, _lastScrollOffset),
          child: Container(
            width: expandColumns ? null : columnWidth,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: widget.selectedRoomId == room.id
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              border: Border(left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
            ),
            child: Text(
              room.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: widget.selectedRoomId == room.id ? FontWeight.bold : FontWeight.w500,
                color: widget.selectedRoomId == room.id
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        );
        return expandColumns ? Expanded(child: content) : content;
      }).toList(),
    );
  }

  Widget _buildHoursGrid({
    required List<Room> rooms,
    required int hoursCount,
    required bool fitsOnScreen,
    required double roomColumnWidth,
    required double totalWidth,
  }) {
    final totalHeight = hoursCount * _CompactDayGrid.compactHourHeight;

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight,
        child: Row(
          children: [
            // Колонка с метками часов
            _buildHourLabels(hoursCount),
            // Сетка + позиционированные элементы
            Expanded(
              child: fitsOnScreen
                  ? _buildGridWithLessons(rooms, hoursCount, roomColumnWidth)
                  : SingleChildScrollView(
                      controller: _gridScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: totalWidth,
                        child: _buildGridWithLessons(rooms, hoursCount, roomColumnWidth),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourLabels(int hoursCount) {
    return Container(
      width: _CompactDayGrid.hourLabelWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: List.generate(hoursCount, (hourIndex) {
          final hour = widget.startHour + hourIndex;
          return Container(
            height: _CompactDayGrid.compactHourHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGridWithLessons(List<Room> rooms, int hoursCount, double columnWidth) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Фоновая сетка с линиями
        _buildGridLines(rooms, hoursCount, columnWidth),
        // Позиционированные занятия
        ...widget.lessons.map((l) => _buildPositionedLesson(l, rooms, columnWidth)),
        // Позиционированные брони
        ...widget.bookings.expand((b) => _buildPositionedBooking(b, rooms, columnWidth)),
        // Позиционированные слоты
        ...widget.scheduleSlots.map((s) => _buildPositionedSlot(s, rooms, columnWidth)),
        // Иконки "+" для свободных мест
        ..._buildAddIconOverlays(rooms, hoursCount, columnWidth),
      ],
    );
  }

  Widget _buildGridLines(List<Room> rooms, int hoursCount, double columnWidth) {
    return Row(
      children: rooms.asMap().entries.map((entry) {
        final index = entry.key;
        return Container(
          width: columnWidth,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).dividerColor,
                width: index == 0 ? 0 : 0.5,
              ),
            ),
          ),
          child: Column(
            children: List.generate(hoursCount, (i) => Container(
              height: _CompactDayGrid.compactHourHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                ),
              ),
            )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPositionedLesson(Lesson lesson, List<Room> rooms, double columnWidth) {
    final roomIndex = rooms.indexWhere((r) => r.id == lesson.roomId);
    if (roomIndex == -1) return const SizedBox.shrink();

    final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    final startOffset = (startMinutes - widget.startHour * 60) / 60 * _CompactDayGrid.compactHourHeight;
    final height = durationMinutes / 60 * _CompactDayGrid.compactHourHeight;

    final bgColor = _getLessonColor(lesson);
    final textColor = _getContrastTextColor(bgColor);

    return Positioned(
      top: startOffset + 1,
      left: roomIndex * columnWidth + 1,
      width: columnWidth - 2,
      height: height - 2,
      child: GestureDetector(
        onTap: () => widget.onLessonTap(lesson),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Время и имя
              Row(
                children: [
                  Text(
                    '${lesson.startTime.hour.toString().padLeft(2, '0')}:${lesson.startTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textColor),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      lesson.student?.name ?? lesson.group?.name ?? '',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Иконки статуса (если есть место)
              if (height > 24)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lesson.isGroupLesson)
                      Icon(Icons.groups, size: 10, color: textColor.withValues(alpha: 0.8)),
                    if (lesson.isRepeating)
                      Padding(
                        padding: EdgeInsets.only(left: lesson.isGroupLesson ? 2 : 0),
                        child: Icon(Icons.repeat, size: 10, color: textColor.withValues(alpha: 0.8)),
                      ),
                    if (lesson.status == LessonStatus.completed)
                      Padding(
                        padding: EdgeInsets.only(left: (lesson.isGroupLesson || lesson.isRepeating) ? 2 : 0),
                        child: Icon(Icons.check_circle, size: 10, color: AppColors.success),
                      ),
                    if (lesson.status == LessonStatus.cancelled)
                      Padding(
                        padding: EdgeInsets.only(left: (lesson.isGroupLesson || lesson.isRepeating) ? 2 : 0),
                        child: Icon(Icons.cancel, size: 10, color: AppColors.error),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPositionedBooking(Booking booking, List<Room> rooms, double columnWidth) {
    final widgets = <Widget>[];

    for (final bookingRoom in booking.rooms) {
      final roomIndex = rooms.indexWhere((r) => r.id == bookingRoom.id);
      if (roomIndex == -1) continue;

      final startMinutes = booking.startTime.hour * 60 + booking.startTime.minute;
      final endMinutes = booking.endTime.hour * 60 + booking.endTime.minute;
      final durationMinutes = endMinutes - startMinutes;

      final startOffset = (startMinutes - widget.startHour * 60) / 60 * _CompactDayGrid.compactHourHeight;
      final height = durationMinutes / 60 * _CompactDayGrid.compactHourHeight;

      widgets.add(Positioned(
        top: startOffset + 1,
        left: roomIndex * columnWidth + 1,
        width: columnWidth - 2,
        height: height - 2,
        child: GestureDetector(
          onTap: () => widget.onBookingTap(booking),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, size: 9, color: Colors.grey[700]),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    booking.description ?? 'Бронь',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return widgets;
  }

  Widget _buildPositionedSlot(Booking slot, List<Room> rooms, double columnWidth) {
    final effectiveRoomId = slot.getEffectiveRoomId(widget.selectedDate);
    final roomIndex = rooms.indexWhere((r) => r.id == effectiveRoomId);
    if (roomIndex == -1) return const SizedBox.shrink();

    final startMinutes = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMinutes = slot.endTime.hour * 60 + slot.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    final startOffset = (startMinutes - widget.startHour * 60) / 60 * _CompactDayGrid.compactHourHeight;
    final height = durationMinutes / 60 * _CompactDayGrid.compactHourHeight;

    return Positioned(
      top: startOffset + 1,
      left: roomIndex * columnWidth + 1,
      width: columnWidth - 2,
      height: height - 2,
      child: GestureDetector(
        onTap: () => widget.onScheduleSlotTap(slot),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.repeat, size: 9, color: AppColors.primary.withValues(alpha: 0.8)),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  slot.student?.name ?? '',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.primary.withValues(alpha: 0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAddIconOverlays(List<Room> rooms, int hoursCount, double columnWidth) {
    final widgets = <Widget>[];

    for (var hourIndex = 0; hourIndex < hoursCount; hourIndex++) {
      final hour = widget.startHour + hourIndex;

      for (var roomIndex = 0; roomIndex < rooms.length; roomIndex++) {
        final room = rooms[roomIndex];

        // Получаем все элементы для этого часа и кабинета
        final roomLessons = widget.lessons.where((l) => l.roomId == room.id).toList();
        final roomBookings = widget.bookings.where((b) => b.rooms.any((r) => r.id == room.id)).toList();
        final roomSlots = widget.scheduleSlots.where((s) {
          final effectiveRoomId = s.getEffectiveRoomId(widget.selectedDate);
          return effectiveRoomId == room.id;
        }).toList();

        // Проверяем свободное место >= 15 мин в этом часе
        final gap = _findGapInHour(room, hour, roomLessons, roomBookings, roomSlots);

        if (gap != null) {
          // Вычисляем позицию иконки "+" в середине свободного промежутка
          final gapStartMinutes = hour * 60 + gap.start;
          final gapEndMinutes = hour * 60 + gap.end;
          final gapCenterMinutes = (gapStartMinutes + gapEndMinutes) / 2;

          final topOffset = (gapCenterMinutes - widget.startHour * 60) / 60 * _CompactDayGrid.compactHourHeight - 8;

          widgets.add(Positioned(
            top: topOffset,
            left: roomIndex * columnWidth + columnWidth / 2 - 8,
            child: GestureDetector(
              onTap: () => widget.onAddLesson(room, hour, gap.start),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  size: 12,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                ),
              ),
            ),
          ));
        }
      }
    }

    return widgets;
  }

  Color _getLessonColor(Lesson lesson) {
    final teacherColor = widget.teacherColors[lesson.teacherId];
    if (teacherColor != null && teacherColor.isNotEmpty) {
      try {
        return Color(int.parse('FF${teacherColor.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    if (lesson.group != null) {
      return AppColors.lessonGroup;
    }
    return AppColors.lessonIndividual;
  }

  /// Находит свободный промежуток >= 15 мин в ячейке часа
  /// Возвращает (startMinuteInHour, endMinuteInHour) или null если нет места
  ({int start, int end})? _findGapInHour(
    Room room,
    int hour,
    List<Lesson> lessons,
    List<Booking> bookings,
    List<Booking> slots,
  ) {
    const minGapMinutes = 15;
    final hourStart = hour * 60;
    final hourEnd = (hour + 1) * 60;

    // Собираем занятые интервалы в этом часе
    final occupiedIntervals = <({int start, int end})>[];

    // Занятия
    for (final lesson in lessons) {
      if (lesson.roomId != room.id) continue;

      final lessonStart = lesson.startTime.hour * 60 + lesson.startTime.minute;
      final lessonEnd = lesson.endTime.hour * 60 + lesson.endTime.minute;

      if (lessonEnd > hourStart && lessonStart < hourEnd) {
        occupiedIntervals.add((
          start: lessonStart.clamp(hourStart, hourEnd),
          end: lessonEnd.clamp(hourStart, hourEnd),
        ));
      }
    }

    // Брони
    for (final booking in bookings) {
      final hasRoom = booking.rooms.any((r) => r.id == room.id);
      if (!hasRoom) continue;

      final bookingStart = booking.startTime.hour * 60 + booking.startTime.minute;
      final bookingEnd = booking.endTime.hour * 60 + booking.endTime.minute;

      if (bookingEnd > hourStart && bookingStart < hourEnd) {
        occupiedIntervals.add((
          start: bookingStart.clamp(hourStart, hourEnd),
          end: bookingEnd.clamp(hourStart, hourEnd),
        ));
      }
    }

    // Слоты постоянного расписания
    for (final slot in slots) {
      final effectiveRoomId = slot.getEffectiveRoomId(widget.selectedDate);
      if (effectiveRoomId != room.id) continue;

      final slotStart = slot.startTime.hour * 60 + slot.startTime.minute;
      final slotEnd = slot.endTime.hour * 60 + slot.endTime.minute;

      if (slotEnd > hourStart && slotStart < hourEnd) {
        occupiedIntervals.add((
          start: slotStart.clamp(hourStart, hourEnd),
          end: slotEnd.clamp(hourStart, hourEnd),
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

  Color _getContrastTextColor(Color backgroundColor) {
    final luminance = 0.299 * backgroundColor.r +
        0.587 * backgroundColor.g +
        0.114 * backgroundColor.b;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// Сетка расписания на неделю
class _WeekTimeGrid extends StatefulWidget {
  final List<Room> rooms;
  final List<Room> allRooms;
  final Map<DateTime, List<Lesson>> lessonsByDay;
  final Map<DateTime, List<Booking>> bookingsByDay;
  final Map<DateTime, List<Booking>> slotsByDay;
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
    required this.bookingsByDay,
    required this.slotsByDay,
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
        // Вычисляем высоту каждой строки на основе максимального количества элементов (занятия + брони + слоты)
        final baseRowHeights = <int, double>{};
        final maxItemsPerDay = <int, int>{}; // Для распределения extra
        for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
          final date = widget.weekStart.add(Duration(days: dayIndex));
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final dayLessons = widget.lessonsByDay[normalizedDate] ?? [];
          final dayBookings = widget.bookingsByDay[normalizedDate] ?? [];
          final daySlots = widget.slotsByDay[normalizedDate] ?? [];

          int maxItems = 0;
          for (final room in rooms) {
            final lessonsCount = dayLessons.where((l) => l.roomId == room.id).length;
            final bookingsCount = dayBookings.where((b) => b.rooms.any((r) => r.id == room.id)).length;
            final slotsCount = daySlots.where((s) => s.getEffectiveRoomId(date) == room.id).length;
            final totalCount = lessonsCount + bookingsCount + slotsCount;
            if (totalCount > maxItems) maxItems = totalCount;
          }

          maxItemsPerDay[dayIndex] = maxItems; // Сохраняем для расчёта flex
          baseRowHeights[dayIndex] = maxItems > 0
              ? (maxItems * _WeekTimeGrid.lessonItemHeight + 8).clamp(_WeekTimeGrid.minRowHeight, double.infinity)
              : _WeekTimeGrid.minRowHeight;
        }

        // Вычисляем доступную высоту для строк дней (минус заголовок 40px)
        const headerHeight = 40.0;
        final availableHeight = constraints.maxHeight - headerHeight;
        final totalMinHeight = baseRowHeights.values.fold(0.0, (sum, h) => sum + h);

        // Распределяем extra ТОЛЬКО на пустые/малозаполненные дни
        // Дни с >= 2 занятиями не растягиваются вообще
        final rowHeights = <int, double>{};
        if (totalMinHeight < availableHeight) {
          const stretchThreshold = 2; // Дни с >= 2 занятий не растягиваются

          // Считаем сколько дней могут растягиваться
          int stretchableDays = 0;
          for (var i = 0; i < 7; i++) {
            if ((maxItemsPerDay[i] ?? 0) < stretchThreshold) {
              stretchableDays++;
            }
          }

          final extraTotal = availableHeight - totalMinHeight;
          final extraPerStretchableDay = stretchableDays > 0 ? extraTotal / stretchableDays : 0.0;

          for (var i = 0; i < 7; i++) {
            final items = maxItemsPerDay[i] ?? 0;
            if (items < stretchThreshold) {
              // Пустой/малозаполненный день — растягиваем
              rowHeights[i] = baseRowHeights[i]! + extraPerStretchableDay;
            } else {
              // Заполненный день — не растягиваем
              rowHeights[i] = baseRowHeights[i]!;
            }
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
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dayBookings = widget.bookingsByDay[normalizedDate] ?? [];
    final daySlots = widget.slotsByDay[normalizedDate] ?? [];

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

        // Брони для этого кабинета
        final roomBookings = dayBookings
            .where((b) => b.rooms.any((r) => r.id == room.id))
            .toList()
          ..sort((a, b) {
            final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
            final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
            return aMinutes.compareTo(bMinutes);
          });

        // Постоянные слоты для этого кабинета
        final roomSlots = daySlots
            .where((s) => s.getEffectiveRoomId(date) == room.id)
            .toList();

        final hasContent = roomLessons.isNotEmpty || roomBookings.isNotEmpty || roomSlots.isNotEmpty;

        final content = GestureDetector(
          onTap: () => widget.onCellTap(room, date),
          child: Container(
            width: expandColumns ? null : roomColumnWidth,
            alignment: Alignment.topLeft,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: hasContent
                ? _buildItemsList(roomLessons, roomBookings, roomSlots)
                : const SizedBox.shrink(),
          ),
        );
        return expandColumns ? Expanded(child: content) : content;
      }).toList(),
    );
  }

  /// Строит список всех элементов (занятия, брони, слоты) отсортированных по времени
  Widget _buildItemsList(List<Lesson> lessons, List<Booking> bookings, List<Booking> slots) {
    // Собираем все элементы с временем начала для сортировки
    final items = <_ScheduleItem>[];

    for (final lesson in lessons) {
      items.add(_ScheduleItem(
        startMinutes: lesson.startTime.hour * 60 + lesson.startTime.minute,
        type: _ItemType.lesson,
        lesson: lesson,
      ));
    }

    for (final booking in bookings) {
      items.add(_ScheduleItem(
        startMinutes: booking.startTime.hour * 60 + booking.startTime.minute,
        type: _ItemType.booking,
        booking: booking,
      ));
    }

    for (final slot in slots) {
      items.add(_ScheduleItem(
        startMinutes: slot.startTime.hour * 60 + slot.startTime.minute,
        type: _ItemType.slot,
        slot: slot,
      ));
    }

    // Сортируем по времени начала
    items.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        switch (item.type) {
          case _ItemType.lesson:
            return _buildLessonItem(item.lesson!);
          case _ItemType.booking:
            return _buildBookingItem(item.booking!);
          case _ItemType.slot:
            return _buildSlotItem(item.slot!);
        }
      }).toList(),
    );
  }

  Widget _buildLessonItem(Lesson lesson) {
    final bgColor = _getLessonColor(lesson);
    final textColor = _getContrastTextColor(bgColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${lesson.startTime.hour}:${lesson.startTime.minute.toString().padLeft(2, '0')} ${lesson.student?.name ?? lesson.group?.name ?? ''}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBookingItem(Booking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 10, color: Colors.grey[700]),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              '${booking.startTime.hour}:${booking.startTime.minute.toString().padLeft(2, '0')} ${booking.description ?? 'Бронь'}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotItem(Booking slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 10, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              '${slot.startTime.hour}:${slot.startTime.minute.toString().padLeft(2, '0')} ${slot.student?.name ?? ''}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

  /// Возвращает контрастный цвет текста (белый или чёрный) в зависимости от яркости фона
  Color _getContrastTextColor(Color backgroundColor) {
    // Вычисляем относительную яркость по формуле W3C
    // Используем новый API: r, g, b возвращают значения 0.0-1.0
    final luminance = 0.299 * backgroundColor.r +
        0.587 * backgroundColor.g +
        0.114 * backgroundColor.b;
    // Если яркость > 0.5 — фон светлый, используем тёмный текст
    return luminance > 0.5 ? Colors.black87 : Colors.white;
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
    final canEdit = hasFullAccess ||
                    (permissions?.editAllLessons ?? false) ||
                    (isOwnLesson && (permissions?.editOwnLessons ?? true));

    // Проверка даты: прошлые занятия нельзя отменить
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final lessonDate = DateTime(lesson.date.year, lesson.date.month, lesson.date.day);
    final isPastLesson = lessonDate.isBefore(todayOnly);

    // Можно отменить только сегодняшние и будущие занятия (и не уже отменённые)
    final canCancel = canDelete && !isPastLesson && !_isCancelled;

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
      // Ограничиваем высоту, чтобы избежать overflow
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle (вне скролла)
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Скроллируемое содержимое
          Flexible(
            child: SingleChildScrollView(
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
                                Icon(Icons.school, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    teacherName,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    // Бейдж "Отменено" (если занятие отменено)
                    if (_isCancelled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Отменено',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                        const _DetailRow(
                          icon: Icons.repeat_rounded,
                          label: 'Повтор',
                          value: 'Да',
                        ),
                    ],
                  ),
                ),

                // Секция участников для групповых занятий
                if (lesson.isGroupLesson) ...[
                  const SizedBox(height: 16),
                  _GroupParticipantsSection(
                    lesson: lesson,
                    institutionId: widget.institutionId,
                    isCompleted: _isCompleted,
                    isLoading: _isLoading,
                    hasPrice: hasPrice,
                    onUpdated: () {
                      widget.onUpdated();
                      // Перезагружаем данные занятия
                      ref.invalidate(lessonsByInstitutionStreamProvider(
                        InstitutionDateParams(widget.institutionId, lesson.date),
                      ));
                    },
                  ),
                ],

                // Статусы (только если есть право редактирования)
                if (canEdit) ...[
                  const SizedBox(height: 16),

                  // Статусы (оптимистичное обновление — UI меняется мгновенно)
                  Row(
                    children: [
                      // Проведено
                      Expanded(
                        child: _StatusButton(
                          label: 'Проведено',
                          icon: Icons.check_circle_rounded,
                          isActive: _isCompleted,
                          color: AppColors.success,
                          isLoading: _isLoading,
                          onTap: () => _handleStatusChange(completed: !_isCompleted),
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
                            isLoading: _isLoading || _isLoadingPayment,
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
                ], // конец if (canEdit)

                const SizedBox(height: 20),

                // Кнопки действий (только если есть хотя бы одно право)
                if (canEdit || canCancel)
                  Row(
                    children: [
                      // Редактировать (только если есть право)
                      if (canEdit)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: controllerState.isLoading || _isLoading
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: lesson.isRepeating,
                                      builder: (ctx) => lesson.isRepeating
                                          ? _EditSeriesSheet(
                                              lesson: lesson,
                                              institutionId: widget.institutionId,
                                              onUpdated: widget.onUpdated,
                                            )
                                          : _EditLessonSheet(
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
                      // Отменить занятие (только если есть право и занятие не в прошлом)
                      if (canCancel) ...[
                        if (canEdit) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: controllerState.isLoading || _isLoading
                                ? null
                                : _showCancelSheet,
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Отменить'),
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
        ), // Flexible
        ],
      ),
    );
  }

  Future<void> _handleStatusChange({bool? completed, bool? cancelled}) async {
    if (_isLoading) return;

    final controller = ref.read(lessonControllerProvider.notifier);
    final lesson = widget.lesson;

    // Сохраняем текущий статус для отката при ошибке
    final previousStatus = _currentStatus;

    // Определяем новый статус
    LessonStatus newStatus;
    if (completed == true) {
      newStatus = LessonStatus.completed;
    } else if (cancelled == true) {
      newStatus = LessonStatus.cancelled;
    } else {
      newStatus = LessonStatus.scheduled;
    }

    // Оптимистичное обновление — мгновенно меняем UI БЕЗ индикатора загрузки
    setState(() {
      _currentStatus = newStatus;
    });

    // Сохранение в фоне (без блокировки UI)
    bool success = false;

    if (completed == true) {
      success = await controller.complete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
    } else if (completed == false && previousStatus == LessonStatus.completed) {
      success = await controller.uncomplete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
    } else if (cancelled == true) {
      success = await controller.cancel(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
    } else if (cancelled == false && previousStatus == LessonStatus.cancelled) {
      success = await controller.uncomplete(lesson.id, lesson.roomId, lesson.date, widget.institutionId);
    }

    if (mounted && !success) {
      // Откат при ошибке + показываем сообщение
      setState(() {
        _currentStatus = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось обновить статус'),
          backgroundColor: Colors.red,
        ),
      );
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

  /// Открывает шторку отмены занятия
  void _showCancelSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CancelLessonSheet(
        lesson: widget.lesson,
        institutionId: widget.institutionId,
        onCancelled: () {
          widget.onUpdated();
          // Закрываем и детали занятия
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Диалог отмены занятия
/// Объединяет удаление и отмену в одну функцию с опцией списания баланса
class _CancelLessonSheet extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String institutionId;
  final VoidCallback onCancelled;

  const _CancelLessonSheet({
    required this.lesson,
    required this.institutionId,
    required this.onCancelled,
  });

  @override
  ConsumerState<_CancelLessonSheet> createState() => _CancelLessonSheetState();
}

class _CancelLessonSheetState extends ConsumerState<_CancelLessonSheet> {
  bool _deductFromBalance = false;
  bool _cancelFollowing = false;
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;
  int _followingCount = 1;

  @override
  void initState() {
    super.initState();
    _loadFollowingCount();
    // Для групповых — по умолчанию выбираем всех
    if (widget.lesson.isGroupLesson && widget.lesson.lessonStudents != null) {
      for (final ls in widget.lesson.lessonStudents!) {
        _selectedStudentIds.add(ls.studentId);
      }
    }
  }

  Future<void> _loadFollowingCount() async {
    if (widget.lesson.repeatGroupId != null) {
      final controller = ref.read(lessonControllerProvider.notifier);
      // Считаем ВСЕ занятия серии (включая разные дни недели)
      // После исправления UUID все занятия weekdays-серии имеют один repeatGroupId
      final count = await controller.getFollowingCount(
        widget.lesson.repeatGroupId!,
        widget.lesson.date,
      );
      if (mounted) {
        setState(() => _followingCount = count);
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    String message;
    bool success;

    if (_cancelFollowing && widget.lesson.repeatGroupId != null) {
      // Отмена серии
      final count = await controller.cancelFollowingLessons(
        lesson: widget.lesson,
        deductFromBalance: _deductFromBalance,
        institutionId: widget.institutionId,
      );
      success = count > 0;
      message = 'Отменено $count занятий';
    } else {
      // Отмена одного занятия
      success = await controller.cancelLesson(
        lesson: widget.lesson,
        deductFromBalance: _deductFromBalance,
        institutionId: widget.institutionId,
        studentIdsToDeduct: widget.lesson.isGroupLesson ? _selectedStudentIds.toList() : null,
      );
      message = 'Занятие отменено';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      widget.onCancelled();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lesson = widget.lesson;
    final isCompleted = lesson.status == LessonStatus.completed;
    final showSeriesOption = lesson.repeatGroupId != null && _followingCount > 1;

    // Определяем дату занятия относительно сегодня
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final lessonDate = DateTime(lesson.date.year, lesson.date.month, lesson.date.day);
    final isToday = lessonDate.isAtSameMomentAs(todayOnly);
    final isFuture = lessonDate.isAfter(todayOnly);

    // Для сегодняшних — можно выбрать списание
    // Для будущих — списание недоступно (только архивация)
    final canShowDeductOption = isToday && !isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Text(
                  'Отменить занятие',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Информация о занятии
                Text(
                  lesson.participantName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Информация для будущих занятий (без списания)
                if (isFuture) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Занятие будет отменено и архивировано без списания с баланса',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Предупреждение для проведённых занятий
                if (isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Занятие уже проведено. Списание баланса недоступно.',
                            style: TextStyle(color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Переключатель списания баланса (только для сегодняшних)
                if (canShowDeductOption) ...[
                  SwitchListTile(
                    value: _deductFromBalance,
                    onChanged: (value) => setState(() => _deductFromBalance = value),
                    title: const Text('Списать занятие с баланса'),
                    subtitle: const Text('Занятие будет вычтено из предоплаченных'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                // Для групповых — чекбоксы участников (только для сегодняшних со списанием)
                if (canShowDeductOption && _deductFromBalance && lesson.isGroupLesson) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Кому списать занятие:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...?lesson.lessonStudents?.map((ls) {
                    final isSelected = _selectedStudentIds.contains(ls.studentId);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedStudentIds.add(ls.studentId);
                          } else {
                            _selectedStudentIds.remove(ls.studentId);
                          }
                        });
                      },
                      title: Text(ls.student?.name ?? 'Ученик'),
                      subtitle: Text('Баланс: ${ls.student?.balance ?? 0}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Для серии — выбор "только это" или "все последующие"
                if (showSeriesOption) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Это занятие является частью серии ($_followingCount шт.)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Только это'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Это и последующие'),
                      ),
                    ],
                    selected: {_cancelFollowing},
                    onSelectionChanged: (selected) {
                      setState(() => _cancelFollowing = selected.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Подсказка: при отмене серии списывается только сегодняшнее
                  if (_cancelFollowing && canShowDeductOption && _deductFromBalance) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Списание применится только к сегодняшнему занятию',
                              style: TextStyle(fontSize: 12, color: colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Подсказка для будущих: все занятия серии будут архивированы без списания
                  if (_cancelFollowing && isFuture) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Все занятия серии будут архивированы без списания',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Кнопка отмены
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _cancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _cancelFollowing
                                ? 'Отменить $_followingCount занятий'
                                : 'Отменить занятие',
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Кнопка "Назад"
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Назад'),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Секция участников группового занятия
class _GroupParticipantsSection extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String institutionId;
  final bool isCompleted;
  final bool isLoading;
  final bool hasPrice;
  final VoidCallback onUpdated;

  const _GroupParticipantsSection({
    required this.lesson,
    required this.institutionId,
    required this.isCompleted,
    required this.isLoading,
    required this.hasPrice,
    required this.onUpdated,
  });

  @override
  ConsumerState<_GroupParticipantsSection> createState() => _GroupParticipantsSectionState();
}

class _GroupParticipantsSectionState extends ConsumerState<_GroupParticipantsSection> {
  final Map<String, bool> _attendanceState = {};
  final Map<String, bool> _paymentState = {};
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем состояние присутствия из данных занятия
    if (widget.lesson.lessonStudents != null) {
      for (final ls in widget.lesson.lessonStudents!) {
        _attendanceState[ls.studentId] = ls.attended;
        // По умолчанию оплата включена для присутствующих (когда занятие ещё не завершено)
        // или false если занятие уже завершено (оплата уже была обработана)
        _paymentState[ls.studentId] = !widget.isCompleted && ls.attended;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final participants = widget.lesson.lessonStudents ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              Icon(Icons.groups, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Участники',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // Счётчик присутствия
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_attendanceState.values.where((v) => v).length}/${participants.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Список участников
          if (participants.isEmpty)
            Text(
              'Нет участников',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          else
            ...participants.map((ls) => _buildParticipantTile(ls)),

          // Кнопка добавления гостя (только если не завершено)
          if (!widget.isCompleted) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isUpdating ? null : _showAddGuestDialog,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Добавить гостя'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                // Кнопка оплаты (только если есть цена)
                if (widget.hasPrice && _hasPaymentsToProcess)
                  ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _handleGroupPayments,
                    icon: const Icon(Icons.monetization_on, size: 18),
                    label: const Text('Оплатить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantTile(LessonStudent ls) {
    final colorScheme = Theme.of(context).colorScheme;
    final studentName = ls.student?.name ?? 'Неизвестный';
    final attended = _attendanceState[ls.studentId] ?? ls.attended;
    final shouldPay = _paymentState[ls.studentId] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Чекбокс присутствия
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: attended,
              onChanged: widget.isCompleted || _isUpdating
                  ? null
                  : (value) => _handleAttendanceChange(ls.studentId, value ?? true),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          // Имя участника
          Expanded(
            child: Text(
              studentName,
              style: TextStyle(
                fontSize: 14,
                color: attended ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                decoration: attended ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          // Чекбокс оплаты (если есть цена и занятие не завершено)
          if (widget.hasPrice && !widget.isCompleted) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Оплата',
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: shouldPay,
                  onChanged: _isUpdating || !attended
                      ? null
                      : (value) {
                          setState(() {
                            _paymentState[ls.studentId] = value ?? false;
                          });
                        },
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Icon(
              Icons.monetization_on,
              size: 16,
              color: shouldPay && attended
                  ? AppColors.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
          // Кнопка удаления (только если не завершено и можно удалить)
          if (!widget.isCompleted)
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: _isUpdating ? null : () => _removeParticipant(ls.studentId, ls.student?.name),
              tooltip: 'Убрать из занятия',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  /// Проверка, есть ли участники для оплаты
  bool get _hasPaymentsToProcess {
    for (final entry in _paymentState.entries) {
      final studentId = entry.key;
      final shouldPay = entry.value;
      final attended = _attendanceState[studentId] ?? false;
      if (shouldPay && attended) return true;
    }
    return false;
  }

  Future<void> _handleAttendanceChange(String studentId, bool attended) async {
    setState(() {
      _attendanceState[studentId] = attended;
      // Автоматически включаем оплату при включении присутствия, выключаем при выключении
      if (widget.hasPrice) {
        _paymentState[studentId] = attended;
      }
    });

    // Сохраняем в БД
    final controller = ref.read(lessonControllerProvider.notifier);
    await controller.updateAttendance(
      widget.lesson.id,
      studentId,
      attended,
      widget.lesson.roomId,
      widget.lesson.date,
      widget.institutionId,
    );
  }

  /// Обработка оплаты для выбранных участников
  Future<void> _handleGroupPayments() async {
    final price = widget.lesson.lessonType?.defaultPrice;
    if (price == null || price <= 0) return;

    // Собираем студентов для оплаты
    final studentsToProcess = <String>[];
    for (final entry in _paymentState.entries) {
      final studentId = entry.key;
      final shouldPay = entry.value;
      final attended = _attendanceState[studentId] ?? false;
      if (shouldPay && attended) {
        studentsToProcess.add(studentId);
      }
    }

    if (studentsToProcess.isEmpty) return;

    setState(() => _isUpdating = true);

    try {
      final paymentController = ref.read(paymentControllerProvider.notifier);

      for (final studentId in studentsToProcess) {
        await paymentController.create(
          institutionId: widget.institutionId,
          studentId: studentId,
          amount: price,
          lessonsCount: 1,
          comment: 'lesson:${widget.lesson.id}|group|$studentId',
        );

        // Снимаем галочку оплаты после успешной оплаты
        if (mounted) {
          setState(() {
            _paymentState[studentId] = false;
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Оплата записана: ${studentsToProcess.length} ${_pluralStudents(studentsToProcess.length)}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка оплаты: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
        widget.onUpdated();
      }
    }
  }

  String _pluralStudents(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'ученик';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'ученика';
    return 'учеников';
  }

  Future<void> _removeParticipant(String studentId, String? studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Убрать участника?'),
        content: Text(
          studentName != null
              ? 'Убрать $studentName из этого занятия?'
              : 'Убрать участника из этого занятия?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final success = await controller.removeLessonStudent(
      widget.lesson.id,
      studentId,
      widget.lesson.roomId,
      widget.lesson.date,
      widget.institutionId,
    );

    if (success && mounted) {
      setState(() {
        _attendanceState.remove(studentId);
        _isUpdating = false;
      });
      widget.onUpdated();
    } else if (mounted) {
      setState(() => _isUpdating = false);
    }
  }

  void _showAddGuestDialog() {
    final studentsAsync = ref.read(studentsProvider(widget.institutionId));
    final existingIds = widget.lesson.lessonStudents?.map((ls) => ls.studentId).toSet() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Добавить гостя',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: studentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                  data: (students) {
                    final availableStudents = students
                        .where((s) => !existingIds.contains(s.id))
                        .toList();
                    if (availableStudents.isEmpty) {
                      return const Center(
                        child: Text('Все ученики уже добавлены'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: availableStudents.length,
                      itemBuilder: (context, index) {
                        final student = availableStudents[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, color: AppColors.primary),
                          ),
                          title: Text(student.name),
                          onTap: () => _addGuest(student.id, student.name),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addGuest(String studentId, String studentName) async {
    Navigator.pop(context); // Закрываем диалог выбора

    setState(() => _isUpdating = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final success = await controller.addGuestToLesson(
      widget.lesson.id,
      studentId,
      widget.lesson.roomId,
      widget.lesson.date,
      widget.institutionId,
    );

    if (success && mounted) {
      setState(() {
        _attendanceState[studentId] = true;
        _isUpdating = false;
      });
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$studentName добавлен как гость'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      setState(() => _isUpdating = false);
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : colorScheme.outlineVariant,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? color : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? color : colorScheme.onSurfaceVariant,
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
  String? _selectedGroupId;
  String? _selectedSubjectId;
  String? _selectedLessonTypeId;
  String? _selectedRoomId;

  /// Является ли занятие групповым (определяется при инициализации и не меняется)
  bool get _isGroupLesson => widget.lesson.groupId != null;

  @override
  void initState() {
    super.initState();
    _startTime = widget.lesson.startTime;
    _endTime = widget.lesson.endTime;
    _date = widget.lesson.date;
    _selectedStudentId = widget.lesson.studentId;
    _selectedGroupId = widget.lesson.groupId;
    _selectedSubjectId = widget.lesson.subjectId;
    _selectedLessonTypeId = widget.lesson.lessonTypeId;
    _selectedRoomId = widget.lesson.roomId;

  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final groupsAsync = ref.watch(studentGroupsProvider(widget.institutionId));
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

            // Время (комбинированный пикер)
            InkWell(
              onTap: () async {
                final range = await showIosTimeRangePicker(
                  context: context,
                  initialStartTime: _startTime,
                  initialEndTime: _endTime,
                  minuteInterval: 5,
                );
                if (range != null) {
                  setState(() {
                    _startTime = range.start;
                    _endTime = range.end;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Время',
                  prefixIcon: Icon(Icons.access_time),
                ),
                child: Text('${_formatTime(_startTime)} – ${_formatTime(_endTime)}'),
              ),
            ),
            const SizedBox(height: 16),

            // Кабинет
            roomsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (rooms) {
                return DropdownButtonFormField<String?>(
                  key: ValueKey('room_$_selectedRoomId'),
                  decoration: const InputDecoration(
                    labelText: 'Кабинет',
                    prefixIcon: Icon(Icons.door_front_door),
                  ),
                  initialValue: _selectedRoomId,
                  items: rooms.map((r) => DropdownMenuItem<String?>(
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

            // Ученик или Группа (зависит от типа занятия)
            if (_isGroupLesson)
              groupsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => ErrorView.inline(e),
                data: (groups) {
                  return DropdownButtonFormField<String?>(
                    key: ValueKey('group_$_selectedGroupId'),
                    decoration: const InputDecoration(
                      labelText: 'Группа',
                      prefixIcon: Icon(Icons.groups),
                    ),
                    initialValue: _selectedGroupId,
                    items: groups.map((g) => DropdownMenuItem<String?>(
                      value: g.id,
                      child: Text(g.name),
                    )).toList(),
                    onChanged: (groupId) {
                      setState(() => _selectedGroupId = groupId);
                    },
                  );
                },
              )
            else
              studentsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => ErrorView.inline(e),
                data: (students) {
                  return DropdownButtonFormField<String?>(
                    key: ValueKey('student_$_selectedStudentId'),
                    decoration: const InputDecoration(
                      labelText: 'Ученик',
                      prefixIcon: Icon(Icons.person),
                    ),
                    initialValue: _selectedStudentId,
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
                  key: ValueKey('subject_$_selectedSubjectId'),
                  decoration: const InputDecoration(
                    labelText: 'Предмет',
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  initialValue: _selectedSubjectId,
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
                  key: ValueKey('type_$_selectedLessonTypeId'),
                  decoration: const InputDecoration(
                    labelText: 'Тип занятия',
                    prefixIcon: Icon(Icons.category),
                  ),
                  initialValue: _selectedLessonTypeId,
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

    // Проверяем, изменилось ли хоть одно поле
    final timeChanged = _startTime != lesson.startTime || _endTime != lesson.endTime;
    final roomChanged = _selectedRoomId != lesson.roomId;
    final studentChanged = !_isGroupLesson && _selectedStudentId != lesson.studentId;
    final subjectChanged = _selectedSubjectId != lesson.subjectId;
    final lessonTypeChanged = _selectedLessonTypeId != lesson.lessonTypeId;
    final dateChanged = _date.year != lesson.date.year ||
        _date.month != lesson.date.month ||
        _date.day != lesson.date.day;

    final hasAnyChange = timeChanged || roomChanged || studentChanged ||
        subjectChanged || lessonTypeChanged || dateChanged;

    // Если ничего не изменилось — просто закрываем
    if (!hasAnyChange) {
      Navigator.pop(context);
      return;
    }

    // Обновление занятия (для повторяющихся используется _EditSeriesSheet напрямую)
    final success = await controller.update(
      lesson.id,
      roomId: lesson.roomId,
      date: lesson.date,
      institutionId: widget.institutionId,
      newRoomId: _selectedRoomId,
      newDate: _date,
      startTime: _startTime,
      endTime: _endTime,
      studentId: _isGroupLesson ? null : _selectedStudentId,
      groupId: _isGroupLesson ? _selectedGroupId : null,
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

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Форма создания нового занятия, бронирования или постоянного расписания
/// Режим формы: занятие, бронирование или постоянное расписание
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

/// Область редактирования серии занятий
enum EditScope {
  thisOnly('Только это занятие'),
  thisAndFollowing('Это и последующие'),
  all('Все занятия серии'),
  selected('Выбранные');

  final String label;
  const EditScope(this.label);
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

/// Выбор ученика с возможностью показать всех без закрытия
class _StudentPickerSheet extends StatefulWidget {
  final List<Student> myStudents;
  final List<Student> otherStudents;
  final Student? currentStudent;
  final void Function(Student student) onStudentSelected;

  const _StudentPickerSheet({
    required this.myStudents,
    required this.otherStudents,
    required this.currentStudent,
    required this.onStudentSelected,
  });

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  bool _showAllStudents = false;

  @override
  Widget build(BuildContext context) {
    final hasMyStudents = widget.myStudents.isNotEmpty;
    final hasOtherStudents = widget.otherStudents.isNotEmpty;

    // Показываем кнопку "Показать всех" если есть остальные и список не раскрыт
    final showExpandButton = hasOtherStudents && !_showAllStudents;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
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
          // Заголовок
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Выберите ученика',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Divider(height: 1),
          // Список учеников
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Если нет своих учеников — показываем сообщение
                if (!hasMyStudents && !_showAllStudents)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Text(
                      'У вас нет своих учеников',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Свои ученики (если есть)
                if (hasMyStudents)
                  ...widget.myStudents.map((student) => _buildStudentTile(student, false)),
                // Кнопка "Показать всех" (если есть остальные ученики и список не раскрыт)
                if (showExpandButton)
                  InkWell(
                    onTap: () => setState(() => _showAllStudents = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.expand_more,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Показать всех (${widget.otherStudents.length})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Остальные ученики (если раскрыто)
                if (_showAllStudents && widget.otherStudents.isNotEmpty) ...[
                  // Разделитель с текстом (только если есть свои ученики)
                  if (hasMyStudents)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Остальные ученики',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                        ],
                      ),
                    ),
                  // Остальные ученики
                  ...widget.otherStudents.map((student) => _buildStudentTile(student, true)),
                  // Кнопка "Скрыть"
                  InkWell(
                    onTap: () => setState(() => _showAllStudents = false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.expand_less,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Скрыть',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(Student student, bool isOther) {
    final isSelected = widget.currentStudent?.id == student.id;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person,
          size: 20,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        student.name,
        style: TextStyle(
          color: isOther
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        widget.onStudentSelected(student);
        Navigator.of(context).pop();
      },
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
  final bool showAllRoomsOverride;
  final ValueChanged<ScheduleFilters> onApply;
  final ValueChanged<bool> onShowAllRoomsChanged;

  const _FilterSheet({
    required this.institutionId,
    required this.currentFilters,
    required this.showAllRoomsOverride,
    required this.onApply,
    required this.onShowAllRoomsChanged,
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
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final membershipAsync = ref.watch(myMembershipProvider(widget.institutionId));

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
                  // Кабинеты по умолчанию (настройка, не временный фильтр)
                  _buildRoomsSection(roomsAsync, membershipAsync),
                  const SizedBox(height: 16),

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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Нет учеников', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

  Widget _buildRoomsSection(
    AsyncValue<List<Room>> roomsAsync,
    AsyncValue<InstitutionMember?> membershipAsync,
  ) {
    final membership = membershipAsync.valueOrNull;
    final rooms = roomsAsync.valueOrNull;

    if (rooms == null || rooms.isEmpty) {
      return const SizedBox.shrink();
    }

    // Получаем текущие настройки кабинетов
    final defaultRoomIds = membership?.defaultRoomIds;
    final hasSelection = defaultRoomIds != null && defaultRoomIds.isNotEmpty;

    String subtitle;
    if (widget.showAllRoomsOverride) {
      subtitle = 'Временно показаны все';
    } else if (defaultRoomIds == null) {
      subtitle = 'Не настроено';
    } else if (defaultRoomIds.isEmpty) {
      subtitle = 'Все кабинеты';
    } else {
      // Показываем названия выбранных кабинетов
      final selectedNames = rooms
          .where((r) => defaultRoomIds.contains(r.id))
          .map((r) => r.name)
          .take(3)
          .toList();
      subtitle = selectedNames.join(', ');
      if (defaultRoomIds.length > 3) {
        subtitle += ' +${defaultRoomIds.length - 3}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.showAllRoomsOverride
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.meeting_room_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Кабинеты по умолчанию'),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: widget.showAllRoomsOverride || hasSelection
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              // Показываем диалог настройки кабинетов
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => _RoomSetupSheet(
                  institutionId: widget.institutionId,
                  rooms: rooms,
                  isFirstTime: false,
                  onSaved: () {},
                ),
              );
            },
          ),
          // Кнопка "Показать все" / "Вернуть фильтр" если есть выбранные кабинеты
          if (hasSelection)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: widget.showAllRoomsOverride
                    ? FilledButton.icon(
                        onPressed: () {
                          widget.onShowAllRoomsChanged(false);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.filter_alt, size: 18),
                        label: const Text('Вернуть фильтр кабинетов'),
                      )
                    : OutlinedButton.icon(
                        onPressed: () {
                          widget.onShowAllRoomsChanged(true);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Показать все кабинеты'),
                      ),
              ),
            ),
        ],
      ),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Нет данных', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
  /// Предзаполненный час окончания (из постоянного слота)
  final int? preselectedEndHour;
  /// Предзаполненные минуты окончания (из постоянного слота)
  final int? preselectedEndMinute;
  /// Предзаполненный ученик (из постоянного слота)
  final Student? preselectedStudent;
  /// Предзаполненный предмет (из постоянного слота)
  final Subject? preselectedSubject;
  /// Предзаполненный тип занятия (из постоянного слота)
  final LessonType? preselectedLessonType;

  const _QuickAddLessonSheet({
    required this.rooms,
    required this.initialDate,
    required this.institutionId,
    required this.onCreated,
    this.preselectedRoom,
    this.preselectedStartHour,
    this.preselectedStartMinute,
    this.preselectedEndHour,
    this.preselectedEndMinute,
    this.preselectedStudent,
    this.preselectedSubject,
    this.preselectedLessonType,
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

  // Для групповых занятий
  bool _isGroupLesson = false;
  StudentGroup? _selectedGroup;

  // Для режима бронирования
  Set<String> _selectedRoomIds = {};
  final TextEditingController _descriptionController = TextEditingController();
  bool _isWeeklyBooking = false; // Еженедельное повторение

  // Для еженедельного бронирования (постоянное расписание)
  final Set<int> _scheduleDays = {}; // Выбранные дни недели (1-7)
  final Map<int, TimeOfDay> _scheduleStartTimes = {};
  final Map<int, TimeOfDay> _scheduleEndTimes = {};
  final Set<int> _scheduleConflictingDays = {};
  bool _isCheckingScheduleConflicts = false;

  // Для повторяющихся занятий
  RepeatType _repeatType = RepeatType.none;
  int _repeatCount = 4;
  // Map: dayOfWeek (1-7) -> (startTime, endTime)
  final Map<int, (TimeOfDay, TimeOfDay)> _weekdayTimes = {};
  List<DateTime> _customDates = [];
  List<DateTime> _previewDates = [];
  List<DateTime> _conflictDates = [];
  bool _isCheckingConflicts = false;

  // Для двухэтапного закрытия шторки
  final _sheetController = DraggableScrollableController();
  bool _wasScrolled = false;
  bool _readyToClose = false;
  Timer? _closeResetTimer;

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
      final startMinute = widget.preselectedStartMinute ?? 0;
      _startTime = TimeOfDay(hour: widget.preselectedStartHour!, minute: startMinute);

      // Время окончания: из параметра или +1 час
      if (widget.preselectedEndHour != null) {
        final endMinute = widget.preselectedEndMinute ?? 0;
        _endTime = TimeOfDay(hour: widget.preselectedEndHour!, minute: endMinute);
      } else {
        _endTime = TimeOfDay(hour: widget.preselectedStartHour! + 1, minute: startMinute);
      }
    } else {
      final now = TimeOfDay.now();
      // Округляем до ближайшего часа
      _startTime = TimeOfDay(hour: now.hour, minute: 0);
      _endTime = TimeOfDay(hour: now.hour + 1, minute: 0);
    }

    // Предзаполненный ученик из слота
    _selectedStudent = widget.preselectedStudent;

    // Предзаполненный предмет из слота
    _selectedSubject = widget.preselectedSubject;

    // Предзаполненный тип занятия из слота
    _selectedLessonType = widget.preselectedLessonType;

    // Слушатель для двухэтапного закрытия
    _sheetController.addListener(_onSheetSizeChanged);
  }

  void _onSheetSizeChanged() {
    // Если шторка начала опускаться ниже 88% — сразу snap обратно
    // Это предотвращает видимое "дёргание" шторки вниз
    if (_sheetController.size < 0.88 && _sheetController.size > 0.35) {
      if (_wasScrolled && !_readyToClose) {
        // Скроллили контент + первый свайп → snap обратно мгновенно
        _sheetController.animateTo(
          0.9,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
        _readyToClose = true;
        _startCloseResetTimer();
      }
      // Если не скроллили ИЛИ уже readyToClose → позволяем закрыться естественно
    }
  }

  void _startCloseResetTimer() {
    _closeResetTimer?.cancel();
    _closeResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _readyToClose = false;
          _wasScrolled = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _closeResetTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final membersAsync = ref.watch(membersStreamProvider(widget.institutionId));
    final groupsAsync = ref.watch(groupsProvider(widget.institutionId));
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

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.9,
      minChildSize: 0.3,
      maxChildSize: 0.93,
      expand: false,
      snap: true,
      snapSizes: const [0.9],
      snapAnimationDuration: const Duration(milliseconds: 300),
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              // Если контент скроллится (не на нуле)
              if (notification.metrics.pixels > 10) {
                _wasScrolled = true;
              }
            }
            return false;
          },
          child: ListView(
            controller: scrollController,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Переключатель режима: Занятие / Бронирование
            SegmentedButton<_AddFormMode>(
              segments: const [
                ButtonSegment<_AddFormMode>(
                  value: _AddFormMode.lesson,
                  label: Text('Занятие'),
                  icon: Icon(Icons.school, size: 16),
                ),
                ButtonSegment<_AddFormMode>(
                  value: _AddFormMode.booking,
                  label: Text('Бронь'),
                  icon: Icon(Icons.lock_clock, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<_AddFormMode> newSelection) {
                setState(() {
                  _mode = newSelection.first;
                  // Сбрасываем еженедельный режим при смене вкладки
                  if (_mode != _AddFormMode.booking) {
                    _isWeeklyBooking = false;
                  }
                });
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
                                initialValue: _selectedRoom,
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
              InkWell(
                onTap: () async {
                  final range = await showIosTimeRangePicker(
                    context: context,
                    initialStartTime: _startTime,
                    initialEndTime: _endTime,
                    minuteInterval: 5,
                  );
                  if (range != null) {
                    setState(() {
                      _startTime = range.start;
                      _endTime = range.end;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Время *',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  child: Text('${_formatTime(_startTime)} – ${_formatTime(_endTime)}'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ========== РЕЖИМ БРОНИРОВАНИЯ ==========
            if (_mode == _AddFormMode.booking) ...[
              // Переключатель "Еженедельно"
              SwitchListTile(
                title: const Text('Повторять еженедельно'),
                subtitle: Text(
                  _isWeeklyBooking
                      ? 'Постоянное расписание с привязкой к ученику'
                      : 'Разовое бронирование кабинета',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _isWeeklyBooking,
                onChanged: (value) {
                  setState(() {
                    _isWeeklyBooking = value;
                    // Сбрасываем данные при переключении
                    if (value) {
                      _selectedRoomIds.clear();
                      _descriptionController.clear();
                    } else {
                      _scheduleDays.clear();
                      _scheduleStartTimes.clear();
                      _scheduleEndTimes.clear();
                      _scheduleConflictingDays.clear();
                      _selectedStudent = null;
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // ----- РАЗОВАЯ БРОНЬ (не еженедельно) -----
              if (!_isWeeklyBooking) ...[
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
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Выберите хотя бы один кабинет',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

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
                InkWell(
                  onTap: () async {
                    final range = await showIosTimeRangePicker(
                      context: context,
                      initialStartTime: _startTime,
                      initialEndTime: _endTime,
                      minuteInterval: 5,
                    );
                    if (range != null) {
                      setState(() {
                        _startTime = range.start;
                        _endTime = range.end;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Время *',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text('${_formatTime(_startTime)} – ${_formatTime(_endTime)}'),
                  ),
                ),
                const SizedBox(height: 16),

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

                // Кнопка создания разовой брони
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
              ],

              // ----- ЕЖЕНЕДЕЛЬНАЯ БРОНЬ (постоянное расписание) -----
              if (_isWeeklyBooking) ...[
                // Кабинет (один)
                Builder(
                  builder: (context) {
                    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
                    final rooms = roomsAsync.valueOrNull ?? widget.rooms;

                    if (_selectedRoom != null && !rooms.any((r) => r.id == _selectedRoom!.id)) {
                      _selectedRoom = rooms.isNotEmpty ? rooms.first : null;
                    }

                    return rooms.isEmpty
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
                              _checkScheduleConflicts();
                            },
                          );
                  },
                ),
                const SizedBox(height: 16),

                // Дни недели
                Text(
                  'Дни недели *',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in [
                      (1, 'Пн'),
                      (2, 'Вт'),
                      (3, 'Ср'),
                      (4, 'Чт'),
                      (5, 'Пт'),
                      (6, 'Сб'),
                      (7, 'Вс')
                    ])
                      FilterChip(
                        label: Text(day.$2),
                        selected: _scheduleDays.contains(day.$1),
                        avatar: _scheduleConflictingDays.contains(day.$1)
                            ? Icon(Icons.warning_amber, size: 16, color: Theme.of(context).colorScheme.error)
                            : null,
                        backgroundColor: _scheduleConflictingDays.contains(day.$1)
                            ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
                            : null,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _scheduleDays.add(day.$1);
                              _scheduleStartTimes[day.$1] = _startTime;
                              _scheduleEndTimes[day.$1] = _endTime;
                            } else {
                              _scheduleDays.remove(day.$1);
                              _scheduleStartTimes.remove(day.$1);
                              _scheduleEndTimes.remove(day.$1);
                              _scheduleConflictingDays.remove(day.$1);
                            }
                          });
                          _checkScheduleConflicts();
                        },
                      ),
                  ],
                ),
                if (_scheduleDays.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Выберите хотя бы один день',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Время для выбранных дней
                if (_scheduleDays.isNotEmpty) ...[
                  Text(
                    'Время занятий',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ..._buildScheduleDayTimeRows(),
                  const SizedBox(height: 16),
                ],

                // Ученик
                Builder(builder: (context) {
                  final myStudentIdsAsync = ref.watch(myStudentIdsProvider(widget.institutionId));

                  return studentsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => ErrorView.inline(e),
                    data: (allStudents) {
                      final myStudentIds = myStudentIdsAsync.valueOrNull ?? <String>{};
                      final myStudents = allStudents.where((s) => myStudentIds.contains(s.id)).toList();
                      final otherStudents = allStudents.where((s) => !myStudentIds.contains(s.id)).toList();
                      final currentStudent = _selectedStudent != null
                          ? allStudents.where((s) => s.id == _selectedStudent!.id).firstOrNull
                          : null;

                      return allStudents.isEmpty
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
                          : InkWell(
                              onTap: () => _showStudentPickerSheet(
                                context: context,
                                myStudents: myStudents,
                                otherStudents: otherStudents,
                                allStudents: allStudents,
                                currentStudent: currentStudent,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Ученик *',
                                  prefixIcon: const Icon(Icons.person),
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  currentStudent?.name ?? 'Выберите ученика',
                                  style: currentStudent != null
                                      ? null
                                      : TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                            );
                    },
                  );
                }),
                const SizedBox(height: 16),

                // Преподаватель
                membersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (members) {
                    final activeMembers = members.where((m) => !m.isArchived).toList();
                    if (activeMembers.length <= 1) return const SizedBox.shrink();

                    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
                    _selectedTeacher ??= activeMembers.where((m) => m.userId == currentUserId).firstOrNull;

                    final currentTeacher = _selectedTeacher != null
                        ? activeMembers.where((m) => m.userId == _selectedTeacher!.userId).firstOrNull
                        : null;

                    return DropdownButtonFormField<InstitutionMember?>(
                      decoration: const InputDecoration(
                        labelText: 'Преподаватель *',
                        prefixIcon: Icon(Icons.school),
                      ),
                      value: currentTeacher,
                      items: activeMembers.map((m) => DropdownMenuItem<InstitutionMember?>(
                        value: m,
                        child: Text(m.profile?.fullName ?? 'Без имени'),
                      )).toList(),
                      onChanged: (member) {
                        setState(() => _selectedTeacher = member);
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
                    final effectiveSubject = _selectedSubject != null
                        ? subjects.where((s) => s.id == _selectedSubject!.id).firstOrNull
                        : null;
                    return DropdownButtonFormField<Subject?>(
                      decoration: const InputDecoration(
                        labelText: 'Предмет',
                        prefixIcon: Icon(Icons.music_note),
                      ),
                      value: effectiveSubject,
                      items: [
                        const DropdownMenuItem<Subject?>(value: null, child: Text('Не выбран')),
                        ...subjects.map((s) => DropdownMenuItem<Subject?>(
                          value: s,
                          child: Text(s.name),
                        )),
                      ],
                      onChanged: (subject) {
                        setState(() => _selectedSubject = subject);
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
                    final effectiveLessonType = _selectedLessonType != null
                        ? lessonTypes.where((lt) => lt.id == _selectedLessonType!.id).firstOrNull
                        : null;
                    return DropdownButtonFormField<LessonType?>(
                      decoration: const InputDecoration(
                        labelText: 'Тип занятия',
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: effectiveLessonType,
                      items: [
                        const DropdownMenuItem<LessonType?>(value: null, child: Text('Не выбран')),
                        ...lessonTypes.map((lt) => DropdownMenuItem<LessonType?>(
                          value: lt,
                          child: Text('${lt.name} (${lt.defaultDurationMinutes} мин)'),
                        )),
                      ],
                      onChanged: (lessonType) {
                        setState(() {
                          _selectedLessonType = lessonType;
                          if (lessonType != null) {
                            // Обновляем длительность для всех выбранных дней
                            for (final day in _scheduleDays) {
                              final start = _scheduleStartTimes[day] ?? _startTime;
                              final startMinutes = start.hour * 60 + start.minute;
                              final endMinutes = startMinutes + lessonType.defaultDurationMinutes;
                              _scheduleEndTimes[day] = TimeOfDay(
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
                const SizedBox(height: 16),

                // Статус проверки конфликтов
                if (_isCheckingScheduleConflicts)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Проверка конфликтов...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  )
                else if (_scheduleConflictingDays.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Конфликты: ${_scheduleConflictingDays.length} дн. (измените время)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Кнопка создания еженедельного слота
                ElevatedButton.icon(
                  onPressed: _scheduleDays.isEmpty ||
                          _isCheckingScheduleConflicts ||
                          _scheduleConflictingDays.isNotEmpty ||
                          _selectedStudent == null ||
                          _selectedRoom == null
                      ? null
                      : _createSchedule,
                  icon: _isCheckingScheduleConflicts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.repeat),
                  label: Text(
                    _isCheckingScheduleConflicts
                        ? 'Проверка...'
                        : _scheduleConflictingDays.isNotEmpty
                            ? 'Есть конфликты'
                            : _scheduleDays.length > 1
                                ? 'Создать ${_scheduleDays.length} слотов'
                                : 'Создать слот',
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],

            // ========== Продолжение РЕЖИМА ЗАНЯТИЯ ==========
            if (_mode == _AddFormMode.lesson) ...[
              // Переключатель Ученик/Группа
              Builder(builder: (context) {
                final groups = groupsAsync.valueOrNull ?? [];
                // Показываем переключатель только если есть группы
                if (groups.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Ученик'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Группа'),
                          icon: Icon(Icons.groups),
                        ),
                      ],
                      selected: {_isGroupLesson},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _isGroupLesson = selected.first;
                          // Сбрасываем выбор при переключении
                          if (_isGroupLesson) {
                            _selectedStudent = null;
                          } else {
                            _selectedGroup = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),

              // Выбор ученика (индивидуальное занятие)
              if (!_isGroupLesson)
                Builder(builder: (context) {
                  // Используем myStudentIdsProvider для консистентности с экраном учеников
                  final myStudentIdsAsync = ref.watch(myStudentIdsProvider(widget.institutionId));

                  return studentsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => ErrorView.inline(e),
                    data: (allStudents) {
                      final myStudentIds = myStudentIdsAsync.valueOrNull ?? <String>{};

                      // Разделяем на своих и остальных
                      final myStudents = allStudents.where((s) => myStudentIds.contains(s.id)).toList();
                      final otherStudents = allStudents.where((s) => !myStudentIds.contains(s.id)).toList();

                      // Находим выбранного студента по ID в текущем списке
                      final currentStudent = _selectedStudent != null
                          ? allStudents.where((s) => s.id == _selectedStudent!.id).firstOrNull
                          : null;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: allStudents.isEmpty
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
                                : InkWell(
                                    onTap: () => _showStudentPickerSheet(
                                      context: context,
                                      myStudents: myStudents,
                                      otherStudents: otherStudents,
                                      allStudents: allStudents,
                                      currentStudent: currentStudent,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Ученик *',
                                        prefixIcon: const Icon(Icons.person),
                                        suffixIcon: const Icon(Icons.arrow_drop_down),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        currentStudent?.name ?? 'Выберите ученика',
                                        style: currentStudent != null
                                            ? null
                                            : TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                    ),
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
                  );
                }),

              // Выбор группы (групповое занятие)
              if (_isGroupLesson)
                groupsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => ErrorView.inline(e),
                  data: (groups) {
                    final currentGroup = _selectedGroup != null
                        ? groups.where((g) => g.id == _selectedGroup!.id).firstOrNull
                        : null;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: groups.isEmpty
                              ? InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Группа *',
                                    prefixIcon: Icon(Icons.groups),
                                  ),
                                  child: Text(
                                    'Нет групп',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                )
                              : DropdownButtonFormField<StudentGroup?>(
                                  decoration: const InputDecoration(
                                    labelText: 'Группа *',
                                    prefixIcon: Icon(Icons.groups),
                                  ),
                                  initialValue: currentGroup,
                                  items: groups.map((g) => DropdownMenuItem<StudentGroup?>(
                                    value: g,
                                    child: Text('${g.name} (${g.membersCount} уч.)'),
                                  )).toList(),
                                  onChanged: (group) {
                                    setState(() => _selectedGroup = group);
                                  },
                                ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: IconButton.filled(
                            onPressed: () => _showCreateGroupDialog(),
                            icon: const Icon(Icons.add, size: 20),
                            tooltip: 'Создать группу',
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

                // Находим текущего преподавателя в списке по userId (объекты могут пересоздаваться)
                final currentTeacher = _selectedTeacher != null
                    ? activeMembers.where((m) => m.userId == _selectedTeacher!.userId).firstOrNull
                    : null;

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
                  initialValue: currentTeacher,
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
                // Находим предзаполненный subject в списке по ID
                final effectiveSubject = _selectedSubject != null
                    ? subjects.where((s) => s.id == _selectedSubject!.id).firstOrNull
                    : null;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Subject?>(
                        decoration: const InputDecoration(
                          labelText: 'Предмет',
                          prefixIcon: Icon(Icons.music_note),
                        ),
                        initialValue: effectiveSubject,
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
                // Находим предзаполненный lessonType в списке по ID
                final effectiveLessonType = _selectedLessonType != null
                    ? lessonTypes.where((lt) => lt.id == _selectedLessonType!.id).firstOrNull
                    : null;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<LessonType?>(
                        decoration: const InputDecoration(
                          labelText: 'Тип занятия',
                          prefixIcon: Icon(Icons.category),
                        ),
                        initialValue: effectiveLessonType,
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
              const SizedBox(height: 16),

              // Повторяющиеся занятия
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown выбора типа повтора
                      DropdownButtonFormField<RepeatType>(
                        key: ValueKey('repeat_$_repeatType'),
                        decoration: InputDecoration(
                          labelText: 'Повтор',
                          prefixIcon: const Icon(Icons.repeat),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        initialValue: _repeatType,
                        items: RepeatType.values
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ))
                            .toList(),
                        onChanged: (type) {
                          setState(() {
                            _repeatType = type ?? RepeatType.none;
                            _previewDates = [];
                            _conflictDates = [];
                          });
                          if (type != RepeatType.none && _selectedRoom != null) {
                            _updatePreview();
                          }
                        },
                      ),

                      // Количество занятий (для daily, weekly, weekdays)
                      if (_repeatType != RepeatType.none &&
                          _repeatType != RepeatType.custom) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Количество занятий:',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$_repeatCount',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Слайдер для выбора количества
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            showValueIndicator: ShowValueIndicator.onlyForContinuous,
                          ),
                          child: Slider(
                            value: _repeatCount.toDouble(),
                            min: 2,
                            max: 52,
                            divisions: 50,
                            label: '$_repeatCount',
                            onChanged: (value) {
                              setState(() => _repeatCount = value.round());
                              _updatePreview();
                            },
                          ),
                        ),
                        // Быстрые кнопки
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final count in [4, 8, 12, 24])
                              ActionChip(
                                label: Text('$count'),
                                backgroundColor: _repeatCount == count
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                                onPressed: () {
                                  setState(() => _repeatCount = count);
                                  _updatePreview();
                                },
                              ),
                          ],
                        ),
                      ],

                      // Выбор дней недели (для weekdays)
                      if (_repeatType == RepeatType.weekdays) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final day in [
                              (1, 'Пн'),
                              (2, 'Вт'),
                              (3, 'Ср'),
                              (4, 'Чт'),
                              (5, 'Пт'),
                              (6, 'Сб'),
                              (7, 'Вс')
                            ])
                              FilterChip(
                                label: Text(day.$2),
                                selected: _weekdayTimes.containsKey(day.$1),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      // Добавляем с текущим временем
                                      _weekdayTimes[day.$1] = (_startTime, _endTime);
                                    } else {
                                      _weekdayTimes.remove(day.$1);
                                    }
                                  });
                                  if (_weekdayTimes.isNotEmpty) {
                                    _updatePreview();
                                  }
                                },
                              ),
                          ],
                        ),
                        // Время занятий для выбранных дней
                        if (_weekdayTimes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Время занятий',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          ..._buildWeekdayTimeRows(),
                        ],
                      ],

                      // Кнопка выбора дат (custom)
                      if (_repeatType == RepeatType.custom) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showMultiDatePicker,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(_customDates.isEmpty
                              ? 'Выбрать даты в календаре'
                              : 'Выбрано: ${_customDates.length} дат'),
                        ),
                      ],

                      // Превью дат
                      if (_previewDates.length > 1) ...[
                        const SizedBox(height: 12),
                        if (_isCheckingConflicts)
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Проверка конфликтов...',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          )
                        else ...[
                          Text(
                            'Будет создано ${_previewDates.length} занятий',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          if (_conflictDates.isNotEmpty)
                            Text(
                              'Конфликты: ${_conflictDates.length} (будут пропущены)',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка создания
              ElevatedButton.icon(
                onPressed: controllerState.isLoading ||
                        _isCheckingConflicts ||
                        (_isGroupLesson ? _selectedGroup == null : _selectedStudent == null) ||
                        _selectedRoom == null
                    ? null
                    : _createLesson,
                icon: _isCheckingConflicts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isCheckingConflicts
                    ? 'Проверка конфликтов...'
                    : _repeatType != RepeatType.none
                        ? 'Создать ${_previewDates.length > 1 ? _previewDates.length : _repeatCount} занятий'
                        : 'Создать занятие'),
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

  /// Строит строки времени для постоянного расписания (каждый день)
  List<Widget> _buildScheduleDayTimeRows() {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final sortedDays = _scheduleDays.toList()..sort();

    return sortedDays.map((dayNumber) {
      final startTime = _scheduleStartTimes[dayNumber] ?? _startTime;
      final endTime = _scheduleEndTimes[dayNumber] ?? _endTime;
      final hasConflict = _scheduleConflictingDays.contains(dayNumber);

      // Расчёт длительности
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;
      final durationMinutes = endMinutes - startMinutes;
      final durationText = durationMinutes > 0
          ? (durationMinutes >= 60
              ? '${durationMinutes ~/ 60} ч${durationMinutes % 60 > 0 ? ' ${durationMinutes % 60} мин' : ''}'
              : '$durationMinutes мин')
          : 'Некорректно';

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: hasConflict
            ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickScheduleDayTimeRange(dayNumber),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Day label
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasConflict
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      days[dayNumber],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: hasConflict
                                ? Theme.of(context).colorScheme.onErrorContainer
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Time range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatTimeOfDay(startTime)} — ${_formatTimeOfDay(endTime)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasConflict ? 'Конфликт! Время занято' : durationText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: hasConflict
                                  ? Theme.of(context).colorScheme.error
                                  : (durationMinutes > 0
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error),
                            ),
                      ),
                    ],
                  ),
                ),

                // Conflict or Edit icon
                Icon(
                  hasConflict ? Icons.warning_amber_rounded : Icons.edit_outlined,
                  color: hasConflict
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Выбор времени для конкретного дня недели в постоянном расписании
  Future<void> _pickScheduleDayTimeRange(int dayNumber) async {
    final currentStart = _scheduleStartTimes[dayNumber] ?? _startTime;
    final currentEnd = _scheduleEndTimes[dayNumber] ?? _endTime;

    final result = await showIosTimeRangePicker(
      context: context,
      initialStartTime: currentStart,
      initialEndTime: currentEnd,
      minuteInterval: 5,
      minHour: 6,
      maxHour: 23,
    );

    if (result != null && mounted) {
      setState(() {
        _scheduleStartTimes[dayNumber] = result.start;
        _scheduleEndTimes[dayNumber] = result.end;
      });
      _checkScheduleConflicts();
    }
  }

  /// Проверяет конфликты для постоянного расписания
  Future<void> _checkScheduleConflicts() async {
    if (_selectedRoom == null || _scheduleDays.isEmpty) {
      setState(() {
        _scheduleConflictingDays.clear();
        _isCheckingScheduleConflicts = false;
      });
      return;
    }

    setState(() => _isCheckingScheduleConflicts = true);

    final repo = ref.read(bookingRepositoryProvider);
    final newConflicts = <int>{};

    for (final day in _scheduleDays) {
      final startTime = _scheduleStartTimes[day] ?? _startTime;
      final endTime = _scheduleEndTimes[day] ?? _endTime;

      // 1. Проверяем конфликт с другими еженедельными бронированиями
      final hasScheduleConflict = await repo.hasWeeklyConflict(
        roomId: _selectedRoom!.id,
        dayOfWeek: day,
        startTime: startTime,
        endTime: endTime,
      );

      if (hasScheduleConflict) {
        newConflicts.add(day);
        continue;
      }

      // 2. Проверяем конфликт с ВСЕМИ будущими занятиями для этого дня недели
      final hasLessonConflict = await repo.hasLessonConflictForDayOfWeek(
        roomId: _selectedRoom!.id,
        dayOfWeek: day,
        startTime: startTime,
        endTime: endTime,
        studentId: _selectedStudent?.id,
      );

      if (hasLessonConflict) {
        newConflicts.add(day);
      }
    }

    if (mounted) {
      setState(() {
        _scheduleConflictingDays.clear();
        _scheduleConflictingDays.addAll(newConflicts);
        _isCheckingScheduleConflicts = false;
      });
    }
  }

  /// Создание постоянного расписания
  Future<void> _createSchedule() async {
    if (_scheduleDays.isEmpty || _selectedStudent == null || _selectedRoom == null) {
      return;
    }

    // Получаем teacherId - либо выбранный, либо текущий пользователь
    final teacherId = _selectedTeacher?.userId ??
        SupabaseConfig.client.auth.currentUser?.id;

    if (teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось определить преподавателя'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = ref.read(bookingControllerProvider.notifier);

    try {
      if (_scheduleDays.length == 1) {
        // Один слот
        final day = _scheduleDays.first;
        await controller.createRecurring(
          institutionId: widget.institutionId,
          studentId: _selectedStudent!.id,
          teacherId: teacherId,
          roomId: _selectedRoom!.id,
          subjectId: _selectedSubject?.id,
          lessonTypeId: _selectedLessonType?.id,
          dayOfWeek: day,
          startTime: _scheduleStartTimes[day] ?? _startTime,
          endTime: _scheduleEndTimes[day] ?? _endTime,
        );
      } else {
        // Несколько слотов (batch)
        final slots = _scheduleDays.map((day) => DayTimeSlot(
          dayOfWeek: day,
          startTime: _scheduleStartTimes[day] ?? _startTime,
          endTime: _scheduleEndTimes[day] ?? _endTime,
        )).toList();

        await controller.createRecurringBatch(
          institutionId: widget.institutionId,
          studentId: _selectedStudent!.id,
          teacherId: teacherId,
          roomId: _selectedRoom!.id,
          subjectId: _selectedSubject?.id,
          lessonTypeId: _selectedLessonType?.id,
          slots: slots,
        );
      }

      if (mounted) {
        widget.onCreated(_selectedDate);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _scheduleDays.length == 1
                  ? 'Постоянное расписание создано'
                  : 'Создано ${_scheduleDays.length} слотов расписания',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Строит строки времени для каждого выбранного дня недели
  List<Widget> _buildWeekdayTimeRows() {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final sortedDays = _weekdayTimes.keys.toList()..sort();

    return sortedDays.map((dayNumber) {
      final times = _weekdayTimes[dayNumber]!;
      final startTime = times.$1;
      final endTime = times.$2;

      // Расчёт длительности
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;
      final durationMinutes = endMinutes - startMinutes;
      final durationText = durationMinutes > 0
          ? (durationMinutes >= 60
              ? '${durationMinutes ~/ 60} ч${durationMinutes % 60 > 0 ? ' ${durationMinutes % 60} мин' : ''}'
              : '$durationMinutes мин')
          : 'Некорректно';

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickWeekdayTimeRange(dayNumber),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Day label
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      days[dayNumber],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Time range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatTimeOfDay(startTime)} — ${_formatTimeOfDay(endTime)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        durationText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: durationMinutes > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                ),

                // Edit icon
                Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Форматирование TimeOfDay
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Выбор времени для конкретного дня недели
  Future<void> _pickWeekdayTimeRange(int dayNumber) async {
    const days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final currentTimes = _weekdayTimes[dayNumber]!;

    final startPicked = await showTimePicker(
      context: context,
      initialTime: currentTimes.$1,
      helpText: '${days[dayNumber]}: Начало занятия',
    );

    if (startPicked == null || !mounted) return;

    final endPicked = await showTimePicker(
      context: context,
      initialTime: currentTimes.$2,
      helpText: '${days[dayNumber]}: Конец занятия',
    );

    if (endPicked == null || !mounted) return;

    setState(() {
      _weekdayTimes[dayNumber] = (startPicked, endPicked);
    });

    _updatePreview();
  }

  /// Генерирует список дат для повторяющихся занятий
  List<DateTime> _generateDates() {
    final dates = <DateTime>[_selectedDate];

    switch (_repeatType) {
      case RepeatType.none:
        return dates;

      case RepeatType.daily:
        for (int i = 1; i < _repeatCount; i++) {
          dates.add(_selectedDate.add(Duration(days: i)));
        }
        return dates;

      case RepeatType.weekly:
        for (int i = 1; i < _repeatCount; i++) {
          dates.add(_selectedDate.add(Duration(days: i * 7)));
        }
        return dates;

      case RepeatType.weekdays:
        if (_weekdayTimes.isEmpty) return dates;
        var currentDate = _selectedDate;
        int added = 1;
        while (added < _repeatCount) {
          currentDate = currentDate.add(const Duration(days: 1));
          if (_weekdayTimes.containsKey(currentDate.weekday)) {
            dates.add(currentDate);
            added++;
          }
          // Защита от бесконечного цикла
          if (currentDate.difference(_selectedDate).inDays > 365) break;
        }
        return dates;

      case RepeatType.custom:
        return [_selectedDate, ..._customDates];
    }
  }

  /// Обновляет превью дат и проверяет конфликты
  Future<void> _updatePreview() async {
    if (_selectedRoom == null) return;

    final dates = _generateDates();
    setState(() {
      _previewDates = dates;
      _isCheckingConflicts = true;
    });

    final controller = ref.read(lessonControllerProvider.notifier);

    // Для режима weekdays — проверяем конфликты с учётом времени каждого дня
    if (_repeatType == RepeatType.weekdays && _weekdayTimes.isNotEmpty) {
      final conflicts = <DateTime>[];
      for (final date in dates) {
        final dayTimes = _weekdayTimes[date.weekday];
        if (dayTimes != null) {
          final dayConflicts = await controller.checkConflictsForDates(
            roomId: _selectedRoom!.id,
            dates: [date],
            startTime: dayTimes.$1,
            endTime: dayTimes.$2,
          );
          conflicts.addAll(dayConflicts);
        }
      }
      if (mounted) {
        setState(() {
          _conflictDates = conflicts;
          _isCheckingConflicts = false;
        });
      }
    } else {
      final conflicts = await controller.checkConflictsForDates(
        roomId: _selectedRoom!.id,
        dates: dates,
        startTime: _startTime,
        endTime: _endTime,
      );

      if (mounted) {
        setState(() {
          _conflictDates = conflicts;
          _isCheckingConflicts = false;
        });
      }
    }
  }

  /// Показывает диалог выбора нескольких дат
  Future<void> _showMultiDatePicker() async {
    final result = await showDialog<Set<DateTime>>(
      context: context,
      builder: (context) => _MultiDatePickerDialog(
        selectedDates: _customDates.toSet(),
        firstDate: _selectedDate,
        lastDate: _selectedDate.add(const Duration(days: 365)),
      ),
    );

    if (result != null) {
      setState(() {
        _customDates = result.toList()..sort();
      });
      _updatePreview();
    }
  }

  Future<void> _createLesson() async {
    if (_selectedRoom == null) return;

    // Валидация: для индивидуального нужен ученик, для группового — группа
    if (_isGroupLesson && _selectedGroup == null) return;
    if (!_isGroupLesson && _selectedStudent == null) return;

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

    // Если включён повтор — создаём серию занятий
    if (_repeatType != RepeatType.none) {
      // Генерируем список дат и фильтруем конфликтные
      final allDates = _generateDates();
      final validDates = allDates
          .where((d) => !_conflictDates.any((c) =>
              c.year == d.year && c.month == d.month && c.day == d.day))
          .toList();

      if (validDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все даты заняты'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      int totalCreated = 0;

      // Для режима weekdays — группируем по дням недели и создаём с соответствующим временем
      if (_repeatType == RepeatType.weekdays && _weekdayTimes.isNotEmpty) {
        // Генерируем ОДИН общий repeatGroupId для всех дней недели
        // Это позволяет правильно считать количество занятий серии
        final sharedRepeatGroupId = const Uuid().v4();

        // Группируем даты по дню недели
        final datesByWeekday = <int, List<DateTime>>{};
        for (final date in validDates) {
          datesByWeekday.putIfAbsent(date.weekday, () => []).add(date);
        }

        // Создаём занятия для каждого дня недели с его временем
        for (final entry in datesByWeekday.entries) {
          final weekday = entry.key;
          final dates = entry.value;
          final times = _weekdayTimes[weekday];

          if (times != null && dates.isNotEmpty) {
            final lessons = await controller.createSeries(
              institutionId: widget.institutionId,
              roomId: _selectedRoom!.id,
              teacherId: teacherId,
              dates: dates,
              startTime: times.$1,
              endTime: times.$2,
              studentId: _isGroupLesson ? null : _selectedStudent!.id,
              groupId: _isGroupLesson ? _selectedGroup!.id : null,
              subjectId: _selectedSubject?.id,
              lessonTypeId: _selectedLessonType?.id,
              repeatGroupId: sharedRepeatGroupId, // Общий ID для всей серии
            );
            totalCreated += lessons?.length ?? 0;
          }
        }
      } else {
        // Для остальных режимов — используем единое время
        final lessons = await controller.createSeries(
          institutionId: widget.institutionId,
          roomId: _selectedRoom!.id,
          teacherId: teacherId,
          dates: validDates,
          startTime: _startTime,
          endTime: _endTime,
          studentId: _isGroupLesson ? null : _selectedStudent!.id,
          groupId: _isGroupLesson ? _selectedGroup!.id : null,
          subjectId: _selectedSubject?.id,
          lessonTypeId: _selectedLessonType?.id,
        );
        totalCreated = lessons?.length ?? 0;
      }

      if (totalCreated > 0 && mounted) {
        // Автоматически создаём привязки только для индивидуальных занятий
        if (!_isGroupLesson) {
          _createBindings(teacherId);
        }

        widget.onCreated(_selectedDate);
        Navigator.pop(context);

        final skipped = allDates.length - validDates.length;
        final message = skipped > 0
            ? 'Создано $totalCreated занятий (пропущено: $skipped)'
            : 'Создано $totalCreated занятий';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Создаём одно занятие
      final lesson = await controller.create(
        institutionId: widget.institutionId,
        roomId: _selectedRoom!.id,
        teacherId: teacherId,
        date: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        studentId: _isGroupLesson ? null : _selectedStudent!.id,
        groupId: _isGroupLesson ? _selectedGroup!.id : null,
        subjectId: _selectedSubject?.id,
        lessonTypeId: _selectedLessonType?.id,
      );

      if (lesson != null && mounted) {
        // Автоматически создаём привязки только для индивидуальных занятий
        if (!_isGroupLesson) {
          _createBindings(teacherId);
        }

        widget.onCreated(_selectedDate);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isGroupLesson ? 'Групповое занятие создано' : 'Занятие создано'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  void _showStudentPickerSheet({
    required BuildContext context,
    required List<Student> myStudents,
    required List<Student> otherStudents,
    required List<Student> allStudents,
    required Student? currentStudent,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _StudentPickerSheet(
        myStudents: myStudents,
        otherStudents: otherStudents,
        currentStudent: currentStudent,
        onStudentSelected: (student) {
          setState(() {
            _selectedStudent = student;
            // Автозаполнение количества повторов из баланса ученика
            if (_repeatType != RepeatType.none && student.balance > 0) {
              // Устанавливаем количество в пределах 2-52
              _repeatCount = student.balance.clamp(2, 52);
            }
          });
          // Автозаполнение типа занятия из привязок ученика
          _autoFillLessonTypeFromStudent(student.id);
          // Обновляем превью если включён повтор
          if (_repeatType != RepeatType.none) {
            _updatePreview();
          }
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

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая группа'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Название группы',
              hintText: 'Например: Группа вокала',
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите название';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final controller = ref.read(groupControllerProvider.notifier);
              final group = await controller.create(
                institutionId: widget.institutionId,
                name: nameController.text.trim(),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (group != null) {
                ref.invalidate(groupsProvider(widget.institutionId));
                ref.read(groupsProvider(widget.institutionId).future).then((groups) {
                  final newGroup = groups.where((g) => g.id == group.id).firstOrNull;
                  if (mounted) {
                    setState(() => _selectedGroup = newGroup);
                  }
                });
              }
            },
            child: const Text('Создать'),
          ),
        ],
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    Icon(Icons.access_time, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
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
                    Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
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
      widget.booking.date!, // Для разовых бронирований date всегда есть
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
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
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

/// BottomSheet для деталей постоянного слота
class _ScheduleSlotDetailSheet extends ConsumerStatefulWidget {
  final Booking slot;
  final DateTime selectedDate;
  final String institutionId;
  final VoidCallback onUpdated;
  final VoidCallback onCreateLesson;

  const _ScheduleSlotDetailSheet({
    required this.slot,
    required this.selectedDate,
    required this.institutionId,
    required this.onUpdated,
    required this.onCreateLesson,
  });

  @override
  ConsumerState<_ScheduleSlotDetailSheet> createState() => _ScheduleSlotDetailSheetState();
}

class _ScheduleSlotDetailSheetState extends ConsumerState<_ScheduleSlotDetailSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(Icons.repeat, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Постоянное расписание',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${slot.dayNameFull}, ${slot.timeRange}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Информация
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ученик
                  _buildInfoRow(
                    Icons.person,
                    'Ученик',
                    slot.student?.name ?? 'Не указан',
                  ),
                  const SizedBox(height: 12),

                  // Преподаватель
                  _buildInfoRow(
                    Icons.school,
                    'Преподаватель',
                    slot.teacher?.fullName ?? 'Не указан',
                  ),
                  const SizedBox(height: 12),

                  // Кабинет
                  _buildInfoRow(
                    Icons.meeting_room,
                    'Кабинет',
                    slot.getEffectiveRoom(widget.selectedDate)?.name ?? 'Не указан',
                  ),

                  // Если есть замена кабинета
                  if (slot.hasReplacement && slot.replacementRoom != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, color: AppColors.warning, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Временно в кабинете ${slot.replacementRoom!.name} до ${_formatDate(slot.replacementUntil!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Предмет (если есть)
                  if (slot.subject != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.book,
                      'Предмет',
                      slot.subject!.name,
                    ),
                  ],

                  // Тип занятия (если есть)
                  if (slot.lessonType != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.category,
                      'Тип занятия',
                      slot.lessonType!.name,
                    ),
                  ],
                ],
              ),
            ),

            const Divider(),

            // Действия
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Создать занятие на эту дату
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text('Создать занятие на $_formatDateShort'),
                    onTap: _isLoading ? null : widget.onCreateLesson,
                  ),

                  // Добавить исключение
                  ListTile(
                    leading: const Icon(Icons.event_busy),
                    title: const Text('Добавить исключение'),
                    subtitle: const Text('Слот не будет действовать в выбранную дату'),
                    onTap: _isLoading ? null : _addException,
                  ),

                  // Приостановить
                  if (!slot.isPaused)
                    ListTile(
                      leading: const Icon(Icons.pause_circle_outline),
                      title: const Text('Приостановить'),
                      subtitle: const Text('Временно деактивировать слот'),
                      onTap: _isLoading ? null : _pauseSlot,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline, color: AppColors.success),
                      title: const Text('Возобновить'),
                      subtitle: Text(
                        slot.pauseUntil != null
                            ? 'Приостановлено до ${_formatDate(slot.pauseUntil!)}'
                            : 'Бессрочная пауза',
                      ),
                      onTap: _isLoading ? null : _resumeSlot,
                    ),

                  // Деактивировать
                  ListTile(
                    leading: const Icon(Icons.archive_outlined, color: AppColors.error),
                    title: const Text('Деактивировать', style: TextStyle(color: AppColors.error)),
                    subtitle: const Text('Полностью отключить слот'),
                    onTap: _isLoading ? null : _deactivateSlot,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _formatDateShort {
    final d = widget.selectedDate;
    return '${d.day}.${d.month.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _addException() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить исключение'),
        content: Text(
          'Слот не будет действовать ${_formatDate(widget.selectedDate)}.\n\n'
          'Это позволит создать другое занятие в это время.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      await controller.addException(
        bookingId: widget.slot.id,
        exceptionDate: widget.selectedDate,
        institutionId: widget.institutionId,
        studentId: widget.slot.studentId,
      );

      widget.onUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Исключение добавлено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pauseSlot() async {
    // Показываем диалог выбора даты возобновления
    final untilDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Приостановить до',
    );

    if (untilDate == null) return;

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      await controller.pause(
        widget.slot.id,
        widget.institutionId,
        untilDate,
      );

      widget.onUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Слот приостановлен до ${_formatDate(untilDate)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resumeSlot() async {
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      await controller.resume(
        widget.slot.id,
        widget.institutionId,
      );

      widget.onUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Слот возобновлён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deactivateSlot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Деактивировать слот'),
        content: const Text(
          'Слот будет полностью отключён и не будет отображаться в расписании.\n\n'
          'Вы сможете активировать его снова в карточке ученика.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Деактивировать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(bookingControllerProvider.notifier);
      await controller.archive(
        widget.slot.id,
        widget.institutionId,
        widget.slot.studentId,
      );

      widget.onUpdated();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Слот деактивирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============================================================
// РЕДАКТИРОВАНИЕ СЕРИИ ПОВТОРЯЮЩИХСЯ ЗАНЯТИЙ
// ============================================================

/// Форма редактирования серии повторяющихся занятий
class _EditSeriesSheet extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String institutionId;
  final VoidCallback onUpdated;

  const _EditSeriesSheet({
    required this.lesson,
    required this.institutionId,
    required this.onUpdated,
  });

  @override
  ConsumerState<_EditSeriesSheet> createState() => _EditSeriesSheetState();
}

class _EditSeriesSheetState extends ConsumerState<_EditSeriesSheet> {
  // Занятия серии
  List<Lesson> _seriesLessons = [];
  bool _isLoadingSeries = true;

  // Выбор области изменений
  EditScope _editScope = EditScope.thisAndFollowing;
  Set<String> _selectedLessonIds = {};

  // Фильтр по дням недели (1=Пн ... 7=Вс)
  final Set<int> _selectedWeekdays = {};
  // Лимит количества занятий (0 = без лимита)
  int _quantityLimit = 0;

  // Редактируемые параметры (null = не изменять)
  TimeOfDay? _newStartTime;
  TimeOfDay? _newEndTime;
  String? _newRoomId;
  String? _newStudentId;
  String? _newSubjectId;
  String? _newLessonTypeId;

  // Конфликты
  List<String> _conflictLessonIds = [];
  bool _isCheckingConflicts = false;
  bool _isSaving = false;

  // Текущий месяц для мини-календаря
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(widget.lesson.date.year, widget.lesson.date.month);
    _loadSeriesLessons();
  }

  Future<void> _loadSeriesLessons() async {
    final repo = ref.read(lessonRepositoryProvider);
    try {
      final lessons = await repo.getSeriesLessons(widget.lesson.repeatGroupId!);
      lessons.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _seriesLessons = lessons;
        _isLoadingSeries = false;
        _updateSelectedLessons();
      });
    } catch (e) {
      setState(() => _isLoadingSeries = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки серии: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _updateSelectedLessons() {
    List<Lesson> filtered;

    switch (_editScope) {
      case EditScope.thisOnly:
        _selectedLessonIds = {widget.lesson.id};
        return;
      case EditScope.thisAndFollowing:
        filtered = _seriesLessons
            .where((l) => !l.date.isBefore(widget.lesson.date))
            .toList();
        break;
      case EditScope.all:
        filtered = List.from(_seriesLessons);
        break;
      case EditScope.selected:
        // При ручном выборе не перезаписываем
        return;
    }

    // Фильтр по дням недели
    if (_selectedWeekdays.isNotEmpty) {
      filtered = filtered.where((l) => _selectedWeekdays.contains(l.date.weekday)).toList();
    }

    // Лимит количества
    if (_quantityLimit > 0 && filtered.length > _quantityLimit) {
      filtered = filtered.take(_quantityLimit).toList();
    }

    _selectedLessonIds = filtered.map((l) => l.id).toSet();
  }

  List<Lesson> get _lessonsToEdit {
    return _seriesLessons.where((l) => _selectedLessonIds.contains(l.id)).toList();
  }

  bool get _hasChanges {
    return _newStartTime != null ||
        _newEndTime != null ||
        _newRoomId != null ||
        _newStudentId != null ||
        _newSubjectId != null ||
        _newLessonTypeId != null;
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Редактировать серию',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoadingSeries
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Область изменений
                        _buildScopeSelector(),
                        const SizedBox(height: 16),

                        // Фильтр по дням недели и количеству
                        if (_editScope != EditScope.thisOnly) ...[
                          _buildWeekdaysFilter(),
                          const SizedBox(height: 16),
                        ],

                        // Мини-календарь
                        _buildMiniCalendar(),
                        const SizedBox(height: 16),

                        // Список занятий
                        _buildLessonsList(),
                        const SizedBox(height: 24),

                        // Секция изменений
                        _buildChangesSection(
                          roomsAsync: roomsAsync,
                          studentsAsync: studentsAsync,
                          subjectsAsync: subjectsAsync,
                          lessonTypesAsync: lessonTypesAsync,
                        ),
                        const SizedBox(height: 16),

                        // Превью
                        _buildPreview(),
                        const SizedBox(height: 24),

                        // Кнопка применения
                        ElevatedButton.icon(
                          onPressed: _hasChanges && _selectedLessonIds.isNotEmpty && !_isSaving
                              ? _applyChanges
                              : null,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: Text(_isSaving ? 'Сохранение...' : 'Применить изменения'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Область изменений',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EditScope>(
          key: ValueKey('scope_$_editScope'),
          initialValue: _editScope,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.select_all),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          items: EditScope.values.map((scope) {
            return DropdownMenuItem(
              value: scope,
              child: Text(scope.label),
            );
          }).toList(),
          onChanged: (scope) {
            if (scope != null) {
              setState(() {
                _editScope = scope;
                _updateSelectedLessons();
              });
              _checkConflicts();
            }
          },
        ),
      ],
    );
  }

  Widget _buildWeekdaysFilter() {
    // Определяем какие дни недели есть в серии
    final weekdaysInSeries = <int>{};
    for (final lesson in _seriesLessons) {
      weekdaysInSeries.add(lesson.date.weekday);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Дни недели
        Text(
          'По дням недели',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final day in [
              (1, 'Пн'),
              (2, 'Вт'),
              (3, 'Ср'),
              (4, 'Чт'),
              (5, 'Пт'),
              (6, 'Сб'),
              (7, 'Вс'),
            ])
              FilterChip(
                label: Text(day.$2),
                selected: _selectedWeekdays.contains(day.$1),
                // Показываем только те дни, которые есть в серии
                backgroundColor: weekdaysInSeries.contains(day.$1)
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                onSelected: weekdaysInSeries.contains(day.$1)
                    ? (selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeekdays.add(day.$1);
                          } else {
                            _selectedWeekdays.remove(day.$1);
                          }
                          _updateSelectedLessons();
                        });
                        _checkConflicts();
                      }
                    : null,
              ),
          ],
        ),

        // Количество занятий
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Количество занятий:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _quantityLimit > 0 ? '$_quantityLimit' : 'Все',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Слайдер для выбора количества
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.onlyForContinuous,
          ),
          child: Slider(
            value: _quantityLimit.toDouble(),
            min: 0,
            max: 52,
            divisions: 52,
            label: _quantityLimit > 0 ? '$_quantityLimit' : 'Все',
            onChanged: (value) {
              setState(() => _quantityLimit = value.round());
              _updateSelectedLessons();
              _checkConflicts();
            },
          ),
        ),
        // Быстрые кнопки
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final count in [0, 4, 8, 12, 24])
              ActionChip(
                label: Text(count == 0 ? 'Все' : '$count'),
                backgroundColor: _quantityLimit == count
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                onPressed: () {
                  setState(() => _quantityLimit = count);
                  _updateSelectedLessons();
                  _checkConflicts();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCalendar() {
    // Находим месяцы, в которых есть занятия серии
    final months = <DateTime>{};
    for (final lesson in _seriesLessons) {
      months.add(DateTime(lesson.date.year, lesson.date.month));
    }
    final sortedMonths = months.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Навигация по месяцам
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final idx = sortedMonths.indexOf(_calendarMonth);
                if (idx > 0) {
                  setState(() => _calendarMonth = sortedMonths[idx - 1]);
                }
              },
            ),
            Text(
              _formatMonth(_calendarMonth),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final idx = sortedMonths.indexOf(_calendarMonth);
                if (idx < sortedMonths.length - 1) {
                  setState(() => _calendarMonth = sortedMonths[idx + 1]);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Дни недели
        Row(
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Календарная сетка
        _buildCalendarGrid(),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1 = Пн
    final daysInMonth = lastDay.day;

    final today = DateTime.now();
    final seriesDates = _seriesLessons.map((l) => l.date).toSet();
    final selectedDates = _lessonsToEdit.map((l) => l.date).toSet();

    final rows = <Widget>[];
    var currentRow = <Widget>[];

    // Пустые ячейки до первого дня месяца
    for (var i = 1; i < startWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox(height: 36)));
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
      final isSeriesDate = seriesDates.any((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day);
      final isSelected = selectedDates.any((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
      final isCurrent = date.year == widget.lesson.date.year &&
          date.month == widget.lesson.date.month &&
          date.day == widget.lesson.date.day;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: isSeriesDate && _editScope == EditScope.selected
                ? () => _toggleDateSelection(date)
                : null,
            child: Container(
              height: 36,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isSeriesDate
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: isPast ? 0.3 : 1)
                        : null,
                borderRadius: BorderRadius.circular(8),
                border: isCurrent
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : isToday
                        ? Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 1,
                          )
                        : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : isSeriesDate
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: isPast ? 0.5 : 1)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: isPast ? 0.3 : 1),
                    fontWeight: isCurrent ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    // Дополняем последнюю строку
    while (currentRow.isNotEmpty && currentRow.length < 7) {
      currentRow.add(const Expanded(child: SizedBox(height: 36)));
    }
    if (currentRow.isNotEmpty) {
      rows.add(Row(children: currentRow));
    }

    return Column(children: rows);
  }

  void _toggleDateSelection(DateTime date) {
    final lesson = _seriesLessons.firstWhere(
      (l) => l.date.year == date.year && l.date.month == date.month && l.date.day == date.day,
    );
    setState(() {
      if (_selectedLessonIds.contains(lesson.id)) {
        _selectedLessonIds.remove(lesson.id);
      } else {
        _selectedLessonIds.add(lesson.id);
      }
    });
    _checkConflicts();
  }

  Widget _buildLessonsList() {
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Занятия серии (${_seriesLessons.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              'Выбрано: ${_selectedLessonIds.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _seriesLessons.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final lesson = _seriesLessons[index];
              final isSelected = _selectedLessonIds.contains(lesson.id);
              final isCurrent = lesson.id == widget.lesson.id;
              final isPast = lesson.date.isBefore(DateTime(today.year, today.month, today.day));
              final hasConflict = _conflictLessonIds.contains(lesson.id);

              return CheckboxListTile(
                value: isSelected,
                onChanged: _editScope == EditScope.selected
                    ? (v) {
                        setState(() {
                          if (v == true) {
                            _selectedLessonIds.add(lesson.id);
                          } else {
                            _selectedLessonIds.remove(lesson.id);
                          }
                        });
                        _checkConflicts();
                      }
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(
                  AppDateUtils.formatDayMonth(lesson.date),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : null,
                    color: hasConflict
                        ? AppColors.error
                        : isPast
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                  ),
                ),
                subtitle: Text(
                  '${_formatTime(lesson.startTime)} – ${_formatTime(lesson.endTime)}',
                  style: TextStyle(
                    color: isPast ? Theme.of(context).colorScheme.outline : null,
                  ),
                ),
                secondary: isCurrent
                    ? Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.primary, size: 20)
                    : hasConflict
                        ? const Icon(Icons.warning, color: AppColors.error, size: 20)
                        : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChangesSection({
    required AsyncValue<List<Room>> roomsAsync,
    required AsyncValue<List<Student>> studentsAsync,
    required AsyncValue<List<Subject>> subjectsAsync,
    required AsyncValue<List<LessonType>> lessonTypesAsync,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Изменения',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),

        // Время
        _buildChangeRow(
          label: 'Время',
          currentValue: '${_formatTime(widget.lesson.startTime)} – ${_formatTime(widget.lesson.endTime)}',
          newValue: _newStartTime != null && _newEndTime != null
              ? '${_formatTime(_newStartTime!)} – ${_formatTime(_newEndTime!)}'
              : null,
          onTap: () => _pickTimeRange(),
          onClear: () => setState(() {
            _newStartTime = null;
            _newEndTime = null;
            _checkConflicts();
          }),
        ),

        // Кабинет
        roomsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (rooms) {
            final currentRoom = rooms.where((r) => r.id == widget.lesson.roomId).firstOrNull;
            final newRoom = _newRoomId != null
                ? rooms.where((r) => r.id == _newRoomId).firstOrNull
                : null;

            return _buildChangeRow(
              label: 'Кабинет',
              currentValue: currentRoom?.name ?? 'Не выбран',
              newValue: newRoom?.name,
              onTap: () => _showRoomPicker(rooms),
              onClear: () => setState(() {
                _newRoomId = null;
                _checkConflicts();
              }),
            );
          },
        ),

        // Ученик (только для индивидуальных занятий)
        if (widget.lesson.studentId != null)
          studentsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (students) {
              final currentStudent = students.where((s) => s.id == widget.lesson.studentId).firstOrNull;
              final newStudent = _newStudentId != null
                  ? students.where((s) => s.id == _newStudentId).firstOrNull
                  : null;

              return _buildChangeRow(
                label: 'Ученик',
                currentValue: currentStudent?.name ?? 'Не выбран',
                newValue: newStudent?.name,
                onTap: () => _showStudentPicker(students),
                onClear: () => setState(() => _newStudentId = null),
              );
            },
          ),

        // Предмет
        subjectsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (subjects) {
            final currentSubject = subjects.where((s) => s.id == widget.lesson.subjectId).firstOrNull;
            final newSubject = _newSubjectId != null
                ? subjects.where((s) => s.id == _newSubjectId).firstOrNull
                : null;

            return _buildChangeRow(
              label: 'Предмет',
              currentValue: currentSubject?.name ?? 'Не выбран',
              newValue: newSubject?.name,
              onTap: () => _showSubjectPicker(subjects),
              onClear: () => setState(() => _newSubjectId = null),
            );
          },
        ),

        // Тип занятия
        lessonTypesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (lessonTypes) {
            final currentType = lessonTypes.where((t) => t.id == widget.lesson.lessonTypeId).firstOrNull;
            final newType = _newLessonTypeId != null
                ? lessonTypes.where((t) => t.id == _newLessonTypeId).firstOrNull
                : null;

            return _buildChangeRow(
              label: 'Тип занятия',
              currentValue: currentType?.name ?? 'Не выбран',
              newValue: newType?.name,
              onTap: () => _showLessonTypePicker(lessonTypes),
              onClear: () => setState(() => _newLessonTypeId = null),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChangeRow({
    required String label,
    required String currentValue,
    String? newValue,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasChange = newValue != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasChange
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
            color: hasChange
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (hasChange)
                      Row(
                        children: [
                          Text(
                            currentValue,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              newValue,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        currentValue,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              if (hasChange)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                )
              else
                Icon(
                  Icons.edit,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final lessonsToEdit = _lessonsToEdit;
    final conflictCount = _conflictLessonIds.where((id) => _selectedLessonIds.contains(id)).length;
    final validCount = lessonsToEdit.length - conflictCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCheckingConflicts)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Проверка конфликтов...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          else ...[
            Text(
              'Будет изменено: $validCount занятий',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (conflictCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Конфликты: $conflictCount (будут пропущены)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickTimeRange() async {
    final range = await showIosTimeRangePicker(
      context: context,
      initialStartTime: _newStartTime ?? widget.lesson.startTime,
      initialEndTime: _newEndTime ?? widget.lesson.endTime,
      minuteInterval: 5,
    );

    if (range != null) {
      setState(() {
        _newStartTime = range.start;
        _newEndTime = range.end;
      });
      _checkConflicts();
    }
  }

  void _showRoomPicker(List<Room> rooms) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: rooms.length,
        itemBuilder: (_, index) {
          final room = rooms[index];
          final isSelected = room.id == _newRoomId;
          final isCurrent = room.id == widget.lesson.roomId;

          return ListTile(
            title: Text(room.name),
            trailing: isSelected
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : isCurrent
                    ? Text('текущий', style: Theme.of(context).textTheme.bodySmall)
                    : null,
            onTap: () {
              Navigator.pop(ctx);
              if (room.id != widget.lesson.roomId) {
                setState(() => _newRoomId = room.id);
                _checkConflicts();
              }
            },
          );
        },
      ),
    );
  }

  void _showStudentPicker(List<Student> students) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: students.length,
        itemBuilder: (_, index) {
          final student = students[index];
          final isSelected = student.id == _newStudentId;
          final isCurrent = student.id == widget.lesson.studentId;

          return ListTile(
            title: Text(student.name),
            trailing: isSelected
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : isCurrent
                    ? Text('текущий', style: Theme.of(context).textTheme.bodySmall)
                    : null,
            onTap: () {
              Navigator.pop(ctx);
              if (student.id != widget.lesson.studentId) {
                setState(() => _newStudentId = student.id);
              }
            },
          );
        },
      ),
    );
  }

  void _showSubjectPicker(List<Subject> subjects) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: subjects.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) {
            return ListTile(
              title: const Text('Не выбран'),
              trailing: _newSubjectId == '' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _newSubjectId = '');
              },
            );
          }
          final subject = subjects[index - 1];
          final isSelected = subject.id == _newSubjectId;
          final isCurrent = subject.id == widget.lesson.subjectId;

          return ListTile(
            title: Text(subject.name),
            trailing: isSelected
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : isCurrent
                    ? Text('текущий', style: Theme.of(context).textTheme.bodySmall)
                    : null,
            onTap: () {
              Navigator.pop(ctx);
              if (subject.id != widget.lesson.subjectId) {
                setState(() => _newSubjectId = subject.id);
              }
            },
          );
        },
      ),
    );
  }

  void _showLessonTypePicker(List<LessonType> lessonTypes) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: lessonTypes.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) {
            return ListTile(
              title: const Text('Не выбран'),
              trailing: _newLessonTypeId == '' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _newLessonTypeId = '');
              },
            );
          }
          final lessonType = lessonTypes[index - 1];
          final isSelected = lessonType.id == _newLessonTypeId;
          final isCurrent = lessonType.id == widget.lesson.lessonTypeId;

          return ListTile(
            title: Text(lessonType.name),
            trailing: isSelected
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : isCurrent
                    ? Text('текущий', style: Theme.of(context).textTheme.bodySmall)
                    : null,
            onTap: () {
              Navigator.pop(ctx);
              if (lessonType.id != widget.lesson.lessonTypeId) {
                setState(() => _newLessonTypeId = lessonType.id);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _checkConflicts() async {
    if (!_hasChanges || _selectedLessonIds.isEmpty) {
      setState(() => _conflictLessonIds = []);
      return;
    }

    // Проверяем конфликты только если изменились время или кабинет
    if (_newStartTime == null && _newEndTime == null && _newRoomId == null) {
      setState(() => _conflictLessonIds = []);
      return;
    }

    setState(() => _isCheckingConflicts = true);

    final repo = ref.read(lessonRepositoryProvider);
    final conflicts = <String>[];

    for (final lesson in _lessonsToEdit) {
      try {
        final hasConflict = await repo.hasTimeConflict(
          roomId: _newRoomId ?? lesson.roomId,
          date: lesson.date,
          startTime: _newStartTime ?? lesson.startTime,
          endTime: _newEndTime ?? lesson.endTime,
          excludeLessonId: lesson.id,
        );

        if (hasConflict) {
          conflicts.add(lesson.id);
        }
      } catch (e) {
        // Игнорируем ошибки проверки отдельных занятий
      }
    }

    if (mounted) {
      setState(() {
        _conflictLessonIds = conflicts;
        _isCheckingConflicts = false;
      });
    }
  }

  Future<void> _applyChanges() async {
    // Фильтруем занятия с конфликтами
    final lessonsToUpdate = _lessonsToEdit
        .where((l) => !_conflictLessonIds.contains(l.id))
        .toList();

    if (lessonsToUpdate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет занятий для обновления (все имеют конфликты)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(lessonControllerProvider.notifier);
      final lessonIds = lessonsToUpdate.map((l) => l.id).toList();

      await controller.updateSelected(
        lessonIds,
        widget.institutionId,
        startTime: _newStartTime,
        endTime: _newEndTime,
        roomId: _newRoomId,
        studentId: _newStudentId,
        subjectId: _newSubjectId == '' ? null : _newSubjectId,
        lessonTypeId: _newLessonTypeId == '' ? null : _newLessonTypeId,
      );

      if (mounted) {
        widget.onUpdated();
        Navigator.pop(context);

        final skipped = _lessonsToEdit.length - lessonsToUpdate.length;
        final message = skipped > 0
            ? 'Обновлено ${lessonsToUpdate.length} занятий (пропущено: $skipped)'
            : 'Обновлено ${lessonsToUpdate.length} занятий';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatMonth(DateTime date) {
    const months = [
      '', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return '${months[date.month]} ${date.year}';
  }
}

/// Диалог настройки кабинетов по умолчанию
class _RoomSetupSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final List<Room> rooms;
  final bool isFirstTime;
  final VoidCallback onSaved;

  const _RoomSetupSheet({
    required this.institutionId,
    required this.rooms,
    required this.isFirstTime,
    required this.onSaved,
  });

  @override
  ConsumerState<_RoomSetupSheet> createState() => _RoomSetupSheetState();
}

class _RoomSetupSheetState extends ConsumerState<_RoomSetupSheet> {
  late Set<String> _selectedRoomIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Загружаем текущие настройки
    final membership = ref.read(myMembershipProvider(widget.institutionId)).valueOrNull;
    if (membership?.defaultRoomIds != null && membership!.defaultRoomIds!.isNotEmpty) {
      _selectedRoomIds = Set.from(membership.defaultRoomIds!);
    } else {
      _selectedRoomIds = {}; // По умолчанию ничего не выбрано
    }
  }

  Future<void> _saveSelection(List<String>? roomIds) async {
    setState(() => _isSaving = true);

    try {
      final membership = ref.read(myMembershipProvider(widget.institutionId)).valueOrNull;
      if (membership == null) throw Exception('Не удалось получить данные участника');

      final success = await ref.read(memberControllerProvider.notifier).updateDefaultRooms(
        membership.id,
        widget.institutionId,
        roomIds,
      );

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(roomIds == null || roomIds.isEmpty
                  ? 'Отображаются все кабинеты'
                  : 'Выбрано кабинетов: ${roomIds.length}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Заголовок
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.isFirstTime
                        ? 'Какими кабинетами вы пользуетесь?'
                        : 'Кабинеты по умолчанию',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isFirstTime
                        ? 'В расписании будут отображаться только выбранные кабинеты. Изменить настройку можно в любой момент через меню фильтров.'
                        : 'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Список кабинетов
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.rooms.length,
                itemBuilder: (context, index) {
                  final room = widget.rooms[index];
                  final isSelected = _selectedRoomIds.contains(room.id);
                  return CheckboxListTile(
                    title: Text(room.name),
                    subtitle: room.number != null ? Text('Кабинет ${room.number}') : null,
                    value: isSelected,
                    onChanged: _isSaving ? null : (value) {
                      setState(() {
                        if (value == true) {
                          _selectedRoomIds.add(room.id);
                        } else {
                          _selectedRoomIds.remove(room.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Кнопки
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Кнопка "Пропустить" (только при первой настройке)
                  if (widget.isFirstTime)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _saveSelection([]),
                        child: const Text('Пропустить'),
                      ),
                    ),
                  if (widget.isFirstTime) const SizedBox(width: 12),
                  // Кнопка "Сохранить"
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving || _selectedRoomIds.isEmpty
                          ? null
                          : () => _saveSelection(_selectedRoomIds.toList()),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_selectedRoomIds.isEmpty
                              ? 'Выберите кабинеты'
                              : 'Сохранить (${_selectedRoomIds.length})'),
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
}

// ============================================================
// ПУБЛИЧНАЯ ФУНКЦИЯ ДЛЯ ПОКАЗА ДЕТАЛЕЙ ЗАНЯТИЯ
// ============================================================

/// Показать детали занятия в модальном окне
/// Может быть вызвана из любого места приложения
void showLessonDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Lesson lesson,
  required String institutionId,
  VoidCallback? onUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LessonDetailSheet(
      lesson: lesson,
      institutionId: institutionId,
      onUpdated: onUpdated ?? () {},
    ),
  );
}
