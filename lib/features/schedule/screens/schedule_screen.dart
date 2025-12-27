import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/utils/date_utils.dart';
import 'package:kabinet/core/utils/validators.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/features/schedule/providers/lesson_provider.dart';
import 'package:kabinet/features/students/providers/student_bindings_provider.dart';
import 'package:kabinet/features/students/providers/student_provider.dart';
import 'package:kabinet/features/institution/providers/subject_provider.dart';
import 'package:kabinet/features/institution/providers/institution_provider.dart';
import 'package:kabinet/features/institution/providers/member_provider.dart';
import 'package:kabinet/features/institution/providers/teacher_subjects_provider.dart';
import 'package:kabinet/features/lesson_types/providers/lesson_type_provider.dart';
import 'package:kabinet/features/payments/providers/payment_provider.dart';
import 'package:kabinet/features/subscriptions/providers/subscription_provider.dart';
import 'package:kabinet/shared/models/lesson.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subject.dart';
import 'package:kabinet/shared/models/institution_member.dart';
import 'package:kabinet/shared/models/lesson_type.dart';
import 'package:kabinet/shared/models/subscription.dart';
import 'package:kabinet/shared/providers/supabase_provider.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/widgets/error_view.dart';

/// Экран расписания кабинета
class ScheduleScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String institutionId;

  const ScheduleScreen({
    super.key,
    required this.roomId,
    required this.institutionId,
  });

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      ref.invalidate(lessonsByRoomProvider(RoomDateParams(widget.roomId, _selectedDate)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final lessonsAsync = ref.watch(
      lessonsByRoomProvider(RoomDateParams(widget.roomId, _selectedDate)),
    );

    return Scaffold(
      appBar: AppBar(
        title: roomAsync.when(
          data: (room) => Text(room.number != null ? 'Кабинет ${room.number}' : room.name),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Кабинет'),
        ),
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
            child: lessonsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView.fromException(e),
              data: (lessons) => _TimeGrid(
                selectedDate: _selectedDate,
                roomId: widget.roomId,
                institutionId: widget.institutionId,
                lessons: lessons,
                onLessonTap: (lesson) => _showLessonDetail(context, lesson),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLessonDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddLessonDialog(BuildContext context) {
    // Инвалидируем кеш справочников для получения актуальных данных
    ref.invalidate(subjectsProvider(widget.institutionId));
    ref.invalidate(lessonTypesProvider(widget.institutionId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddLessonSheet(
        institutionId: widget.institutionId,
        roomId: widget.roomId,
        date: _selectedDate,
        onCreated: () {
          ref.invalidate(lessonsByRoomProvider(RoomDateParams(widget.roomId, _selectedDate)));
        },
      ),
    );
  }

  void _showLessonDetail(BuildContext context, Lesson lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LessonDetailSheet(
        lesson: lesson,
        institutionId: widget.institutionId,
        onUpdated: () {
          ref.invalidate(lessonsByRoomProvider(RoomDateParams(widget.roomId, _selectedDate)));
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
        physics: const ClampingScrollPhysics(),
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

class _TimeGrid extends StatelessWidget {
  final DateTime selectedDate;
  final String roomId;
  final String institutionId;
  final List<Lesson> lessons;
  final void Function(Lesson) onLessonTap;

  const _TimeGrid({
    required this.selectedDate,
    required this.roomId,
    required this.institutionId,
    required this.lessons,
    required this.onLessonTap,
  });

  static const startHour = 8;
  static const endHour = 22;
  static const hourHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: Stack(
              children: [
                Column(
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
                ...lessons.map((lesson) => _buildLessonBlock(context, lesson)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonBlock(BuildContext context, Lesson lesson) {
    final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final startOffset = (startMinutes - startHour * 60) / 60 * hourHeight;
    final duration = (endMinutes - startMinutes) / 60 * hourHeight;

    final color = _getLessonColor(lesson);
    final participant = lesson.student?.name ?? lesson.group?.name ?? 'Занятие';

    return Positioned(
      top: startOffset,
      left: 4,
      right: 4,
      child: GestureDetector(
        onTap: () => onLessonTap(lesson),
        child: Container(
          height: duration,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
            border: Border.all(color: color, width: 2),
          ),
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  participant,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (lesson.status == LessonStatus.completed)
                const Icon(Icons.check_circle, size: 14, color: AppColors.success),
              if (lesson.status == LessonStatus.cancelled)
                const Icon(Icons.cancel, size: 14, color: AppColors.error),
            ],
          ),
        ),
      ),
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

/// Детали занятия
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

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.lesson.status;
    // Принудительно обновляем права при открытии
    Future.microtask(() {
      ref.invalidate(myMembershipProvider(widget.institutionId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
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

    final timeStr = '${lesson.startTime.hour.toString().padLeft(2, '0')}:${lesson.startTime.minute.toString().padLeft(2, '0')} — ${lesson.endTime.hour.toString().padLeft(2, '0')}:${lesson.endTime.minute.toString().padLeft(2, '0')}';

    final hasPrice = lesson.lessonType?.defaultPrice != null &&
                     lesson.lessonType!.defaultPrice! > 0;
    final hasStudent = lesson.studentId != null;
    final isCompleted = _currentStatus == LessonStatus.completed;
    final isScheduled = _currentStatus == LessonStatus.scheduled;
    final canEdit = isScheduled || isCompleted;

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
              Text(
                'Занятие',
                style: Theme.of(context).textTheme.titleLarge,
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
          const SizedBox(height: 16),

          // Информация о занятии
          _InfoRow(icon: Icons.access_time, label: 'Время', value: timeStr),
          if (lesson.student != null)
            _InfoRow(icon: Icons.person, label: 'Ученик', value: lesson.student!.name),
          if (lesson.group != null)
            _InfoRow(icon: Icons.group, label: 'Группа', value: lesson.group!.name),
          if (lesson.subject != null)
            _InfoRow(icon: Icons.book, label: 'Предмет', value: lesson.subject!.name),
          if (lesson.room != null)
            _InfoRow(
              icon: Icons.door_front_door,
              label: 'Кабинет',
              value: lesson.room!.number != null
                  ? 'Кабинет ${lesson.room!.number}'
                  : lesson.room!.name,
            ),
          if (hasPrice && hasStudent)
            _InfoRow(
              icon: Icons.payments,
              label: 'Цена',
              value: '${lesson.lessonType!.defaultPrice!.toInt()} ₸',
            ),

          // Статус
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(_currentStatus).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(_currentStatus), color: _getStatusColor(_currentStatus)),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(_currentStatus),
                  style: TextStyle(
                    color: _getStatusColor(_currentStatus),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Галочки для запланированных и проведённых занятий
          if (canEdit) ...[
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Checkbox Проведено
                  Column(
                    children: [
                      Checkbox(
                        value: isCompleted,
                        onChanged: (value) {
                          if (value == true) {
                            _handleComplete();
                          } else {
                            _handleUncomplete();
                          }
                        },
                        activeColor: AppColors.success,
                      ),
                      const Text('Проведено'),
                    ],
                  ),
                  // Checkbox Оплачено (только если есть цена и ученик)
                  if (hasPrice && hasStudent) ...[
                    const SizedBox(width: 32),
                    Column(
                      children: [
                        Checkbox(
                          value: _isPaid,
                          onChanged: _isPaid
                              ? null  // Уже оплачено - нельзя снять
                              : (value) {
                                  if (value == true) {
                                    _handlePayment();
                                  }
                                },
                          activeColor: AppColors.primary,
                        ),
                        const Text('Оплачено'),
                      ],
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),
          ],

          // Кнопки действий
          if (isScheduled) ...[
            OutlinedButton.icon(
              onPressed: controllerState.isLoading || _isLoading
                  ? null
                  : _handleCancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Отменить занятие'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (controllerState.isLoading && !_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 8),

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

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final success = await controller.complete(
      widget.lesson.id,
      widget.lesson.roomId,
      widget.lesson.date,
      widget.institutionId,
    );

    if (success && mounted) {
      setState(() {
        _currentStatus = LessonStatus.completed;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Занятие отмечено как проведённое'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUncomplete() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final success = await controller.uncomplete(
      widget.lesson.id,
      widget.lesson.roomId,
      widget.lesson.date,
      widget.institutionId,
    );

    if (success && mounted) {
      setState(() {
        _currentStatus = LessonStatus.scheduled;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Статус занятия изменён на "Запланировано"'),
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePayment() async {
    final lesson = widget.lesson;
    if (lesson.studentId == null || lesson.lessonType?.defaultPrice == null) return;

    setState(() => _isLoading = true);

    // Если занятие ещё не проведено - сначала помечаем как проведённое
    if (_currentStatus != LessonStatus.completed) {
      final lessonController = ref.read(lessonControllerProvider.notifier);
      await lessonController.complete(
        lesson.id,
        lesson.roomId,
        lesson.date,
        widget.institutionId,
      );
    }

    // Создаём оплату
    final paymentController = ref.read(paymentControllerProvider.notifier);
    await paymentController.create(
      institutionId: widget.institutionId,
      studentId: lesson.studentId!,
      amount: lesson.lessonType!.defaultPrice!,
      lessonsCount: 1,
      comment: lesson.lessonType?.name ?? 'Оплата занятия',
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

  Future<void> _handleCancel() async {
    setState(() => _isLoading = true);

    final controller = ref.read(lessonControllerProvider.notifier);
    final success = await controller.cancel(
      widget.lesson.id,
      widget.lesson.roomId,
      widget.lesson.date,
      widget.institutionId,
    );

    if (success && mounted) {
      widget.onUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Занятие отменено'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLesson() async {
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
      setState(() => _isLoading = true);

      final controller = ref.read(lessonControllerProvider.notifier);
      final success = await controller.delete(
        widget.lesson.id,
        widget.lesson.roomId,
        widget.lesson.date,
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

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.scheduled:
        return AppColors.primary;
      case LessonStatus.completed:
        return AppColors.success;
      case LessonStatus.cancelled:
        return AppColors.error;
      case LessonStatus.rescheduled:
        return AppColors.warning;
    }
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

  String _getStatusText(LessonStatus status) {
    switch (status) {
      case LessonStatus.scheduled:
        return 'Запланировано';
      case LessonStatus.completed:
        return 'Проведено';
      case LessonStatus.cancelled:
        return 'Отменено';
      case LessonStatus.rescheduled:
        return 'Перенесено';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Форма добавления занятия
class _AddLessonSheet extends ConsumerStatefulWidget {
  final String institutionId;
  final String roomId;
  final DateTime date;
  final VoidCallback onCreated;

  const _AddLessonSheet({
    required this.institutionId,
    required this.roomId,
    required this.date,
    required this.onCreated,
  });

  @override
  ConsumerState<_AddLessonSheet> createState() => _AddLessonSheetState();
}

class _AddLessonSheetState extends ConsumerState<_AddLessonSheet> {
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  Student? _selectedStudent;
  Subject? _selectedSubject;
  LessonType? _selectedLessonType;
  InstitutionMember? _selectedTeacher;

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

            Text(
              'Дата: ${AppDateUtils.formatDayMonth(widget.date)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Время
            Row(
              children: [
                Expanded(
                  child: _TimeSelector(
                    label: 'Начало',
                    time: _startTime,
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
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TimeSelector(
                    label: 'Конец',
                    time: _endTime,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() => _endTime = time);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ученик
            studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView.inline(e),
              data: (students) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Student?>(
                      decoration: const InputDecoration(
                        labelText: 'Ученик',
                        prefixIcon: Icon(Icons.person),
                      ),
                      value: _selectedStudent,
                      items: students.map((s) => DropdownMenuItem<Student?>(
                        value: s,
                        child: Text(s.name),
                      )).toList(),
                      onChanged: (student) async {
                        setState(() => _selectedStudent = student);

                        // Автозаполнение из последнего занятия
                        if (student != null) {
                          _autoFillFromLastLesson(student.id);
                        }
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

            // Предмет
            subjectsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (subjects) {
                if (subjects.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<Subject?>(
                  decoration: const InputDecoration(
                    labelText: 'Предмет (необязательно)',
                    prefixIcon: Icon(Icons.book),
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
                    labelText: 'Тип занятия (необязательно)',
                    prefixIcon: Icon(Icons.event_note),
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
                      // Автоматически установить длительность из типа занятия
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

            // Преподаватель
            membersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (members) {
                if (members.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<InstitutionMember?>(
                  decoration: const InputDecoration(
                    labelText: 'Преподаватель (необязательно)',
                    prefixIcon: Icon(Icons.school),
                  ),
                  value: _selectedTeacher,
                  items: [
                    const DropdownMenuItem<InstitutionMember?>(
                      value: null,
                      child: Text('Текущий пользователь'),
                    ),
                    ...members.map((m) => DropdownMenuItem<InstitutionMember?>(
                      value: m,
                      child: Text(m.profile?.fullName ?? m.roleName),
                    )),
                  ],
                  onChanged: (member) async {
                    setState(() => _selectedTeacher = member);

                    // Автовыбор направления если у преподавателя только одно
                    if (member != null) {
                      await _autoSelectSubjectForTeacher(member.userId);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: controllerState.isLoading ? null : _createLesson,
              child: controllerState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Создать занятие'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createLesson() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: пользователь не авторизован'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите ученика'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Время окончания должно быть позже времени начала'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Проверка подписки студента
    final subscriptionsResult = await ref.read(activeSubscriptionsProvider(_selectedStudent!.id).future);

    // Проверка на заморозку
    final isFrozen = subscriptionsResult.any((sub) => sub.status == SubscriptionStatus.frozen);
    if (isFrozen) {
      final shouldContinue = await _showFrozenWarning();
      if (!shouldContinue) return;
    }

    // Проверка на отсутствие активной подписки
    final hasActiveSubscription = subscriptionsResult.any((sub) => sub.isActive);
    if (!hasActiveSubscription && !isFrozen) {
      final shouldContinue = await _showNoSubscriptionWarning();
      if (!shouldContinue) return;
    }

    // Проверка на истекающую подписку
    final expiringSubscription = subscriptionsResult
        .where((sub) => sub.isActive && sub.isExpiringSoon)
        .firstOrNull;
    if (expiringSubscription != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Внимание: абонемент истекает через ${expiringSubscription.daysUntilExpiration} дн.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    final controller = ref.read(lessonControllerProvider.notifier);
    final teacherId = _selectedTeacher?.userId ?? currentUserId;
    final lesson = await controller.create(
      institutionId: widget.institutionId,
      roomId: widget.roomId,
      teacherId: teacherId,
      studentId: _selectedStudent!.id,
      subjectId: _selectedSubject?.id,
      lessonTypeId: _selectedLessonType?.id,
      date: widget.date,
      startTime: _startTime,
      endTime: _endTime,
    );

    if (lesson != null && mounted) {
      // Автоматически создаём привязки ученик-преподаватель и ученик-предмет
      ref.read(studentBindingsControllerProvider.notifier).createBindingsFromLesson(
        studentId: _selectedStudent!.id,
        teacherId: teacherId,
        subjectId: _selectedSubject?.id,
        institutionId: widget.institutionId,
      );

      ref.invalidate(lessonsByRoomProvider(RoomDateParams(widget.roomId, widget.date)));
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

  Future<bool> _showFrozenWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.ac_unit, color: AppColors.info),
            const SizedBox(width: 8),
            const Text('Абонемент заморожен'),
          ],
        ),
        content: const Text(
          'Абонемент этого ученика заморожен. '
          'Вы уверены, что хотите создать занятие?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Создать всё равно'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showNoSubscriptionWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Нет активного абонемента'),
          ],
        ),
        content: const Text(
          'У этого ученика нет активного абонемента или занятия закончились. '
          'Вы уверены, что хотите создать занятие?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Создать всё равно'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Автозаполнение полей из последнего занятия ученика
  Future<void> _autoFillFromLastLesson(String studentId) async {
    try {
      final lastLesson = await ref.read(studentLastLessonProvider(studentId).future);

      if (lastLesson != null && mounted) {
        final subjectsAsync = ref.read(subjectsProvider(widget.institutionId));
        final lessonTypesAsync = ref.read(lessonTypesProvider(widget.institutionId));
        final membersAsync = ref.read(membersProvider(widget.institutionId));

        setState(() {
          // Автозаполнение предмета
          if (lastLesson.subject != null) {
            final subjects = subjectsAsync.valueOrNull ?? [];
            _selectedSubject = subjects.firstWhere(
              (s) => s.id == lastLesson.subjectId,
              orElse: () => lastLesson.subject!,
            );
          }

          // Автозаполнение типа занятия
          if (lastLesson.lessonType != null) {
            final lessonTypes = lessonTypesAsync.valueOrNull ?? [];
            _selectedLessonType = lessonTypes.firstWhere(
              (lt) => lt.id == lastLesson.lessonTypeId,
              orElse: () => lastLesson.lessonType!,
            );

            // Пересчёт времени окончания по умолчанию
            final startMinutes = _startTime.hour * 60 + _startTime.minute;
            final endMinutes = startMinutes + lastLesson.lessonType!.defaultDurationMinutes;
            _endTime = TimeOfDay(
              hour: endMinutes ~/ 60,
              minute: endMinutes % 60,
            );
          }

          // Автозаполнение преподавателя
          final members = membersAsync.valueOrNull ?? [];
          final matchingMember = members.cast<InstitutionMember?>().firstWhere(
            (m) => m?.userId == lastLesson.teacherId,
            orElse: () => null,
          );
          if (matchingMember != null) {
            _selectedTeacher = matchingMember;
          }
        });
      }
    } catch (e) {
      // Ошибка автозаполнения не критична - просто игнорируем
      debugPrint('Ошибка автозаполнения: $e');
    }
  }

  /// Автовыбор направления если у преподавателя только одно
  Future<void> _autoSelectSubjectForTeacher(String userId) async {
    try {
      final teacherSubjects = await ref.read(
        teacherSubjectsProvider(
          TeacherSubjectsParams(
            userId: userId,
            institutionId: widget.institutionId,
          ),
        ).future,
      );

      if (teacherSubjects.length == 1 && mounted) {
        final subjectsAsync = ref.read(subjectsProvider(widget.institutionId));
        final subjects = subjectsAsync.valueOrNull ?? [];
        final matchingSubject = subjects.firstWhere(
          (s) => s.id == teacherSubjects.first.subjectId,
          orElse: () => teacherSubjects.first.subject!,
        );

        setState(() => _selectedSubject = matchingSubject);
      }
    } catch (e) {
      debugPrint('Ошибка автовыбора направления: $e');
    }
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый ученик'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя ученика',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: Validators.required,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Телефон (необязательно)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(studentControllerProvider.notifier);
                final student = await controller.create(
                  institutionId: widget.institutionId,
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                );

                if (student != null && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  final newStudentId = student.id;
                  ref.invalidate(studentsProvider(widget.institutionId));
                  final students = await ref.read(studentsProvider(widget.institutionId).future);
                  final newStudent = students.where((s) => s.id == newStudentId).firstOrNull;
                  if (mounted) {
                    setState(() => _selectedStudent = newStudent);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ученик "${student.name}" добавлен'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
