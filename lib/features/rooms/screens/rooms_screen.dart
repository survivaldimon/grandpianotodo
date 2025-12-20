import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.rooms),
        actions: [
          if (!_isEditMode)
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
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddRoomDialog(context, ref),
            ),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: error.toString(),
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
            child: Column(
              children: [
                // Кнопка "Все кабинеты"
                if (!_isEditMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      color: AppColors.primary,
                      child: ListTile(
                        leading: const Icon(Icons.grid_view, color: Colors.white),
                        title: const Text(
                          'Все кабинеты',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Расписание всех кабинетов',
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white),
                        onTap: () {
                          context.go('/institutions/${widget.institutionId}/rooms/all');
                        },
                      ),
                    ),
                  ),
                // Список кабинетов
                Expanded(
                  child: _isEditMode
                      ? _buildReorderableList(rooms)
                      : _buildNormalList(rooms),
                ),
              ],
            ),
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
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый кабинет'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Номер кабинета',
                  hintText: 'Например: 101',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Введите номер' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Фортепианный',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final controller = ref.read(roomControllerProvider.notifier);
                final room = await controller.create(
                  institutionId: widget.institutionId,
                  name: nameController.text.isEmpty
                      ? 'Кабинет ${numberController.text}'
                      : nameController.text,
                  number: numberController.text,
                );
                if (room != null && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
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
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('Архивировать', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _showArchiveConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: room.name);
    final numberController = TextEditingController(text: room.number ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактировать кабинет'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Номер кабинета',
                  hintText: 'Например: 101',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Введите номер' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: Фортепианный',
                ),
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
                final controller = ref.read(roomControllerProvider.notifier);
                final success = await controller.update(
                  room.id,
                  institutionId: institutionId,
                  name: nameController.text.isEmpty
                      ? 'Кабинет ${numberController.text}'
                      : nameController.text,
                  number: numberController.text,
                );
                if (success && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Кабинет обновлён')),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(BuildContext context, WidgetRef ref) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Архивировать кабинет?'),
        content: Text(
          'Кабинет "${room.number != null ? "№${room.number} ${room.name}" : room.name}" '
          'будет перемещён в архив. Занятия в этом кабинете останутся в истории.',
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
              final success = await controller.archive(room.id, institutionId);
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Кабинет архивирован'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Архивировать'),
          ),
        ],
      ),
    );
  }
}
