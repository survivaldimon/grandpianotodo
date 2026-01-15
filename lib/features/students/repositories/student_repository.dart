import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/student_group.dart';

/// Репозиторий для работы с учениками
class StudentRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Получить список учеников заведения
  Future<List<Student>> getByInstitution(
    String institutionId, {
    bool includeArchived = false,
    bool onlyWithDebt = false,
  }) async {
    try {
      // 1. Загружаем учеников
      var query = _client
          .from('students')
          .select()
          .eq('institution_id', institutionId);

      if (!includeArchived) {
        query = query.isFilter('archived_at', null);
      }

      final data = await query.order('name');

      // 2. Загружаем балансы из VIEW (учитывает семейные подписки и balance_transfer)
      // ВАЖНО: Оборачиваем в try-catch, т.к. VIEW может быть недоступен
      // для пользователей без прав на payments (RLS)
      final balanceMap = <String, Map<String, int>>{};
      try {
        final balancesData = await _client
            .from('student_subscription_summary')
            .select('student_id, active_balance, transfer_balance')
            .eq('institution_id', institutionId);

        // Создаём map для быстрого поиска баланса
        for (final b in balancesData as List) {
          balanceMap[b['student_id'] as String] = {
            'active_balance': (b['active_balance'] as num?)?.toInt() ?? 0,
            'transfer_balance': (b['transfer_balance'] as num?)?.toInt() ?? 0,
          };
        }
      } catch (e) {
        // Если не удалось загрузить балансы, используем данные из students напрямую
        debugPrint('WARN: Не удалось загрузить балансы из VIEW: $e');
      }

      // 3. Объединяем данные
      return (data as List).map((item) {
        final studentId = item['id'] as String;
        final balances = balanceMap[studentId];

        // Подменяем prepaid_lessons_count на актуальный баланс из VIEW
        // legacy_balance теперь хранит transfer_balance для отображения остатка занятий
        final studentData = Map<String, dynamic>.from(item);
        studentData['prepaid_lessons_count'] = balances?['active_balance'] ?? 0;
        studentData['legacy_balance'] = balances?['transfer_balance'] ?? 0;

        return Student.fromJson(studentData);
      }).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки учеников: $e');
    }
  }

  /// Получить ученика по ID
  Future<Student> getById(String id) async {
    try {
      // 1. Загружаем ученика
      final data = await _client
          .from('students')
          .select()
          .eq('id', id)
          .single();

      // 2. Загружаем баланс из VIEW (учитывает семейные подписки и balance_transfer)
      // ВАЖНО: Оборачиваем в try-catch, т.к. VIEW может быть недоступен для некоторых пользователей
      int activeBalance = 0;
      int transferBalance = 0;
      try {
        final balanceData = await _client
            .from('student_subscription_summary')
            .select('active_balance, transfer_balance')
            .eq('student_id', id)
            .maybeSingle();

        activeBalance = (balanceData?['active_balance'] as num?)?.toInt() ?? 0;
        transferBalance = (balanceData?['transfer_balance'] as num?)?.toInt() ?? 0;
      } catch (e) {
        debugPrint('WARN: Не удалось загрузить баланс из VIEW: $e');
      }

      // 3. Подменяем prepaid_lessons_count и legacy_balance (хранит transfer_balance)
      final studentData = Map<String, dynamic>.from(data);
      studentData['prepaid_lessons_count'] = activeBalance;
      studentData['legacy_balance'] = transferBalance;

      return Student.fromJson(studentData);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки ученика: $e');
    }
  }

  /// Создать ученика
  Future<Student> create({
    required String institutionId,
    required String name,
    String? phone,
    String? comment,
    int legacyBalance = 0,
  }) async {
    try {
      final insertData = <String, dynamic>{
        'institution_id': institutionId,
        'name': name,
        'phone': phone,
        'comment': comment,
      };

      // Добавляем legacy_balance только если он > 0
      if (legacyBalance > 0) {
        insertData['legacy_balance'] = legacyBalance;
      }

      final data = await _client
          .from('students')
          .insert(insertData)
          .select()
          .single();

      return Student.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания ученика: $e');
    }
  }

  /// Обновить ученика
  Future<Student> update(
    String id, {
    String? name,
    String? phone,
    String? comment,
    int? legacyBalance,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (comment != null) updates['comment'] = comment;
      if (legacyBalance != null) updates['legacy_balance'] = legacyBalance;

      final data = await _client
          .from('students')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Student.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления ученика: $e');
    }
  }

  /// Архивировать ученика
  Future<void> archive(String id) async {
    try {
      await _client
          .from('students')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации ученика: $e');
    }
  }

  /// Восстановить ученика
  Future<void> restore(String id) async {
    try {
      await _client
          .from('students')
          .update({'archived_at': null})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка восстановления ученика: $e');
    }
  }

  /// Полностью удалить ученика и все его данные
  /// ВАЖНО: Удаляет ВСЁ - занятия, оплаты, подписки, связи
  /// Это действие НЕОБРАТИМО!
  Future<void> deleteCompletely(String id) async {
    try {
      await _client.rpc('delete_student_completely', params: {'p_student_id': id});
    } catch (e) {
      throw DatabaseException('Ошибка удаления ученика: $e');
    }
  }

  /// Списать занятие напрямую (уменьшить prepaid_lessons_count)
  /// Используется когда нет активной подписки — уходит в долг
  Future<void> decrementPrepaidCount(String id) async {
    try {
      await _client.rpc('decrement_student_prepaid', params: {'student_id': id});
    } catch (e) {
      // Fallback: прямое обновление если функция не существует
      try {
        final data = await _client
            .from('students')
            .select('prepaid_lessons_count')
            .eq('id', id)
            .single();
        final currentCount = (data['prepaid_lessons_count'] as num?)?.toInt() ?? 0;
        await _client
            .from('students')
            .update({'prepaid_lessons_count': currentCount - 1})
            .eq('id', id);
      } catch (e2) {
        throw DatabaseException('Ошибка списания занятия: $e2');
      }
    }
  }

  /// Вернуть занятие напрямую (увеличить prepaid_lessons_count)
  /// Используется при отмене завершённого занятия без подписки
  Future<void> incrementPrepaidCount(String id) async {
    try {
      await _client.rpc('increment_student_prepaid', params: {'student_id': id});
    } catch (e) {
      // Fallback: прямое обновление если функция не существует
      try {
        final data = await _client
            .from('students')
            .select('prepaid_lessons_count')
            .eq('id', id)
            .single();
        final currentCount = (data['prepaid_lessons_count'] as num?)?.toInt() ?? 0;
        await _client
            .from('students')
            .update({'prepaid_lessons_count': currentCount + 1})
            .eq('id', id);
      } catch (e2) {
        throw DatabaseException('Ошибка возврата занятия: $e2');
      }
    }
  }

  /// Списать занятие из остатка (legacy_balance)
  /// Используется для переносимых учеников — списывается в первую очередь
  Future<void> decrementLegacyBalance(String id) async {
    try {
      final data = await _client
          .from('students')
          .select('legacy_balance')
          .eq('id', id)
          .single();
      final currentCount = (data['legacy_balance'] as num?)?.toInt() ?? 0;

      if (currentCount > 0) {
        await _client
            .from('students')
            .update({'legacy_balance': currentCount - 1})
            .eq('id', id);
      }
    } catch (e) {
      throw DatabaseException('Ошибка списания из остатка: $e');
    }
  }

  /// Вернуть занятие в остаток (legacy_balance)
  /// Используется при отмене занятия, списанного из остатка
  Future<void> incrementLegacyBalance(String id) async {
    try {
      final data = await _client
          .from('students')
          .select('legacy_balance')
          .eq('id', id)
          .single();
      final currentCount = (data['legacy_balance'] as num?)?.toInt() ?? 0;

      await _client
          .from('students')
          .update({'legacy_balance': currentCount + 1})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка возврата в остаток: $e');
    }
  }

  /// Получить текущий legacy_balance ученика
  Future<int> getLegacyBalance(String id) async {
    try {
      final data = await _client
          .from('students')
          .select('legacy_balance')
          .eq('id', id)
          .single();
      return (data['legacy_balance'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw DatabaseException('Ошибка получения остатка: $e');
    }
  }

  /// Получить имена учеников по списку ID
  /// Используется для отображения объединённых учеников
  Future<List<String>> getNamesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final data = await _client
          .from('students')
          .select('name')
          .inFilter('id', ids);
      return (data as List).map((e) => e['name'] as String).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки имён учеников: $e');
    }
  }

  /// Поиск учеников
  Future<List<Student>> search(String institutionId, String query) async {
    try {
      final data = await _client
          .from('students')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .ilike('name', '%$query%')
          .order('name')
          .limit(20);

      return (data as List).map((item) => Student.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка поиска: $e');
    }
  }

  /// Стрим учеников (realtime)
  /// Слушаем изменения в students И subscriptions (для обновления баланса)
  /// ВАЖНО: Сначала выдаём текущие данные, потом подписываемся на изменения
  Stream<List<Student>> watchByInstitution(String institutionId) {
    final controller = StreamController<List<Student>>.broadcast();
    StreamSubscription? studentsSubscription;
    StreamSubscription? subscriptionsSubscription;

    // Функция для загрузки и отправки данных
    Future<void> loadAndEmit() async {
      try {
        final students = await getByInstitution(institutionId, includeArchived: true);
        if (!controller.isClosed) {
          controller.add(students);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // 1. Сразу загружаем начальные данные
    loadAndEmit();

    // 2. Слушаем students
    studentsSubscription = _client
        .from('students')
        .stream(primaryKey: ['id'])
        .listen((_) => loadAndEmit());

    // 3. Слушаем subscriptions (для обновления баланса при списании занятий)
    subscriptionsSubscription = _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .listen((_) => loadAndEmit());

    // Очистка при закрытии стрима
    controller.onCancel = () {
      studentsSubscription?.cancel();
      subscriptionsSubscription?.cancel();
    };

    return controller.stream;
  }

  // === Группы ===

  /// Получить группы заведения
  Future<List<StudentGroup>> getGroups(String institutionId) async {
    try {
      final data = await _client
          .from('student_groups')
          .select('*, student_group_members(*, students(*))')
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('name');

      return (data as List)
          .map((item) => StudentGroup.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки групп: $e');
    }
  }

  /// Создать группу
  Future<StudentGroup> createGroup({
    required String institutionId,
    required String name,
    String? comment,
    List<String>? studentIds,
  }) async {
    try {
      final groupData = await _client
          .from('student_groups')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'comment': comment,
          })
          .select()
          .single();

      final group = StudentGroup.fromJson(groupData);

      // Добавить участников
      if (studentIds != null && studentIds.isNotEmpty) {
        await _client.from('student_group_members').insert(
          studentIds.map((id) => {
            'group_id': group.id,
            'student_id': id,
          }).toList(),
        );
      }

      return group;
    } catch (e) {
      throw DatabaseException('Ошибка создания группы: $e');
    }
  }

  /// Добавить ученика в группу
  Future<void> addToGroup(String groupId, String studentId) async {
    try {
      await _client.from('student_group_members').insert({
        'group_id': groupId,
        'student_id': studentId,
      });
    } catch (e) {
      throw DatabaseException('Ошибка добавления в группу: $e');
    }
  }

  /// Удалить ученика из группы
  Future<void> removeFromGroup(String groupId, String studentId) async {
    try {
      await _client
          .from('student_group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('student_id', studentId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления из группы: $e');
    }
  }

  /// Объединить несколько учеников в одного нового
  /// Создаёт новую карточку, переносит все данные, архивирует исходных
  Future<Student> mergeStudents({
    required List<String> sourceIds,
    required String institutionId,
    required String newName,
    String? newPhone,
    String? newComment,
  }) async {
    try {
      if (sourceIds.length < 2) {
        throw const DatabaseException('Нужно минимум 2 ученика для объединения');
      }

      final result = await _client.rpc('merge_students', params: {
        'p_source_ids': sourceIds,
        'p_institution_id': institutionId,
        'p_new_name': newName,
        'p_new_phone': newPhone,
        'p_new_comment': newComment,
      });

      final newStudentId = result as String;
      return getById(newStudentId);
    } catch (e) {
      throw DatabaseException('Ошибка объединения учеников: $e');
    }
  }
}
