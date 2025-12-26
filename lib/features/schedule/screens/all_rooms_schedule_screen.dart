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
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';

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

class _AllRoomsScheduleScreenState extends ConsumerState<AllRoomsScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedRoomId; // null = все кабинеты
  double? _savedScrollOffset; // Сохранённая позиция скролла для восстановления
  ScheduleFilters _filters = const ScheduleFilters();
  ScheduleViewMode _viewMode = ScheduleViewMode.day;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final lessonsAsync = ref.watch(
      lessonsByInstitutionStreamProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
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
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
            },
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
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
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
                ? _buildDayView(roomsAsync, lessonsAsync)
                : _buildWeekView(roomsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(
    AsyncValue<List<Room>> roomsAsync,
    AsyncValue<List<Lesson>> lessonsAsync,
  ) {
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (rooms) => lessonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (lessons) {
          final filteredLessons = _filters.isEmpty
              ? lessons
              : lessons.where((l) => _filters.matchesLesson(l)).toList();

          return _AllRoomsTimeGrid(
            rooms: _selectedRoomId != null
                ? rooms.where((r) => r.id == _selectedRoomId).toList()
                : rooms,
            allRooms: rooms,
            lessons: filteredLessons,
            selectedDate: _selectedDate,
            institutionId: widget.institutionId,
            selectedRoomId: _selectedRoomId,
            restoreScrollOffset: _savedScrollOffset,
            onLessonTap: _showLessonDetail,
            onRoomTap: (roomId, currentOffset) {
              setState(() {
                if (_selectedRoomId == roomId) {
                  // Возвращаемся к общему виду
                  _selectedRoomId = null;
                } else {
                  // Сохраняем позицию скролла перед переходом к одному кабинету
                  _savedScrollOffset = currentOffset;
                  _selectedRoomId = roomId;
                }
              });
            },
            onAddLesson: (room, hour) => _showAddLessonSheet(room, hour),
          );
        },
      ),
    );
  }

  Widget _buildWeekView(AsyncValue<List<Room>> roomsAsync) {
    final weekStart = InstitutionWeekParams.getWeekStart(_selectedDate);
    final weekParams = InstitutionWeekParams(widget.institutionId, weekStart);
    final weekLessonsAsync = ref.watch(lessonsByInstitutionWeekProvider(weekParams));

    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (rooms) => weekLessonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (lessonsByDay) {
          // Применяем фильтры к занятиям каждого дня
          final filteredLessonsByDay = <DateTime, List<Lesson>>{};
          for (final entry in lessonsByDay.entries) {
            filteredLessonsByDay[entry.key] = _filters.isEmpty
                ? entry.value
                : entry.value.where((l) => _filters.matchesLesson(l)).toList();
          }

          return _WeekTimeGrid(
            rooms: _selectedRoomId != null
                ? rooms.where((r) => r.id == _selectedRoomId).toList()
                : rooms,
            allRooms: rooms,
            lessonsByDay: filteredLessonsByDay,
            weekStart: weekStart,
            institutionId: widget.institutionId,
            selectedRoomId: _selectedRoomId,
            restoreScrollOffset: _savedScrollOffset,
            onRoomTap: (roomId, currentOffset) {
              setState(() {
                if (_selectedRoomId == roomId) {
                  // Возвращаемся к общему виду
                  _selectedRoomId = null;
                } else {
                  // Сохраняем позицию скролла перед переходом к одному кабинету
                  _savedScrollOffset = currentOffset;
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
          );
        },
      ),
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

  void _showAddLessonSheet(Room room, int hour) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddLessonSheet(
        room: room,
        date: _selectedDate,
        startHour: hour,
        institutionId: widget.institutionId,
        onCreated: () {
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

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
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

  const _WeekDaySelector({
    required this.selectedDate,
    required this.onDateSelected,
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
    // Не прокручиваем автоматически - пользователь сам листает
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
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
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
  final DateTime selectedDate;
  final String institutionId;
  final String? selectedRoomId;
  final double? restoreScrollOffset; // Позиция скролла для восстановления
  final void Function(Lesson) onLessonTap;
  final void Function(String roomId, double currentOffset) onRoomTap;
  final void Function(Room room, int hour) onAddLesson;

  const _AllRoomsTimeGrid({
    required this.rooms,
    required this.allRooms,
    required this.lessons,
    required this.selectedDate,
    required this.institutionId,
    required this.onLessonTap,
    required this.onRoomTap,
    required this.onAddLesson,
    this.selectedRoomId,
    this.restoreScrollOffset,
  });

  static const startHour = 8;
  static const endHour = 22;
  static const hourHeight = 60.0;
  static const roomColumnWidth = 120.0; // Базовая ширина для многих кабинетов

  @override
  State<_AllRoomsTimeGrid> createState() => _AllRoomsTimeGridState();
}

class _AllRoomsTimeGridState extends State<_AllRoomsTimeGrid> {
  late ScrollController _headerScrollController;
  late ScrollController _gridScrollController;
  bool _isSyncing = false;

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
      // Восстанавливаем позицию скролла сразу
      _restoreScrollPosition(widget.restoreScrollOffset!);
    }
  }

  void _restoreScrollPosition(double offset) {
    if (_headerScrollController.hasClients) {
      _headerScrollController.jumpTo(offset);
    }
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(offset);
    }
  }

  void _syncGridFromHeader() {
    if (_isSyncing) return;
    // Не синхронизируем когда выбран один кабинет (разные ширины)
    if (widget.selectedRoomId != null) return;
    _isSyncing = true;
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
    if (rooms.isEmpty) {
      return const Center(
        child: Text('Нет кабинетов', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final totalHeight = (_AllRoomsTimeGrid.endHour - _AllRoomsTimeGrid.startHour + 1) * _AllRoomsTimeGrid.hourHeight;

    // Если выбран один кабинет - используем всю доступную ширину
    final isSingleRoom = widget.selectedRoomId != null && rooms.length == 1;

    return LayoutBuilder(builder: (context, constraints) {
      // Доступная ширина для колонки кабинета (минус ширина временной шкалы)
      final availableWidth = constraints.maxWidth - AppSizes.timeGridWidth;
      final roomColumnWidth = isSingleRoom
          ? availableWidth
          : _AllRoomsTimeGrid.roomColumnWidth;

    return Column(
      children: [
        // Заголовки кабинетов
        Container(
          height: 40,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              // Пустое место над временной шкалой
              SizedBox(width: AppSizes.timeGridWidth),
              // Заголовки кабинетов (кликабельные для фильтрации)
              Expanded(
                child: isSingleRoom
                    ? Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onRoomTap(
                                widget.rooms[0].id,
                                0,
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: widget.selectedRoomId == widget.rooms[0].id
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : null,
                                  border: BorderDirectional(
                                    bottom: widget.selectedRoomId == widget.rooms[0].id
                                        ? BorderSide(color: AppColors.primary, width: 2)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  widget.rooms[0].number != null
                                      ? '№${widget.rooms[0].number}'
                                      : widget.rooms[0].name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: widget.selectedRoomId == widget.rooms[0].id
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
                                  onTap: () => widget.onRoomTap(
                                    widget.rooms[index].id,
                                    _headerScrollController.hasClients ? _headerScrollController.offset : 0,
                                  ),
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
                        for (int hour = _AllRoomsTimeGrid.startHour; hour <= _AllRoomsTimeGrid.endHour; hour++)
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
                    child: isSingleRoom
                        ? Stack(
                            children: [
                              // Сетка с кликабельными ячейками
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(),
                                      child: Column(
                                        children: [
                                          for (int hour = _AllRoomsTimeGrid.startHour; hour <= _AllRoomsTimeGrid.endHour; hour++)
                                            _buildCell(rooms[0], hour, lessons),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Занятия
                              ...lessons.map((lesson) => _buildLessonBlock(context, lesson, roomColumnWidth)),
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
                                              for (int hour = _AllRoomsTimeGrid.startHour; hour <= _AllRoomsTimeGrid.endHour; hour++)
                                                _buildCell(rooms[i], hour, lessons),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Занятия
                                  ...lessons.map((lesson) => _buildLessonBlock(context, lesson, roomColumnWidth)),
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

  /// Проверяет, занята ли ячейка (есть ли урок в этот час)
  bool _isCellOccupied(Room room, int hour, List<Lesson> lessons) {
    for (final lesson in lessons) {
      if (lesson.roomId != room.id) continue;
      final lessonStartHour = lesson.startTime.hour;
      final lessonEndHour = lesson.endTime.hour + (lesson.endTime.minute > 0 ? 1 : 0);
      if (hour >= lessonStartHour && hour < lessonEndHour) {
        return true;
      }
    }
    return false;
  }

  Widget _buildCell(Room room, int hour, List<Lesson> lessons) {
    final isOccupied = _isCellOccupied(room, hour, lessons);

    return GestureDetector(
      onTap: isOccupied ? null : () => widget.onAddLesson(room, hour),
      child: Container(
        height: _AllRoomsTimeGrid.hourHeight,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: isOccupied
            ? null
            : Center(
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                ),
              ),
      ),
    );
  }

  Widget _buildLessonBlock(BuildContext context, Lesson lesson, double roomColumnWidth) {
    final roomIndex = widget.rooms.indexWhere((r) => r.id == lesson.roomId);
    if (roomIndex == -1) return const SizedBox.shrink();

    final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final startOffset = (startMinutes - _AllRoomsTimeGrid.startHour * 60) / 60 * _AllRoomsTimeGrid.hourHeight;
    final duration = (endMinutes - startMinutes) / 60 * _AllRoomsTimeGrid.hourHeight;

    final color = _getLessonColor(lesson);
    final participant = lesson.student?.name ?? lesson.group?.name ?? 'Занятие';

    return Positioned(
      top: startOffset,
      left: roomIndex * roomColumnWidth + 2,
      width: roomColumnWidth - 4,
      child: GestureDetector(
        onTap: () => widget.onLessonTap(lesson),
        child: Container(
          height: duration,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      participant,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (lesson.isRepeating)
                    const Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                  if (lesson.status == LessonStatus.completed)
                    const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                  if (lesson.status == LessonStatus.cancelled)
                    const Icon(Icons.cancel, size: 12, color: AppColors.error),
                ],
              ),
              if (duration > 30)
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

  Color _getLessonColor(Lesson lesson) {
    if (lesson.status == LessonStatus.cancelled) {
      return AppColors.error;
    }
    if (lesson.status == LessonStatus.completed) {
      return AppColors.success;
    }
    if (lesson.group != null) {
      return AppColors.lessonGroup;
    }
    return AppColors.lessonIndividual;
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
  final void Function(String roomId, double currentOffset) onRoomTap;
  final void Function(Room room, DateTime date) onCellTap;

  const _WeekTimeGrid({
    required this.rooms,
    required this.allRooms,
    required this.lessonsByDay,
    required this.weekStart,
    required this.institutionId,
    required this.onRoomTap,
    required this.onCellTap,
    this.selectedRoomId,
    this.restoreScrollOffset,
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
      // Восстанавливаем позицию скролла сразу
      _restoreScrollPosition(widget.restoreScrollOffset!);
    }
  }

  void _restoreScrollPosition(double offset) {
    if (_headerScrollController.hasClients) {
      _headerScrollController.jumpTo(offset);
    }
    for (final controller in _dayControllers) {
      if (controller.hasClients) {
        controller.jumpTo(offset);
      }
    }
  }

  void _syncFromHeader() {
    if (_isSyncing) return;
    if (!_headerScrollController.hasClients) return;

    _isSyncing = true;

    final offset = _headerScrollController.offset;

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
      return const Center(
        child: Text('Нет кабинетов', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    // Вычисляем высоту каждой строки на основе максимального количества занятий
    final rowHeights = <int, double>{};
    for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
      final date = widget.weekStart.add(Duration(days: dayIndex));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dayLessons = widget.lessonsByDay[normalizedDate] ?? [];

      int maxLessons = 0;
      for (final room in rooms) {
        final count = dayLessons.where((l) => l.roomId == room.id).length;
        if (count > maxLessons) maxLessons = count;
      }

      rowHeights[dayIndex] = maxLessons > 0
          ? (maxLessons * _WeekTimeGrid.lessonItemHeight + 8).clamp(_WeekTimeGrid.minRowHeight, double.infinity)
          : _WeekTimeGrid.minRowHeight;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Если выбран один кабинет - расширяем на весь экран
        final availableWidth = constraints.maxWidth - _WeekTimeGrid.dayLabelWidth;
        final roomColumnWidth = rooms.length == 1
            ? availableWidth
            : _WeekTimeGrid.minRoomColumnWidth;
        final totalWidth = rooms.length * roomColumnWidth;
        final needsHorizontalScroll = totalWidth > availableWidth;

        return Column(
          children: [
            // Заголовки кабинетов (всегда показываем все, как в режиме День)
            Container(
              height: 40,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
              ),
              child: Row(
                children: [
                  // Пустой угол
                  Container(
                    width: _WeekTimeGrid.dayLabelWidth,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: const Text(
                      'Неделя',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Заголовки кабинетов
                  Expanded(
                    child: rooms.length == 1
                        ? _buildRoomHeaders(widget.rooms, roomColumnWidth)
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
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: List.generate(7, (dayIndex) {
                    final date = widget.weekStart.add(Duration(days: dayIndex));
                    final normalizedDate = DateTime(date.year, date.month, date.day);
                    final dayLessons = widget.lessonsByDay[normalizedDate] ?? [];
                    final isToday = AppDateUtils.isToday(date);
                    final rowHeight = rowHeights[dayIndex] ?? _WeekTimeGrid.minRowHeight;

                    return Container(
                      height: rowHeight,
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
                            height: rowHeight,
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
                            child: rooms.length == 1
                                ? _buildDayCells(widget.rooms, dayLessons, date, roomColumnWidth)
                                : SingleChildScrollView(
                                    controller: _dayControllers[dayIndex],
                                    scrollDirection: Axis.horizontal,
                                    physics: const ClampingScrollPhysics(),
                                    child: SizedBox(
                                      width: totalWidth,
                                      child: _buildDayCells(widget.rooms, dayLessons, date, roomColumnWidth),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomHeaders(List<Room> rooms, double roomColumnWidth) {
    final isSingleRoom = rooms.length == 1;
    return Row(
      children: rooms.map((room) {
        final isSelected = widget.selectedRoomId == room.id;
        final content = GestureDetector(
          onTap: () => widget.onRoomTap(
            room.id,
            _headerScrollController.hasClients ? _headerScrollController.offset : 0,
          ),
          child: Container(
            width: isSingleRoom ? double.infinity : roomColumnWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
              border: const Border(
                left: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Text(
              room.number != null ? '№${room.number}' : room.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
        return isSingleRoom ? Expanded(child: content) : content;
      }).toList(),
    );
  }

  Widget _buildDayCells(List<Room> rooms, List<Lesson> dayLessons, DateTime date, double roomColumnWidth) {
    final isSingleRoom = rooms.length == 1;
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
            width: isSingleRoom ? double.infinity : roomColumnWidth,
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
        return isSingleRoom ? Expanded(child: content) : content;
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

  Color _getLessonColor(Lesson lesson) {
    if (lesson.status == LessonStatus.cancelled) {
      return AppColors.error;
    }
    if (lesson.status == LessonStatus.completed) {
      return AppColors.success;
    }
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
    final permissions = ref.watch(myPermissionsProvider(widget.institutionId));
    final isOwnLesson = currentUserId != null && lesson.teacherId == currentUserId;
    final canDelete = isOwner ||
                      (permissions?.deleteAllLessons ?? false) ||
                      (isOwnLesson && (permissions?.deleteOwnLessons ?? false));

    ref.listen(lessonControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  lesson.student?.name ?? lesson.group?.name ?? 'Занятие',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.onUpdated();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.access_time, value: timeStr),
          if (lesson.room != null)
            _InfoRow(
              icon: Icons.door_front_door,
              value: lesson.room!.number != null
                  ? 'Кабинет ${lesson.room!.number}'
                  : lesson.room!.name,
            ),
          if (lesson.subject != null)
            _InfoRow(icon: Icons.music_note, value: lesson.subject!.name),
          if (lesson.lessonType != null)
            _InfoRow(icon: Icons.category, value: lesson.lessonType!.name),
          if (hasPrice)
            _InfoRow(
              icon: Icons.attach_money,
              value: '${lesson.lessonType!.defaultPrice!.toStringAsFixed(0)} ₸',
            ),
          if (lesson.isRepeating)
            const _InfoRow(
              icon: Icons.repeat,
              value: 'Повторяющееся занятие',
            ),
          const SizedBox(height: 16),

          // Чекбоксы статуса
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Проведено
                Expanded(
                  child: _StatusCheckbox(
                    label: 'Проведено',
                    value: _isCompleted,
                    color: AppColors.success,
                    isLoading: _isLoading || controllerState.isLoading,
                    onChanged: (value) => _handleStatusChange(completed: value),
                  ),
                ),
                // Отменено
                Expanded(
                  child: _StatusCheckbox(
                    label: 'Отменено',
                    value: _isCancelled,
                    color: AppColors.warning,
                    isLoading: _isLoading || controllerState.isLoading,
                    onChanged: (value) => _handleStatusChange(cancelled: value),
                  ),
                ),
                // Оплачено (если есть цена и ученик)
                if (hasPrice && hasStudent)
                  Expanded(
                    child: _StatusCheckbox(
                      label: 'Оплачено',
                      value: _isPaid,
                      color: AppColors.primary,
                      isLoading: _isLoading || controllerState.isLoading || _isLoadingPayment,
                      onChanged: (value) {
                        if (value == true) {
                          _handlePayment();
                        } else {
                          _handleRemovePayment();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Кнопка редактирования
          OutlinedButton.icon(
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
            icon: const Icon(Icons.edit),
            label: const Text('Редактировать'),
          ),

          if (controllerState.isLoading || _isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 16),

          // Кнопка удаления (только если есть право)
          if (canDelete)
            TextButton.icon(
              onPressed: controllerState.isLoading || _isLoading
                  ? null
                  : _deleteLesson,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить занятие'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),

          const SizedBox(height: 8),
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
      success = await controller.complete(lesson.id, lesson.roomId, lesson.date);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.completed;
          _isLoading = false;
        });
      }
    } else if (completed == false && _isCompleted) {
      // Снимаем "Проведено" — возвращаем в "Запланировано"
      success = await controller.uncomplete(lesson.id, lesson.roomId, lesson.date);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.scheduled;
          _isLoading = false;
        });
      }
    } else if (cancelled == true) {
      // Ставим "Отменено" — снимаем "Проведено"
      success = await controller.cancel(lesson.id, lesson.roomId, lesson.date);
      if (success && mounted) {
        setState(() {
          _currentStatus = LessonStatus.cancelled;
          _isLoading = false;
        });
      }
    } else if (cancelled == false && _isCancelled) {
      // Снимаем "Отменено" — возвращаем в "Запланировано"
      success = await controller.uncomplete(lesson.id, lesson.roomId, lesson.date);
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
      await lessonController.complete(lesson.id, lesson.roomId, lesson.date);
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
        );
        message = 'Удалено $followingCount занятий';
      } else {
        success = await controller.delete(lesson.id, lesson.roomId, lesson.date);
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

/// Чекбокс для статуса занятия
class _StatusCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final bool isLoading;
  final void Function(bool?)? onChanged;

  const _StatusCheckbox({
    required this.label,
    required this.value,
    required this.color,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: isLoading ? null : onChanged,
          activeColor: color,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: value ? color : AppColors.textSecondary,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: AppColors.textSecondary)),
        ],
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
  Student? _selectedStudent;
  Subject? _selectedSubject;
  LessonType? _selectedLessonType;
  Room? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _startTime = widget.lesson.startTime;
    _endTime = widget.lesson.endTime;
    _date = widget.lesson.date;
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
            content: Text(next.error.toString()),
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
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
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
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
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
                _selectedRoom ??= rooms.firstWhere(
                  (r) => r.id == widget.lesson.roomId,
                  orElse: () => rooms.first,
                );
                return DropdownButtonFormField<Room>(
                  decoration: const InputDecoration(
                    labelText: 'Кабинет',
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
                );
              },
            ),
            const SizedBox(height: 16),

            // Ученик
            studentsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Ошибка: $e'),
              data: (students) {
                _selectedStudent ??= students.firstWhere(
                  (s) => s.id == widget.lesson.studentId,
                  orElse: () => students.first,
                );
                return DropdownButtonFormField<Student?>(
                  decoration: const InputDecoration(
                    labelText: 'Ученик',
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: _selectedStudent,
                  items: students.map((s) => DropdownMenuItem<Student?>(
                    value: s,
                    child: Text(s.name),
                  )).toList(),
                  onChanged: (student) {
                    setState(() => _selectedStudent = student);
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
                _selectedSubject ??= widget.lesson.subjectId != null
                    ? subjects.firstWhere(
                        (s) => s.id == widget.lesson.subjectId,
                        orElse: () => subjects.first,
                      )
                    : null;
                return DropdownButtonFormField<Subject?>(
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
                _selectedLessonType ??= widget.lesson.lessonTypeId != null
                    ? lessonTypes.firstWhere(
                        (lt) => lt.id == widget.lesson.lessonTypeId,
                        orElse: () => lessonTypes.first,
                      )
                    : null;
                return DropdownButtonFormField<LessonType?>(
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
          startTime: _startTime,
          endTime: _endTime,
        );
        message = 'Обновлено $followingCount занятий';
      } else {
        success = await controller.update(
          lesson.id,
          roomId: lesson.roomId,
          date: lesson.date,
          newRoomId: _selectedRoom?.id,
          newDate: _date,
          startTime: _startTime,
          endTime: _endTime,
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
        newRoomId: _selectedRoom?.id,
        newDate: _date,
        startTime: _startTime,
        endTime: _endTime,
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

/// Форма создания нового занятия
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

class _AddLessonSheet extends ConsumerStatefulWidget {
  final Room room;
  final DateTime date;
  final int startHour;
  final String institutionId;
  final VoidCallback onCreated;

  const _AddLessonSheet({
    required this.room,
    required this.date,
    required this.startHour,
    required this.institutionId,
    required this.onCreated,
  });

  @override
  ConsumerState<_AddLessonSheet> createState() => _AddLessonSheetState();
}

class _AddLessonSheetState extends ConsumerState<_AddLessonSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  Student? _selectedStudent;
  Subject? _selectedSubject;
  LessonType? _selectedLessonType;
  InstitutionMember? _selectedTeacher;

  // Опции повтора
  RepeatType _repeatType = RepeatType.none;
  int _repeatCount = 4; // Количество повторений
  Set<int> _selectedWeekdays = {}; // 1=Пн, 7=Вс
  List<DateTime> _customDates = []; // Ручной выбор дат
  List<DateTime> _previewDates = []; // Превью дат для создания
  List<DateTime> _conflictDates = []; // Даты с конфликтами
  bool _isCheckingConflicts = false;

  @override
  void initState() {
    super.initState();
    _startTime = TimeOfDay(hour: widget.startHour, minute: 0);
    _endTime = TimeOfDay(hour: widget.startHour + 1, minute: 0);
  }

  /// Генерирует список дат на основе типа повтора
  List<DateTime> _generateDates() {
    final dates = <DateTime>[widget.date]; // Первая дата всегда включена

    switch (_repeatType) {
      case RepeatType.none:
        return dates;
      case RepeatType.daily:
        for (int i = 1; i < _repeatCount; i++) {
          dates.add(widget.date.add(Duration(days: i)));
        }
        return dates;
      case RepeatType.weekly:
        for (int i = 1; i < _repeatCount; i++) {
          dates.add(widget.date.add(Duration(days: i * 7)));
        }
        return dates;
      case RepeatType.weekdays:
        if (_selectedWeekdays.isEmpty) return dates;
        var currentDate = widget.date;
        int added = 1;
        while (added < _repeatCount) {
          currentDate = currentDate.add(const Duration(days: 1));
          if (_selectedWeekdays.contains(currentDate.weekday)) {
            dates.add(currentDate);
            added++;
          }
          // Защита от бесконечного цикла
          if (currentDate.difference(widget.date).inDays > 365) break;
        }
        return dates;
      case RepeatType.custom:
        return [widget.date, ..._customDates];
    }
  }

  /// Показывает диалог мульти-выбора дат
  Future<void> _showMultiDatePicker() async {
    final selectedDates = Set<DateTime>.from(_customDates);
    final firstDate = widget.date.add(const Duration(days: 1));
    final lastDate = widget.date.add(const Duration(days: 365));

    final result = await showDialog<Set<DateTime>>(
      context: context,
      builder: (ctx) => _MultiDatePickerDialog(
        selectedDates: selectedDates,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );

    if (result != null) {
      setState(() {
        _customDates = result.toList()..sort();
      });
      _updatePreview();
    }
  }

  /// Обновляет превью дат и проверяет конфликты
  Future<void> _updatePreview() async {
    final dates = _generateDates();
    setState(() {
      _previewDates = dates;
      _isCheckingConflicts = true;
    });

    // Проверяем конфликты
    final controller = ref.read(lessonControllerProvider.notifier);
    final conflicts = await controller.checkConflictsForDates(
      roomId: widget.room.id,
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

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.institutionId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final lessonTypesAsync = ref.watch(lessonTypesProvider(widget.institutionId));
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
    final controllerState = ref.watch(lessonControllerProvider);

    ref.listen(lessonControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    final roomName = widget.room.number != null
        ? 'Кабинет ${widget.room.number}'
        : widget.room.name;

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
                  'Новое занятие',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Информация о кабинете и дате
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.door_front_door, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(roomName),
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(AppDateUtils.formatDayMonth(widget.date)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Время
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
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
                        // Перепроверяем конфликты при изменении времени
                        if (_repeatType != RepeatType.none) {
                          _updatePreview();
                        }
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
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
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

            // Ученик
            studentsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Ошибка: $e'),
              data: (students) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (students.isEmpty)
                      const Text(
                        'Нет учеников. Добавьте ученика ниже.',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    else
                      DropdownButtonFormField<Student?>(
                        decoration: const InputDecoration(
                          labelText: 'Ученик *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        value: _selectedStudent,
                        items: students.map((s) => DropdownMenuItem<Student?>(
                          value: s,
                          child: Text(s.name),
                        )).toList(),
                        onChanged: (student) {
                          setState(() => _selectedStudent = student);
                        },
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showAddStudentDialog(),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Добавить нового ученика'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Преподаватель (перемещён выше)
            membersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (members) {
                final activeMembers = members.where((m) => !m.isArchived).toList();
                if (activeMembers.length <= 1) return const SizedBox.shrink();

                // Установить текущего пользователя по умолчанию
                final currentUserId = ref.read(currentUserIdProvider);
                _selectedTeacher ??= activeMembers.where((m) => m.userId == currentUserId).firstOrNull;

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
                if (subjects.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<Subject?>(
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
                return DropdownButtonFormField<LessonType?>(
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
                );
              },
            ),
            const SizedBox(height: 16),

            // Тип повтора
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Повтор занятий',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RepeatType>(
              decoration: const InputDecoration(
                labelText: 'Тип повтора',
                prefixIcon: Icon(Icons.repeat),
              ),
              value: _repeatType,
              items: RepeatType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.label),
              )).toList(),
              onChanged: (type) {
                setState(() {
                  _repeatType = type ?? RepeatType.none;
                  _previewDates = [];
                  _conflictDates = [];
                });
                if (type != RepeatType.none) {
                  _updatePreview();
                }
              },
            ),

            // Количество повторений (для daily, weekly, weekdays)
            if (_repeatType != RepeatType.none && _repeatType != RepeatType.custom) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Количество занятий:'),
                  ),
                  IconButton(
                    onPressed: _repeatCount > 2
                        ? () {
                            setState(() => _repeatCount--);
                            _updatePreview();
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_repeatCount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _repeatCount < 52
                        ? () {
                            setState(() => _repeatCount++);
                            _updatePreview();
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],

            // Выбор дней недели
            if (_repeatType == RepeatType.weekdays) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
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
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeekdays.add(day.$1);
                          } else {
                            _selectedWeekdays.remove(day.$1);
                          }
                        });
                        _updatePreview();
                      },
                    ),
                ],
              ),
            ],

            // Ручной выбор дат
            if (_repeatType == RepeatType.custom) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showMultiDatePicker(),
                icon: const Icon(Icons.calendar_month),
                label: Text(_customDates.isEmpty
                    ? 'Выбрать даты в календаре'
                    : 'Выбрано: ${_customDates.length} дат'),
              ),
              if (_customDates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _customDates.map((date) => Chip(
                    label: Text(AppDateUtils.formatDayMonth(date)),
                    onDeleted: () {
                      setState(() => _customDates.remove(date));
                      _updatePreview();
                    },
                  )).toList(),
                ),
              ],
            ],

            // Превью дат с конфликтами
            if (_repeatType != RepeatType.none && _previewDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _conflictDates.isEmpty
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _conflictDates.isEmpty ? AppColors.success : AppColors.warning,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _conflictDates.isEmpty ? Icons.check_circle : Icons.warning,
                          size: 20,
                          color: _conflictDates.isEmpty ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCheckingConflicts
                              ? 'Проверка конфликтов...'
                              : _conflictDates.isEmpty
                                  ? 'Будет создано ${_previewDates.length} занятий'
                                  : 'Конфликты: ${_conflictDates.length} из ${_previewDates.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _conflictDates.isEmpty ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    if (_conflictDates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Конфликтные даты будут пропущены:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: _conflictDates.map((date) => Chip(
                          label: Text(
                            AppDateUtils.formatDayMonth(date),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: AppColors.error.withValues(alpha: 0.2),
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Кнопка создания
            ElevatedButton.icon(
              onPressed: controllerState.isLoading || _selectedStudent == null
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
          ],
        ),
      ),
    );
  }

  Future<void> _createLesson() async {
    if (_selectedStudent == null) return;

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    // Используем выбранного преподавателя или текущего пользователя
    final teacherId = _selectedTeacher?.userId ?? currentUserId;

    final controller = ref.read(lessonControllerProvider.notifier);

    // Если есть повтор — создаём серию
    if (_repeatType != RepeatType.none) {
      // Фильтруем конфликтные даты
      final datesToCreate = _previewDates
          .where((date) => !_conflictDates.contains(date))
          .toList();

      if (datesToCreate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все даты заняты'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final lessons = await controller.createSeries(
        institutionId: widget.institutionId,
        roomId: widget.room.id,
        teacherId: teacherId,
        dates: datesToCreate,
        startTime: _startTime,
        endTime: _endTime,
        studentId: _selectedStudent!.id,
        subjectId: _selectedSubject?.id,
        lessonTypeId: _selectedLessonType?.id,
      );

      if (lessons != null && mounted) {
        // Автоматически создаём привязки ученик-преподаватель и ученик-предмет
        _createBindings(teacherId);

        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Создано ${lessons.length} занятий'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Одиночное занятие
      final lesson = await controller.create(
        institutionId: widget.institutionId,
        roomId: widget.room.id,
        teacherId: teacherId,
        date: widget.date,
        startTime: _startTime,
        endTime: _endTime,
        studentId: _selectedStudent!.id,
        subjectId: _selectedSubject?.id,
        lessonTypeId: _selectedLessonType?.id,
      );

      if (lesson != null && mounted) {
        // Автоматически создаём привязки ученик-преподаватель и ученик-предмет
        _createBindings(teacherId);

        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Занятие создано'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// Создаёт привязки ученик-преподаватель и ученик-предмет (upsert - не падает если уже есть)
  void _createBindings(String teacherId) {
    if (_selectedStudent == null) return;

    // Запускаем в фоне, не блокируем UI
    ref.read(studentBindingsControllerProvider.notifier).createBindingsFromLesson(
      studentId: _selectedStudent!.id,
      teacherId: teacherId,
      subjectId: _selectedSubject?.id,
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

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: Colors.grey[300],
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Новый ученик',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Быстрое добавление',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
                    fillColor: Colors.grey[50],
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
                    fillColor: Colors.grey[50],
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

  bool get _hasChanges =>
      _selectedTeachers != widget.currentFilters.teacherIds ||
      _selectedStudents != widget.currentFilters.studentIds ||
      _selectedLessonTypes != widget.currentFilters.lessonTypeIds ||
      _selectedSubjects != widget.currentFilters.subjectIds;

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
    final membersAsync = ref.watch(membersProvider(widget.institutionId));
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
                      error: (e, _) => Text('Ошибка: $e'),
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
                      error: (e, _) => Text('Ошибка: $e'),
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
                      error: (e, _) => Text('Ошибка: $e'),
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
      error: (e, _) => Text('Ошибка: $e'),
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
