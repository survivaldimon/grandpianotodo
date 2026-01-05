import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';
import 'package:kabinet/shared/models/payment_plan.dart';

/// Репозиторий для работы с тарифами оплаты
class PaymentPlanRepository {
  final _client = SupabaseConfig.client;

  /// Получить все тарифы заведения
  Future<List<PaymentPlan>> getByInstitution(String institutionId) async {
    try {
      final data = await _client
          .from('payment_plans')
          .select()
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .order('lessons_count');

      return (data as List).map((item) => PaymentPlan.fromJson(item)).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки тарифов: $e');
    }
  }

  /// Получить тариф по ID
  Future<PaymentPlan?> getById(String id) async {
    try {
      final data = await _client
          .from('payment_plans')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return PaymentPlan.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки тарифа: $e');
    }
  }

  /// Создать новый тариф
  Future<PaymentPlan> create({
    required String institutionId,
    required String name,
    required double price,
    required int lessonsCount,
    int validityDays = 30,
    String? color,
  }) async {
    try {
      final insertData = <String, dynamic>{
        'institution_id': institutionId,
        'name': name,
        'price': price,
        'lessons_count': lessonsCount,
        'validity_days': validityDays,
      };
      if (color != null) insertData['color'] = color;

      final data = await _client
          .from('payment_plans')
          .insert(insertData)
          .select()
          .single();

      return PaymentPlan.fromJson(data);
    } catch (e) {
      throw DatabaseException('Ошибка создания тарифа: $e');
    }
  }

  /// Обновить тариф
  Future<PaymentPlan> update({
    required String id,
    String? name,
    double? price,
    int? lessonsCount,
    int? validityDays,
    String? color,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (price != null) updates['price'] = price;
      if (lessonsCount != null) updates['lessons_count'] = lessonsCount;
      if (validityDays != null) updates['validity_days'] = validityDays;
      if (color != null) updates['color'] = color;

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
  Future<void> archive(String id) async {
    try {
      await _client
          .from('payment_plans')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка архивирования тарифа: $e');
    }
  }

  /// Удалить тариф навсегда
  Future<void> delete(String id) async {
    try {
      await _client.from('payment_plans').delete().eq('id', id);
    } catch (e) {
      throw DatabaseException('Ошибка удаления тарифа: $e');
    }
  }
}
