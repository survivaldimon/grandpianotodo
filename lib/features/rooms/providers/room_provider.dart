import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabinet/features/rooms/repositories/room_repository.dart';
import 'package:kabinet/shared/models/room.dart';

/// Провайдер репозитория кабинетов
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

/// Провайдер списка кабинетов заведения (realtime)
final roomsProvider =
    StreamProvider.family<List<Room>, String>((ref, institutionId) {
  final repo = ref.watch(roomRepositoryProvider);
  return repo.watchByInstitution(institutionId);
});

/// Провайдер кабинета по ID
final roomProvider = FutureProvider.family<Room, String>((ref, id) async {
  final repo = ref.watch(roomRepositoryProvider);
  return repo.getById(id);
});

/// Стрим кабинетов (realtime)
final roomsStreamProvider =
    StreamProvider.family<List<Room>, String>((ref, institutionId) {
  final repo = ref.watch(roomRepositoryProvider);
  return repo.watchByInstitution(institutionId);
});

/// Контроллер кабинетов
class RoomController extends StateNotifier<AsyncValue<void>> {
  final RoomRepository _repo;
  final Ref _ref;

  RoomController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<Room?> create({
    required String institutionId,
    required String name,
    String? number,
  }) async {
    state = const AsyncValue.loading();
    try {
      final room = await _repo.create(
        institutionId: institutionId,
        name: name,
        number: number,
      );
      _ref.invalidate(roomsProvider(institutionId));
      state = const AsyncValue.data(null);
      return room;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> update(
    String id, {
    required String institutionId,
    String? name,
    String? number,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(id, name: name, number: number);
      _ref.invalidate(roomsProvider(institutionId));
      _ref.invalidate(roomProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      _ref.invalidate(roomsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> archive(String id, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archive(id);
      _ref.invalidate(roomsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> reorder(List<Room> rooms, String institutionId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reorder(rooms);
      _ref.invalidate(roomsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> moveUp(Room room, List<Room> rooms, String institutionId) async {
    final index = rooms.indexWhere((r) => r.id == room.id);
    if (index <= 0) return false;

    state = const AsyncValue.loading();
    try {
      // Меняем местами элементы в списке
      final newList = List<Room>.from(rooms);
      final temp = newList[index];
      newList[index] = newList[index - 1];
      newList[index - 1] = temp;
      // Обновляем sort_order для всех
      await _repo.reorder(newList);
      _ref.invalidate(roomsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> moveDown(Room room, List<Room> rooms, String institutionId) async {
    final index = rooms.indexWhere((r) => r.id == room.id);
    if (index < 0 || index >= rooms.length - 1) return false;

    state = const AsyncValue.loading();
    try {
      // Меняем местами элементы в списке
      final newList = List<Room>.from(rooms);
      final temp = newList[index];
      newList[index] = newList[index + 1];
      newList[index + 1] = temp;
      // Обновляем sort_order для всех
      await _repo.reorder(newList);
      _ref.invalidate(roomsProvider(institutionId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Провайдер контроллера кабинетов
final roomControllerProvider =
    StateNotifierProvider<RoomController, AsyncValue<void>>((ref) {
  final repo = ref.watch(roomRepositoryProvider);
  return RoomController(repo, ref);
});
