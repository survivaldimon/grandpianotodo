import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/core/constants/app_sizes.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/core/widgets/loading_indicator.dart';
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
  List<Room>? _localRooms; // Локальный список для сохранения порядка между операциями

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roomsAsync = ref.watch(roomsProvider(widget.institutionId));
    final rooms = roomsAsync.valueOrNull ?? [];
    final hasRooms = rooms.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rooms),
      ),
      floatingActionButton: hasRooms
          ? FloatingActionButton(
              onPressed: () => _showAddRoomDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: Builder(
        builder: (context) {
          final rooms = roomsAsync.valueOrNull;

          // Показываем loading только при первой загрузке
          if (rooms == null) {
            return const LoadingIndicator();
          }

          // Всегда показываем данные (даже если фоном ошибка)
          if (rooms.isEmpty) {
            return EmptyState(
              icon: Icons.door_front_door_outlined,
              title: l10n.noRooms,
              subtitle: l10n.addRoomFirst,
              action: ElevatedButton.icon(
                onPressed: () => _showAddRoomDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.addRoom),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              try {
                ref.invalidate(roomsProvider(widget.institutionId));
                _localRooms = null; // Сбрасываем локальный список при refresh
                await ref.read(roomsProvider(widget.institutionId).future);
              } catch (e) {
                debugPrint('[RoomsScreen] refresh error: $e');
              }
            },
            child: _buildRoomsList(l10n, _localRooms ?? rooms),
          );
        },
      ),
    );
  }

  Widget _buildRoomsList(AppLocalizations l10n, List<Room> rooms) {
    return ReorderableListView.builder(
      padding: AppSizes.paddingAllM,
      itemCount: rooms.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        if (oldIndex == newIndex) return;

        final newRooms = List<Room>.from(rooms);
        final room = newRooms.removeAt(oldIndex);
        newRooms.insert(newIndex, room);

        // Обновляем данные синхронно
        setState(() {
          _localRooms = newRooms;
        });

        // Сохраняем в БД
        ref.read(roomControllerProvider.notifier).reorder(
              newRooms,
              widget.institutionId,
            );
      },
      itemBuilder: (context, index) {
        final room = rooms[index];

        return Slidable(
          key: ValueKey(room.id),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.4,
            children: [
              SlidableAction(
                onPressed: (_) => _showEditDialog(context, room),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: l10n.edit,
              ),
              SlidableAction(
                onPressed: (_) => _showDeleteConfirmation(context, room),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: l10n.delete,
              ),
            ],
          ),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () => _showEditDialog(context, room),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: const Icon(
                  Icons.door_front_door,
                  color: AppColors.primary,
                ),
              ),
              title: Text(room.number != null ? l10n.roomWithNumber(room.number!) : room.name),
              subtitle: room.number != null ? Text(room.name) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showOptions(context, room),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.drag_handle,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context, Room room) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditDialog(context, room);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(context, room);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _EditRoomSheet(
        room: room,
        institutionId: widget.institutionId,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Room room) {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final roomName = room.number != null ? "№${room.number} ${room.name}" : room.name;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteRoomQuestion),
        content: Text(l10n.deleteRoomMessage(roomName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final controller = ref.read(roomControllerProvider.notifier);
              final success = await controller.delete(room.id, widget.institutionId);
              if (success) {
                _localRooms = null; // Сбрасываем локальный список
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.roomDeleted),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
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
    final l10n = AppLocalizations.of(context);

    try {
      final controller = ref.read(roomControllerProvider.notifier);
      final room = await controller.create(
        institutionId: widget.institutionId,
        name: _nameController.text.isEmpty
            ? l10n.roomWithNumber(_numberController.text)
            : _nameController.text.trim(),
        number: _numberController.text.trim(),
      );

      if (room != null && mounted) {
        Navigator.pop(context);
        final displayName = room.number != null ? "№${room.number}" : room.name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.roomCreatedMessage(displayName)),
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
    final l10n = AppLocalizations.of(context);
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
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.newRoom,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.fillRoomData,
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
                    labelText: l10n.roomNumberRequired,
                    hintText: l10n.roomNumberHint,
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) => v == null || v.isEmpty ? l10n.enterRoomNumber : null,
                ),
                const SizedBox(height: 16),

                // Название
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.roomNameOptional,
                    hintText: l10n.roomNameHint,
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
                        : Text(
                            l10n.createRoom,
                            style: const TextStyle(
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
    final l10n = AppLocalizations.of(context);

    try {
      final controller = ref.read(roomControllerProvider.notifier);
      final success = await controller.update(
        widget.room.id,
        institutionId: widget.institutionId,
        name: _nameController.text.isEmpty
            ? l10n.roomWithNumber(_numberController.text)
            : _nameController.text.trim(),
        number: _numberController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.roomUpdated),
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
    final l10n = AppLocalizations.of(context);
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
                        Icons.edit,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.editRoomTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.changeRoomData,
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
                    labelText: l10n.roomNumberRequired,
                    hintText: l10n.roomNumberHint,
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) => v == null || v.isEmpty ? l10n.enterRoomNumber : null,
                ),
                const SizedBox(height: 16),

                // Название
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.roomNameOptional,
                    hintText: l10n.roomNameHint,
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
                        : Text(
                            l10n.save,
                            style: const TextStyle(
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
