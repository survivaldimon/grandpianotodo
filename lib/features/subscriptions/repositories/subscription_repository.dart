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
          .select('*')
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
          .select('*')
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
          .select('*, students(*)')
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

      return lessonIds.length;
    } catch (e) {
      // Если ошибка - продолжаем без привязки
      return 0;
    }
  }

  /// Списать занятие с подписки (выбирает подписку с ближайшим сроком)
  /// Возвращает обновлённую подписку или null если нет активных подписок
  Future<Subscription?> deductLesson(String studentId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      // Находим активную подписку с ближайшим сроком истечения
      final data = await _client
          .from('subscriptions')
          .select('*')
          .eq('student_id', studentId)
          .gt('lessons_remaining', 0)
          .gte('expires_at', today)
          .eq('is_frozen', false)
          .order('expires_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      final subscription = Subscription.fromJson(data);

      // Списываем занятие
      final updated = await _client
          .from('subscriptions')
          .update({'lessons_remaining': subscription.lessonsRemaining - 1})
          .eq('id', subscription.id)
          .select('*')
          .single();

      return Subscription.fromJson(updated);
    } catch (e) {
      throw DatabaseException('Ошибка списания занятия: $e');
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
        throw DatabaseException('Подписка не заморожена');
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
  Stream<List<Subscription>> watchByStudent(String studentId) {
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .order('created_at', ascending: false)
        .map((data) => data.map((item) => Subscription.fromJson(item)).toList());
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
          .select('*, students(*)')
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
          .select('*, students(*)')
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
      final subscriptions = await getActiveByStudent(studentId);
      return subscriptions.fold<int>(0, (sum, sub) => sum + sub.lessonsRemaining);
    } catch (e) {
      return 0;
    }
  }
}
