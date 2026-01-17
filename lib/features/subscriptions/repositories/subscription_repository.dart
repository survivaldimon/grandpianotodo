import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/subscription.dart';

/// Репозиторий для работы с подписками (абонементами)
class SubscriptionRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Получить подписки студента
  Future<List<Subscription>> getByStudent(String studentId) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select('*, payments(*, payment_plans(*))')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      return (data as List).map((item) => Subscription.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки подписок: $e');
    }
  }

  /// Получить активные подписки студента
  Future<List<Subscription>> getActiveByStudent(String studentId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      final data = await _client
          .from('subscriptions')
          .select('*, payments(*, payment_plans(*))')
          .eq('student_id', studentId)
          .gt('lessons_remaining', 0)
          .or('expires_at.gte.$today,is_frozen.eq.true')
          .order('expires_at', ascending: true);

      return (data as List).map((item) => Subscription.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки активных подписок: $e');
    }
  }

  /// Получить подписку по ID
  Future<Subscription> getById(String id) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select('*, students(*), payments(*, payment_plans(*))')
          .eq('id', id)
          .single();

      return Subscription.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки подписки: $e');
    }
  }

  /// Создать подписку (с автоматической привязкой долговых занятий)
  Future<Subscription> create({
    required String institutionId,
    required String studentId,
    String? paymentId,
    required int lessonsTotal,
    required DateTime expiresAt,
    DateTime? startsAt,
  }) async {
    try {
      // Создаём подписку
      final data = await _client
          .from('subscriptions')
          .insert({
            'institution_id': institutionId,
            'student_id': studentId,
            'payment_id': paymentId,
            'lessons_total': lessonsTotal,
            'lessons_remaining': lessonsTotal,
            'starts_at': (startsAt ?? DateTime.now()).toIso8601String().split('T').first,
            'expires_at': expiresAt.toIso8601String().split('T').first,
          })
          .select('*')
          .single();

      final subscription = Subscription.fromJson(data);

      // Привязываем долговые занятия к новой подписке
      final linkedCount = await linkDebtLessons(
        studentId: studentId,
        subscriptionId: subscription.id,
        maxLessons: lessonsTotal,
      );

      // Если привязали занятия - обновляем lessons_remaining
      if (linkedCount > 0) {
        final updatedData = await _client
            .from('subscriptions')
            .update({'lessons_remaining': lessonsTotal - linkedCount})
            .eq('id', subscription.id)
            .select('*')
            .single();

        return Subscription.fromJson(updatedData);
      }

      return subscription;
    } catch (e) {
      throw DatabaseException('Ошибка создания подписки: $e');
    }
  }

  /// Привязать долговые занятия к подписке
  Future<int> linkDebtLessons({
    required String studentId,
    required String subscriptionId,
    required int maxLessons,
  }) async {
    try {
      // Находим занятия без subscription_id (долговые)
      final lessons = await _client
          .from('lessons')
          .select('id')
          .eq('student_id', studentId)
          .isFilter('subscription_id', null)
          .eq('status', 'completed')
          .isFilter('archived_at', null)
          .order('date', ascending: true)
          .order('start_time', ascending: true)
          .limit(maxLessons);

      final lessonsList = lessons as List;
      if (lessonsList.isEmpty) return 0;

      // Привязываем занятия к подписке
      final lessonIds = lessonsList.map((l) => l['id'] as String).toList();

      await _client
          .from('lessons')
          .update({'subscription_id': subscriptionId})
          .inFilter('id', lessonIds);

      // Сбрасываем долг для привязанных занятий
      // Каждое долговое занятие уменьшило prepaid_lessons_count на 1
      // Теперь нужно вернуть эти занятия (увеличить prepaid на количество привязанных)
      for (int i = 0; i < lessonIds.length; i++) {
        await _client.rpc('increment_student_prepaid', params: {'student_id': studentId});
      }

      return lessonIds.length;
    } catch (e) {
      // Если ошибка - продолжаем без привязки
      return 0;
    }
  }

  /// Списать занятие с подписки (выбирает подписку с ближайшим сроком)
  /// Сначала ищет личную подписку, затем семейную через subscription_members
  /// Возвращает обновлённую подписку или null если нет активных подписок
  Future<Subscription?> deductLesson(String studentId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      // 1. Сначала ищем ЛИЧНУЮ подписку (is_family = false)
      final personalData = await _client
          .from('subscriptions')
          .select('*')
          .eq('student_id', studentId)
          .eq('is_family', false)
          .gt('lessons_remaining', 0)
          .gte('expires_at', today)
          .eq('is_frozen', false)
          .order('expires_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (personalData != null) {
        return _deductFromSubscription(Subscription.fromJson(personalData));
      }

      // 2. Если нет личной — ищем СЕМЕЙНУЮ через subscription_members
      final familyMemberships = await _client
          .from('subscription_members')
          .select('subscription_id')
          .eq('student_id', studentId);

      final membershipList = familyMemberships as List;
      if (membershipList.isEmpty) return null;

      final subscriptionIds = membershipList
          .map((m) => m['subscription_id'] as String)
          .toList();

      // Находим активную семейную подписку
      final familyData = await _client
          .from('subscriptions')
          .select('*')
          .inFilter('id', subscriptionIds)
          .eq('is_family', true)
          .gt('lessons_remaining', 0)
          .gte('expires_at', today)
          .eq('is_frozen', false)
          .order('expires_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (familyData == null) return null;

      return _deductFromSubscription(Subscription.fromJson(familyData));
    } catch (e) {
      throw DatabaseException('Ошибка списания занятия: $e');
    }
  }

  /// Внутренний метод для списания занятия (атомарный UPDATE)
  Future<Subscription> _deductFromSubscription(Subscription subscription) async {
    debugPrint('[DEDUCT] Starting deduction from subscription ${subscription.id}');
    debugPrint('[DEDUCT] BEFORE: lessons_remaining = ${subscription.lessonsRemaining}');

    // Используем RPC для атомарного обновления: lessons_remaining = lessons_remaining - 1
    // Это предотвращает race conditions при одновременных запросах
    try {
      final updated = await _client.rpc(
        'deduct_subscription_lesson',
        params: {'p_subscription_id': subscription.id},
      );

      if (updated == null) {
        throw const DatabaseException('Подписка не найдена');
      }

      final result = Subscription.fromJson(updated as Map<String, dynamic>);
      debugPrint('[DEDUCT] RPC SUCCESS: lessons_remaining = ${result.lessonsRemaining}');
      return result;
    } catch (e) {
      // Fallback на прямой UPDATE если функция не существует
      debugPrint('[DEDUCT] RPC failed, using fallback: $e');
      final updated = await _client
          .from('subscriptions')
          .update({'lessons_remaining': subscription.lessonsRemaining - 1})
          .eq('id', subscription.id)
          .select('*')
          .single();

      final result = Subscription.fromJson(updated);
      debugPrint('[DEDUCT] FALLBACK: lessons_remaining = ${result.lessonsRemaining}');
      return result;
    }
  }

  /// Списать занятие и вернуть ID подписки для привязки к занятию
  Future<String?> deductLessonAndGetId(String studentId) async {
    final subscription = await deductLesson(studentId);
    return subscription?.id;
  }

  /// Вернуть занятие на подписку
  Future<Subscription?> returnLesson(String studentId, {String? subscriptionId}) async {
    try {
      // Если указан ID подписки - возвращаем туда
      if (subscriptionId != null) {
        final data = await _client
            .from('subscriptions')
            .select('*')
            .eq('id', subscriptionId)
            .single();

        final subscription = Subscription.fromJson(data);

        final updated = await _client
            .from('subscriptions')
            .update({
              'lessons_remaining': (subscription.lessonsRemaining + 1)
                  .clamp(0, subscription.lessonsTotal)
            })
            .eq('id', subscriptionId)
            .select('*')
            .single();

        return Subscription.fromJson(updated);
      }

      // Иначе возвращаем на последнюю использованную подписку
      final data = await _client
          .from('subscriptions')
          .select('*')
          .eq('student_id', studentId)
          .lt('lessons_remaining', _client.rpc('get_column', params: {'col': 'lessons_total'}))
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      final subscription = Subscription.fromJson(data);

      final updated = await _client
          .from('subscriptions')
          .update({
            'lessons_remaining': (subscription.lessonsRemaining + 1)
                .clamp(0, subscription.lessonsTotal)
          })
          .eq('id', subscription.id)
          .select('*')
          .single();

      return Subscription.fromJson(updated);
    } catch (e) {
      throw DatabaseException('Ошибка возврата занятия: $e');
    }
  }

  /// Заморозить подписку
  Future<Subscription> freeze(String subscriptionId, int days) async {
    try {
      final frozenUntil = DateTime.now().add(Duration(days: days));

      final data = await _client
          .from('subscriptions')
          .update({
            'is_frozen': true,
            'frozen_until': frozenUntil.toIso8601String().split('T').first,
          })
          .eq('id', subscriptionId)
          .select('*')
          .single();

      return Subscription.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка заморозки подписки: $e');
    }
  }

  /// Разморозить подписку (с продлением срока)
  Future<Subscription> unfreeze(String subscriptionId) async {
    try {
      // Получаем текущую подписку
      final current = await getById(subscriptionId);

      if (!current.isFrozen || current.frozenUntil == null) {
        throw const DatabaseException('Подписка не заморожена');
      }

      // Вычисляем сколько дней была заморожена
      final now = DateTime.now();
      final freezeStart = current.updatedAt; // Примерная дата начала заморозки
      final daysFrozen = now.difference(freezeStart).inDays;

      // Продлеваем срок действия
      final newExpiresAt = current.expiresAt.add(Duration(days: daysFrozen));

      final data = await _client
          .from('subscriptions')
          .update({
            'is_frozen': false,
            'frozen_until': null,
            'expires_at': newExpiresAt.toIso8601String().split('T').first,
            'frozen_days_total': current.frozenDaysTotal + daysFrozen,
          })
          .eq('id', subscriptionId)
          .select('*')
          .single();

      return Subscription.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка разморозки подписки: $e');
    }
  }

  /// Продлить срок подписки
  Future<Subscription> extend(String subscriptionId, int days) async {
    try {
      final current = await getById(subscriptionId);
      final newExpiresAt = current.expiresAt.add(Duration(days: days));

      final data = await _client
          .from('subscriptions')
          .update({
            'expires_at': newExpiresAt.toIso8601String().split('T').first,
          })
          .eq('id', subscriptionId)
          .select('*')
          .single();

      return Subscription.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка продления подписки: $e');
    }
  }

  /// Удалить подписку
  Future<void> delete(String subscriptionId) async {
    try {
      await _client.from('subscriptions').delete().eq('id', subscriptionId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления подписки: $e');
    }
  }

  /// Стрим подписок студента (realtime)
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<Subscription>> watchByStudent(String studentId) {
    final controller = StreamController<List<Subscription>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final subscriptions = await getByStudent(studentId);
        if (!controller.isClosed) {
          controller.add(subscriptions);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client.from('subscriptions').stream(primaryKey: ['id']).listen(
      (_) => loadAndEmit(),
      onError: (e) {
        debugPrint('[SubscriptionRepository] watchByStudent error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      },
    );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Получить истекающие подписки заведения (в течение N дней)
  Future<List<Subscription>> getExpiringSoon(
    String institutionId, {
    int days = 7,
  }) async {
    try {
      final today = DateTime.now();
      final futureDate = today.add(Duration(days: days));

      final data = await _client
          .from('subscriptions')
          .select('*, students(*), payments(*, payment_plans(*))')
          .eq('institution_id', institutionId)
          .gt('lessons_remaining', 0)
          .eq('is_frozen', false)
          .gte('expires_at', today.toIso8601String().split('T').first)
          .lte('expires_at', futureDate.toIso8601String().split('T').first)
          .order('expires_at', ascending: true);

      return (data as List).map((item) => Subscription.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки истекающих подписок: $e');
    }
  }

  /// Получить замороженные подписки заведения
  Future<List<Subscription>> getFrozen(String institutionId) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select('*, students(*), payments(*, payment_plans(*))')
          .eq('institution_id', institutionId)
          .eq('is_frozen', true)
          .order('frozen_until', ascending: true);

      return (data as List).map((item) => Subscription.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки замороженных подписок: $e');
    }
  }

  /// Получить сводку по подпискам студента
  Future<StudentSubscriptionSummary?> getStudentSummary(String studentId) async {
    try {
      final data = await _client
          .from('student_subscription_summary')
          .select('*')
          .eq('student_id', studentId)
          .maybeSingle();

      if (data == null) return null;
      return StudentSubscriptionSummary.fromJson(data);
    } catch (e) {
      // View может не существовать - возвращаем null
      return null;
    }
  }

  /// Проверить, есть ли активная подписка у студента
  Future<bool> hasActiveSubscription(String studentId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      final data = await _client
          .from('subscriptions')
          .select('id')
          .eq('student_id', studentId)
          .gt('lessons_remaining', 0)
          .or('expires_at.gte.$today,is_frozen.eq.true')
          .limit(1)
          .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }

  /// Проверить, заморожена ли подписка студента
  Future<bool> isFrozen(String studentId) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select('id')
          .eq('student_id', studentId)
          .eq('is_frozen', true)
          .gt('lessons_remaining', 0)
          .limit(1)
          .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }

  /// Получить активный баланс студента (сумма активных подписок)
  Future<int> getActiveBalance(String studentId) async {
    try {
      final subscriptions = await getByStudentIncludingFamily(studentId);
      final activeSubscriptions = subscriptions.where((sub) => sub.isActive);
      return activeSubscriptions.fold<int>(0, (sum, sub) => sum + sub.lessonsRemaining);
    } catch (e) {
      return 0;
    }
  }

  // ============ СЕМЕЙНЫЕ АБОНЕМЕНТЫ ============

  /// Создать семейный абонемент
  Future<Subscription> createFamily({
    required String institutionId,
    required List<String> studentIds,
    String? paymentId,
    required int lessonsTotal,
    required DateTime expiresAt,
    DateTime? startsAt,
  }) async {
    try {
      if (studentIds.length < 2) {
        throw const DatabaseException('Семейный абонемент требует минимум 2 ученика');
      }

      // Создаём подписку с is_family = true
      final data = await _client
          .from('subscriptions')
          .insert({
            'institution_id': institutionId,
            'student_id': studentIds.first, // Первый ученик как "основной"
            'payment_id': paymentId,
            'lessons_total': lessonsTotal,
            'lessons_remaining': lessonsTotal,
            'starts_at': (startsAt ?? DateTime.now()).toIso8601String().split('T').first,
            'expires_at': expiresAt.toIso8601String().split('T').first,
            'is_family': true,
          })
          .select('*')
          .single();

      final subscription = Subscription.fromJson(data);

      // Добавляем всех участников в subscription_members
      final memberInserts = studentIds.map((sid) => {
        'subscription_id': subscription.id,
        'student_id': sid,
      }).toList();

      await _client.from('subscription_members').insert(memberInserts);

      // Привязываем долговые занятия всех участников
      int totalLinked = 0;
      for (final studentId in studentIds) {
        if (totalLinked >= lessonsTotal) break;
        final linked = await linkDebtLessons(
          studentId: studentId,
          subscriptionId: subscription.id,
          maxLessons: lessonsTotal - totalLinked,
        );
        totalLinked += linked;
      }

      // Обновляем lessons_remaining если привязали занятия
      if (totalLinked > 0) {
        final updatedData = await _client
            .from('subscriptions')
            .update({'lessons_remaining': lessonsTotal - totalLinked})
            .eq('id', subscription.id)
            .select('*, subscription_members(*, students(*))')
            .single();

        return Subscription.fromJson(updatedData);
      }

      // Возвращаем подписку с участниками
      return await getByIdWithMembers(subscription.id);
    } catch (e) {
      throw DatabaseException('Ошибка создания семейного абонемента: $e');
    }
  }

  /// Получить подписку по ID с участниками
  Future<Subscription> getByIdWithMembers(String id) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select('*, students(*), payments(*, payment_plans(*)), subscription_members(*, students(*))')
          .eq('id', id)
          .single();

      return Subscription.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки подписки: $e');
    }
  }

  /// Получить подписки студента включая семейные
  Future<List<Subscription>> getByStudentIncludingFamily(String studentId) async {
    try {
      // 1. Личные подписки
      final personalData = await _client
          .from('subscriptions')
          .select('*, payments(*, payment_plans(*)), subscription_members(*, students(*))')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      final result = (personalData as List)
          .map((item) => Subscription.fromJson(item))
          .toList();

      // 2. Семейные подписки через subscription_members
      final familyMemberships = await _client
          .from('subscription_members')
          .select('subscription_id')
          .eq('student_id', studentId);

      final membershipList = familyMemberships as List;
      if (membershipList.isNotEmpty) {
        final familySubscriptionIds = membershipList
            .map((m) => m['subscription_id'] as String)
            .toSet(); // Set для исключения дубликатов

        // Исключаем ID которые уже есть в личных
        final personalIds = result.map((s) => s.id).toSet();
        final uniqueFamilyIds = familySubscriptionIds.difference(personalIds);

        if (uniqueFamilyIds.isNotEmpty) {
          final familyData = await _client
              .from('subscriptions')
              .select('*, payments(*, payment_plans(*)), subscription_members(*, students(*))')
              .inFilter('id', uniqueFamilyIds.toList())
              .order('created_at', ascending: false);

          result.addAll((familyData as List)
              .map((item) => Subscription.fromJson(item)));
        }
      }

      return result;
    } catch (e) {
      throw DatabaseException('Ошибка загрузки подписок: $e');
    }
  }

  /// Получить активные подписки студента включая семейные
  Future<List<Subscription>> getActiveByStudentIncludingFamily(String studentId) async {
    try {
      final allSubscriptions = await getByStudentIncludingFamily(studentId);
      return allSubscriptions.where((sub) => sub.isActive).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки активных подписок: $e');
    }
  }

  /// Получить участников семейного абонемента
  Future<List<SubscriptionMember>> getFamilyMembers(String subscriptionId) async {
    try {
      final data = await _client
          .from('subscription_members')
          .select('*, students(*)')
          .eq('subscription_id', subscriptionId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((m) => SubscriptionMember.fromJson(m))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки участников: $e');
    }
  }

  /// Добавить участника в семейный абонемент
  Future<void> addFamilyMember(String subscriptionId, String studentId) async {
    try {
      await _client.from('subscription_members').insert({
        'subscription_id': subscriptionId,
        'student_id': studentId,
      });
    } catch (e) {
      throw DatabaseException('Ошибка добавления участника: $e');
    }
  }

  /// Удалить участника из семейного абонемента
  Future<void> removeFamilyMember(String subscriptionId, String studentId) async {
    try {
      // Проверяем что останется минимум 2 участника
      final members = await getFamilyMembers(subscriptionId);
      if (members.length <= 2) {
        throw const DatabaseException('В семейном абонементе должно быть минимум 2 участника');
      }

      await _client
          .from('subscription_members')
          .delete()
          .eq('subscription_id', subscriptionId)
          .eq('student_id', studentId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления участника: $e');
    }
  }

  /// Обновить участников семейного абонемента
  /// Полностью заменяет список участников новым
  Future<Subscription> updateSubscriptionMembers({
    required String subscriptionId,
    required List<String> studentIds,
  }) async {
    if (studentIds.length < 2) {
      throw const DatabaseException('В семейном абонементе должно быть минимум 2 участника');
    }

    try {
      // 1. Удаляем всех текущих участников
      await _client
          .from('subscription_members')
          .delete()
          .eq('subscription_id', subscriptionId);

      // 2. Добавляем новых участников
      final memberInserts = studentIds.map((sid) => {
        'subscription_id': subscriptionId,
        'student_id': sid,
      }).toList();

      await _client.from('subscription_members').insert(memberInserts);

      // 3. Возвращаем обновлённую подписку
      return await getByIdWithMembers(subscriptionId);
    } catch (e) {
      throw DatabaseException('Ошибка обновления участников: $e');
    }
  }

  /// Стрим подписок студента включая семейные (realtime)
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<List<Subscription>> watchByStudentIncludingFamily(String studentId) {
    final controller = StreamController<List<Subscription>>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final subscriptions = await getByStudentIncludingFamily(studentId);
        if (!controller.isClosed) {
          controller.add(subscriptions);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    loadAndEmit();

    final subscription = _client.from('subscriptions').stream(primaryKey: ['id']).listen(
      (_) => loadAndEmit(),
      onError: (e) {
        debugPrint('[SubscriptionRepository] watchByStudentIncludingFamily error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      },
    );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }
}
