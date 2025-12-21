import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/utils/date_utils.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/institution/providers/subject_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/room.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/lesson_type.dart';

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

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final lessonsAsync = ref.watch(
      lessonsByInstitutionProvider(InstitutionDateParams(widget.institutionId, _selectedDate)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Все кабинеты'),
        actions: [
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
          _WeekDaySelector(
            selectedDate: _selectedDate,
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (rooms) => lessonsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
                data: (lessons) => _AllRoomsTimeGrid(
                  rooms: rooms,
                  lessons: lessons,
                  selectedDate: _selectedDate,
                  institutionId: widget.institutionId,
                  onLessonTap: _showLessonDetail,
                ),
              ),
            ),
          ),
        ],
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
          ref.invalidate(lessonsByInstitutionProvider(
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
}

class _WeekDaySelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekDaySelector({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final startOfWeek = AppDateUtils.startOfWeek(selectedDate);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = AppDateUtils.isSameDay(date, selectedDate);
          final isToday = AppDateUtils.isToday(date);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: InkWell(
              onTap: () => onDateSelected(date),
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

class _AllRoomsTimeGrid extends StatelessWidget {
  final List<Room> rooms;
  final List<Lesson> lessons;
  final DateTime selectedDate;
  final String institutionId;
  final void Function(Lesson) onLessonTap;

  const _AllRoomsTimeGrid({
    required this.rooms,
    required this.lessons,
    required this.selectedDate,
    required this.institutionId,
    required this.onLessonTap,
  });

  static const startHour = 8;
  static const endHour = 22;
  static const hourHeight = 60.0;
  static const roomColumnWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(
        child: Text('Нет кабинетов', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final totalHeight = (endHour - startHour + 1) * hourHeight;

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
              // Заголовки кабинетов
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Container(
                      width: roomColumnWidth,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: index == 0 ? Colors.transparent : AppColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Text(
                        room.number != null ? '№${room.number}' : room.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Сетка расписания
        Expanded(
          child: SingleChildScrollView(
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
                        for (int hour = startHour; hour <= endHour; hour++)
                          SizedBox(
                            height: hourHeight,
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: rooms.length * roomColumnWidth,
                        child: Stack(
                          children: [
                            // Сетка
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
                                        for (int hour = startHour; hour <= endHour; hour++)
                                          Container(
                                            height: hourHeight,
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                top: BorderSide(color: AppColors.border, width: 0.5),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            // Занятия
                            ...lessons.map((lesson) => _buildLessonBlock(context, lesson)),
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
  }

  Widget _buildLessonBlock(BuildContext context, Lesson lesson) {
    final roomIndex = rooms.indexWhere((r) => r.id == lesson.roomId);
    if (roomIndex == -1) return const SizedBox.shrink();

    final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final startOffset = (startMinutes - startHour * 60) / 60 * hourHeight;
    final duration = (endMinutes - startMinutes) / 60 * hourHeight;

    final color = _getLessonColor(lesson);
    final participant = lesson.student?.name ?? lesson.group?.name ?? 'Занятие';

    return Positioned(
      top: startOffset,
      left: roomIndex * roomColumnWidth + 2,
      width: roomColumnWidth - 4,
      child: GestureDetector(
        onTap: () => onLessonTap(lesson),
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

class _LessonDetailSheet extends ConsumerWidget {
  final Lesson lesson;
  final String institutionId;
  final VoidCallback onUpdated;

  const _LessonDetailSheet({
    required this.lesson,
    required this.institutionId,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(lessonControllerProvider);
    final timeStr = '${_formatTime(lesson.startTime)} — ${_formatTime(lesson.endTime)}';

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
                onPressed: () => Navigator.pop(context),
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
          const SizedBox(height: 12),
          _StatusChip(status: lesson.status),
          const SizedBox(height: 24),

          // Кнопка редактирования
          if (lesson.status == LessonStatus.scheduled) ...[
            OutlinedButton.icon(
              onPressed: controllerState.isLoading
                  ? null
                  : () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => _EditLessonSheet(
                          lesson: lesson,
                          institutionId: institutionId,
                          onUpdated: onUpdated,
                        ),
                      );
                    },
              icon: const Icon(Icons.edit),
              label: const Text('Редактировать'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controllerState.isLoading
                        ? null
                        : () async {
                            final controller = ref.read(lessonControllerProvider.notifier);
                            final success = await controller.complete(
                              lesson.id,
                              lesson.roomId,
                              lesson.date,
                            );
                            if (success && context.mounted) {
                              onUpdated();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Занятие отмечено как проведённое'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Проведено'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controllerState.isLoading
                        ? null
                        : () async {
                            final controller = ref.read(lessonControllerProvider.notifier);
                            final success = await controller.cancel(
                              lesson.id,
                              lesson.roomId,
                              lesson.date,
                            );
                            if (success && context.mounted) {
                              onUpdated();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Занятие отменено'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Отменить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (controllerState.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 16),

          // Кнопка удаления
          TextButton.icon(
            onPressed: controllerState.isLoading
                ? null
                : () => _deleteLesson(context, ref),
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

  Future<void> _deleteLesson(BuildContext context, WidgetRef ref) async {
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

    if (confirmed == true && context.mounted) {
      final controller = ref.read(lessonControllerProvider.notifier);
      final success = await controller.delete(
        lesson.id,
        lesson.roomId,
        lesson.date,
      );

      if (success && context.mounted) {
        onUpdated();
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

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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

class _StatusChip extends StatelessWidget {
  final LessonStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (status) {
      case LessonStatus.scheduled:
        label = 'Запланировано';
        color = AppColors.primary;
        break;
      case LessonStatus.completed:
        label = 'Проведено';
        color = AppColors.success;
        break;
      case LessonStatus.cancelled:
        label = 'Отменено';
        color = AppColors.error;
        break;
      case LessonStatus.rescheduled:
        label = 'Перенесено';
        color = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getStatusIcon(LessonStatus status) {
    switch (status) {
      case LessonStatus.scheduled:
        return Icons.schedule;
      case LessonStatus.completed:
        return Icons.check_circle;
      case LessonStatus.cancelled:
        return Icons.cancel;
      case LessonStatus.rescheduled:
        return Icons.update;
    }
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
    final success = await controller.update(
      widget.lesson.id,
      roomId: widget.lesson.roomId,
      date: widget.lesson.date,
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

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
