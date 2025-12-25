import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

/// Репозиторий для работы с оплатами
class PaymentRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Получить оплаты за период
  Future<List<Payment>> getByPeriod(
    String institutionId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from('payments')
          .select('*, students(*), payment_plans(*)')
          .eq('institution_id', institutionId)
          .gte('paid_at', from.toIso8601String())
          .lte('paid_at', to.toIso8601String())
          .order('paid_at', ascending: false);

      return (data as List).map((item) => Payment.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки оплат: $e');
    }
  }

  /// Получить оплаты ученика
  Future<List<Payment>> getByStudent(String studentId) async {
    try {
      final data = await _client
          .from('payments')
          .select('*, payment_plans(*)')
          .eq('student_id', studentId)
          .order('paid_at', ascending: false);

      return (data as List).map((item) => Payment.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки оплат ученика: $e');
    }
  }

  /// Создать оплату
  /// Баланс ученика обновляется автоматически триггером в БД
  Future<Payment> create({
    required String institutionId,
    required String studentId,
    String? paymentPlanId,
    required double amount,
    required int lessonsCount,
    DateTime? paidAt,
    String? comment,
  }) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('payments')
          .insert({
            'institution_id': institutionId,
            'student_id': studentId,
            'payment_plan_id': paymentPlanId,
            'amount': amount,
            'lessons_count': lessonsCount,
            'paid_at': (paidAt ?? DateTime.now()).toIso8601String(),
            'recorded_by': _userId,
            'comment': comment,
          })
          .select('*, students(*), payment_plans(*)')
          .single();

      return Payment.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания оплаты: $e');
    }
  }

  /// Создать корректировку
  Future<Payment> createCorrection({
    required String institutionId,
    required String studentId,
    required double amount,
    required int lessonsCount,
    required String reason,
    String? comment,
  }) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('payments')
          .insert({
            'institution_id': institutionId,
            'student_id': studentId,
            'amount': amount,
            'lessons_count': lessonsCount,
            'is_correction': true,
            'correction_reason': reason,
            'paid_at': DateTime.now().toIso8601String(),
            'recorded_by': _userId,
            'comment': comment,
          })
          .select('*, students(*)')
          .single();

      return Payment.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания корректировки: $e');
    }
  }

  /// Получить сумму оплат за период
  Future<double> getTotalForPeriod(
    String institutionId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from('payments')
          .select('amount')
          .eq('institution_id', institutionId)
          .gte('paid_at', from.toIso8601String())
          .lte('paid_at', to.toIso8601String());

      double total = 0;
      for (final item in data as List) {
        total += (item['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      throw DatabaseException('Ошибка расчёта суммы: $e');
    }
  }

  /// Получить все оплаты заведения
  Future<List<Payment>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('payments')
          .select('*, students(*), payment_plans(*)')
          .eq('institution_id', institutionId)
          .order('paid_at', ascending: false);

      return (data as List).map((item) => Payment.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки оплат: $e');
    }
  }

  /// Стрим оплат (realtime)
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  Stream<List<Payment>> watchByInstitution(String institutionId) async* {
    await for (final _ in _client.from('payments').stream(primaryKey: ['id'])) {
      // При любом изменении загружаем актуальные данные
      final payments = await getByInstitution(institutionId);
      yield payments;
    }
  }

  // === Тарифы ===

  /// Получить тарифы заведения
  Future<List<PaymentPlan>> getPlans(String institutionId) async {
    try {
      final data = await _client
          .from('payment_plans')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('lessons_count');

      return (data as List)
          .map((item) => PaymentPlan.fromJson(item))
          .toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки тарифов: $e');
    }
  }

  /// Создать тариф
  Future<PaymentPlan> createPlan({
    required String institutionId,
    required String name,
    required double price,
    required int lessonsCount,
    int validityDays = 30,
  }) async {
    try {
      final data = await _client
          .from('payment_plans')
          .insert({
            'institution_id': institutionId,
            'name': name,
            'price': price,
            'lessons_count': lessonsCount,
            'validity_days': validityDays,
          })
          .select()
          .single();

      return PaymentPlan.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания тарифа: $e');
    }
  }

  /// Обновить тариф
  Future<PaymentPlan> updatePlan(
    String id, {
    String? name,
    double? price,
    int? lessonsCount,
    int? validityDays,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (price != null) updates['price'] = price;
      if (lessonsCount != null) updates['lessons_count'] = lessonsCount;
      if (validityDays != null) updates['validity_days'] = validityDays;

      final data = await _client
          .from('payment_plans')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return PaymentPlan.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления тарифа: $e');
    }
  }

  /// Архивировать тариф
  Future<void> archivePlan(String id) async {
    try {
      await _client
          .from('payment_plans')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивации тарифа: $e');
    }
  }

  // === Редактирование и удаление оплат ===

  /// Обновить оплату
  /// Баланс ученика корректируется автоматически триггером в БД
  Future<Payment> update(
    String paymentId, {
    required String studentId,
    required int oldLessonsCount,
    double? amount,
    int? lessonsCount,
    String? comment,
  }) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      final updates = <String, dynamic>{};
      if (amount != null) updates['amount'] = amount;
      if (lessonsCount != null) updates['lessons_count'] = lessonsCount;
      if (comment != null) updates['comment'] = comment;

      final data = await _client
          .from('payments')
          .update(updates)
          .eq('id', paymentId)
          .select('*, students(*), payment_plans(*)')
          .single();

      return Payment.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления оплаты: $e');
    }
  }

  /// Удалить оплату
  /// Баланс ученика возвращается автоматически триггером в БД
  Future<void> delete(String paymentId) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      await _client.from('payments').delete().eq('id', paymentId);
    } catch (e) {
      throw DatabaseException('Ошибка удаления оплаты: $e');
    }
  }

  /// Найти оплату по ID занятия (ищет по comment с префиксом lesson:)
  Future<Payment?> findByLessonId(String lessonId) async {
    try {
      final data = await _client
          .from('payments')
          .select('*, students(*), payment_plans(*)')
          .like('comment', 'lesson:$lessonId|%')
          .maybeSingle();

      if (data == null) return null;
      return Payment.fromJson(data);
    } catch (e) {
      return null; // Не выбрасываем ошибку, просто возвращаем null
    }
  }

  /// Удалить оплату по ID занятия
  Future<bool> deleteByLessonId(String lessonId) async {
    if (_userId == null) throw AuthAppException('Пользователь не авторизован');

    try {
      await _client
          .from('payments')
          .delete()
          .like('comment', 'lesson:$lessonId|%');
      return true;
    } catch (e) {
      return false;
    }
  }
}
