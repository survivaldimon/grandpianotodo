import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabinet/core/constants/app_strings.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
import 'package:kabinet/core/widgets/error_view.dart';
import 'package:kabinet/core/widgets/empty_state.dart';
import 'package:kabinet/features/rooms/providers/room_provider.dart';
import 'package:kabinet/shared/models/room.dart';

/// Экран списка кабинетов
class RoomsScreen extends ConsumerStatefulWidget {
  final String institutionId;

  const RoomsScreen({super.key, required this.institutionId});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final rooms = roomsAsync.valueOrNull ?? [];
    final hasRooms = rooms.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.rooms),
        actions: [
          if (!_isEditMode && hasRooms)
            IconButton(
              icon: const Icon(Icons.reorder),
              tooltip: 'Изменить порядок',
              onPressed: () {
                setState(() => _isEditMode = true);
              },
            ),
          if (_isEditMode)
            TextButton(
              onPressed: () {
                setState(() => _isEditMode = false);
              },
              child: const Text('Готово'),
            ),
        ],
      ),
      floatingActionButton: !_isEditMode && hasRooms
          ? FloatingActionButton(
              onPressed: () => _showAddRoomDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: roomsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView.fromException(
          error,
          onRetry: () => ref.invalidate(roomsProvider(widget.institutionId)),
        ),
        data: (rooms) {
          if (rooms.isEmpty) {
            return EmptyState(
              icon: Icons.door_front_door_outlined,
              title: 'Нет кабинетов',
              subtitle: 'Добавьте первый кабинет',
              action: ElevatedButton.icon(
                onPressed: () => _showAddRoomDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Добавить кабинет'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(roomsProvider(widget.institutionId));
              await ref.read(roomsProvider(widget.institutionId).future);
            },
            child: _isEditMode
                ? _buildReorderableList(rooms)
                : _buildNormalList(rooms),
          );
        },
      ),
    );
  }

  Widget _buildNormalList(List<Room> rooms) {
    return ListView.builder(
      padding: AppSizes.paddingAllM,
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _RoomCard(
          room: room,
          institutionId: widget.institutionId,
          onTap: () {
            context.go('/institutions/${widget.institutionId}/rooms/${room.id}/schedule');
          },
        );
      },
    );
  }

  Widget _buildReorderableList(List<Room> rooms) {
    return ListView.builder(
      padding: AppSizes.paddingAllM,
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final isFirst = index == 0;
        final isLast = index == rooms.length - 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.drag_handle, color: AppColors.textTertiary),
            title: Text(room.number != null ? 'Кабинет ${room.number}' : room.name),
            subtitle: room.number != null ? Text(room.name) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    color: isFirst ? AppColors.textTertiary : AppColors.primary,
                  ),
                  onPressed: isFirst
                      ? null
                      : () async {
                          await ref.read(roomControllerProvider.notifier).moveUp(
                                room,
                                rooms,
                                widget.institutionId,
                              );
                        },
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    color: isLast ? AppColors.textTertiary : AppColors.primary,
                  ),
                  onPressed: isLast
                      ? null
                      : () async {
                          await ref.read(roomControllerProvider.notifier).moveDown(
                                room,
                                rooms,
                                widget.institutionId,
                              );
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddRoomDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddRoomSheet(
        institutionId: widget.institutionId,
      ),
    );
  }
}

/// Форма создания нового кабинета
class _AddRoomSheet extends ConsumerStatefulWidget {
  final String institutionId;

  const _AddRoomSheet({required this.institutionId});

  @override
  ConsumerState<_AddRoomSheet> createState() => _AddRoomSheetState();
}

class _AddRoomSheetState extends ConsumerState<_AddRoomSheet> {
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Кабинет "${room.number != null ? "№${room.number}" : room.name}" создан'),
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
                        Icons.meeting_room,
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
                            'Новый кабинет',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Заполните данные кабинета',
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
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) => v == null || v.isEmpty ? 'Введите номер кабинета' : null,
                ),
                const SizedBox(height: 16),

                // Название
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
                    fillColor: Colors.grey[50],
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

class _RoomCard extends ConsumerWidget {
  final Room room;
  final String institutionId;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.institutionId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          child: const Icon(
            Icons.door_front_door,
            color: AppColors.primary,
          ),
        ),
        title: Text(room.number != null ? 'Кабинет ${room.number}' : room.name),
        subtitle: room.number != null ? Text(room.name) : null,
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showOptions(context, ref),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Открыть расписание'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _EditRoomSheet(
        room: room,
        institutionId: institutionId,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить кабинет?'),
        content: Text(
          'Кабинет "${room.number != null ? "№${room.number} ${room.name}" : room.name}" '
          'будет удалён. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = ref.read(roomControllerProvider.notifier);
              final success = await controller.delete(room.id, institutionId);
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Кабинет удалён'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

/// Форма редактирования кабинета
class _EditRoomSheet extends ConsumerStatefulWidget {
  final Room room;
  final String institutionId;

  const _EditRoomSheet({
    required this.room,
    required this.institutionId,
  });

  @override
  ConsumerState<_EditRoomSheet> createState() => _EditRoomSheetState();
}

class _EditRoomSheetState extends ConsumerState<_EditRoomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.room.number ?? '');
    _nameController = TextEditingController(text: widget.room.name);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(roomControllerProvider.notifier);
      final success = await controller.update(
        widget.room.id,
        institutionId: widget.institutionId,
        name: _nameController.text.isEmpty
            ? 'Кабинет ${_numberController.text}'
            : _nameController.text.trim(),
        number: _numberController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Кабинет обновлён'),
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
                        Icons.edit,
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
                            'Редактировать кабинет',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Измените данные кабинета',
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
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) => v == null || v.isEmpty ? 'Введите номер кабинета' : null,
                ),
                const SizedBox(height: 16),

                // Название
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
                    fillColor: Colors.grey[50],
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 28),

                // Кнопка сохранения
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateRoom,
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
                            'Сохранить',
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
