import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/payment.dart';

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
      // Добавляем subscriptions с subscription_members для семейных абонементов
      final data = await _client
          .from('payments')
          .select('*, students(*), payment_plans(*), subscriptions(*, subscription_members(*, students(*)))')
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
  /// Если hasSubscription=true — триггер пропускает запись (занятия через subscription)
  Future<Payment> create({
    required String institutionId,
    required String studentId,
    String? paymentPlanId,
    required double amount,
    required int lessonsCount,
    String paymentMethod = 'cash',
    bool hasSubscription = false,
    DateTime? paidAt,
    String? comment,
  }) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('payments')
          .insert({
            'institution_id': institutionId,
            'student_id': studentId,
            'payment_plan_id': paymentPlanId,
            'amount': amount,
            'lessons_count': lessonsCount,
            'payment_method': paymentMethod,
            'has_subscription': hasSubscription,
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
    String paymentMethod = 'cash',
    String? comment,
  }) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

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
            'payment_method': paymentMethod,
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
      // Добавляем subscriptions с subscription_members для семейных абонементов
      final data = await _client
          .from('payments')
          .select('*, students(*), payment_plans(*), subscriptions(*, subscription_members(*, students(*)))')
          .eq('institution_id', institutionId)
          .order('paid_at', ascending: false);

      return (data as List).map((item) => Payment.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки оплат: $e');
    }
  }

  /// Стрим оплат (realtime)
  /// Слушаем ВСЕ изменения без фильтра для корректной работы DELETE событий
  /// ВАЖНО: Сначала выдаём текущие данные, потом подписываемся на изменения
  /// Это предотвращает бесконечную загрузку при возврате из фона
  Stream<List<Payment>> watchByInstitution(String institutionId) async* {
    // 1. Сразу выдаём текущие данные (без ожидания Realtime)
    yield await getByInstitution(institutionId);

    // 2. Подписываемся на изменения
    await for (final _ in _client.from('payments').stream(primaryKey: ['id'])) {
      // При любом изменении загружаем актуальные данные
      final payments = await getByInstitution(institutionId);
      yield payments;
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
    String? paymentMethod,
    DateTime? paidAt,
    String? comment,
  }) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      final updates = <String, dynamic>{};
      if (amount != null) updates['amount'] = amount;
      if (lessonsCount != null) updates['lessons_count'] = lessonsCount;
      if (paymentMethod != null) updates['payment_method'] = paymentMethod;
      if (paidAt != null) updates['paid_at'] = paidAt.toIso8601String();
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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

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
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

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

  // === Balance Transfer (Перенос баланса / Остаток занятий) ===

  /// Создать запись переноса баланса (остаток занятий)
  Future<Payment> createBalanceTransfer({
    required String institutionId,
    required String studentId,
    required int lessonsCount,
    String? comment,
  }) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('payments')
          .insert({
            'institution_id': institutionId,
            'student_id': studentId,
            'amount': 0, // Перенос баланса — без денег
            'lessons_count': lessonsCount,
            'is_balance_transfer': true,
            'transfer_lessons_remaining': lessonsCount,
            'payment_method': 'cash',
            'paid_at': DateTime.now().toIso8601String(),
            'recorded_by': _userId,
            'comment': comment,
          })
          .select('*, students(*)')
          .single();

      return Payment.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания переноса баланса: $e');
    }
  }

  /// Получить активные переносы баланса для ученика
  Future<List<Payment>> getActiveBalanceTransfers(String studentId) async {
    try {
      final data = await _client
          .from('payments')
          .select('*')
          .eq('student_id', studentId)
          .eq('is_balance_transfer', true)
          .gt('transfer_lessons_remaining', 0)
          .order('paid_at', ascending: true);

      return (data as List).map((item) => Payment.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки переносов баланса: $e');
    }
  }

  /// Списать 1 занятие с переноса баланса (вызывает RPC функцию)
  /// Возвращает payment_id с которого списано, или null если нет остатка
  Future<String?> deductBalanceTransfer(String studentId) async {
    try {
      final result = await _client.rpc(
        'deduct_balance_transfer',
        params: {'p_student_id': studentId},
      );
      return result as String?;
    } catch (e) {
      // Если ошибка — нет активных переносов
      return null;
    }
  }

  /// Вернуть 1 занятие на перенос баланса (вызывает RPC функцию)
  Future<void> returnBalanceTransferLesson(String paymentId) async {
    try {
      await _client.rpc(
        'return_balance_transfer_lesson',
        params: {'p_payment_id': paymentId},
      );
    } catch (e) {
      throw DatabaseException('Ошибка возврата занятия на перенос: $e');
    }
  }

  /// Обновить количество занятий в переносе баланса
  Future<Payment> updateBalanceTransfer(
    String paymentId, {
    required int lessonsCount,
    String? comment,
  }) async {
    if (_userId == null) throw const AuthAppException('Пользователь не авторизован');

    try {
      final data = await _client
          .from('payments')
          .update({
            'lessons_count': lessonsCount,
            'transfer_lessons_remaining': lessonsCount,
            if (comment != null) 'comment': comment,
          })
          .eq('id', paymentId)
          .eq('is_balance_transfer', true)
          .select('*, students(*)')
          .single();

      return Payment.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка обновления переноса баланса: $e');
    }
  }
}
