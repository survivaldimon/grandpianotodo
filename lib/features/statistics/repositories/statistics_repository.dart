import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';

/// Модель общей статистики
class GeneralStats {
  final int totalLessons;
  final int completedLessons;
  final int cancelledLessons;
  final int scheduledLessons;
  final double totalPayments;
  final double totalDiscounts;
  final int discountedPaymentsCount;
  final int activeStudents;
  final double roomHours;
  final double avgLessonCost; // Средняя стоимость занятия
  final int paidLessonsCount; // Количество оплаченных занятий
  // Статистика по способам оплаты
  final double cashTotal; // Сумма наличными
  final double cardTotal; // Сумма картой
  final int cashCount; // Количество оплат наличными
  final int cardCount; // Количество оплат картой

  const GeneralStats({
    required this.totalLessons,
    required this.completedLessons,
    required this.cancelledLessons,
    required this.scheduledLessons,
    required this.totalPayments,
    required this.totalDiscounts,
    required this.discountedPaymentsCount,
    required this.activeStudents,
    required this.roomHours,
    required this.avgLessonCost,
    required this.paidLessonsCount,
    this.cashTotal = 0,
    this.cardTotal = 0,
    this.cashCount = 0,
    this.cardCount = 0,
  });
}

/// Статистика по предмету
class SubjectStats {
  final String subjectId;
  final String subjectName;
  final String? color;
  final int lessonsCount;
  final double percentage;
  final double avgLessonCost; // Средняя стоимость занятия
  final int paidLessonsCount; // Количество оплаченных занятий

  const SubjectStats({
    required this.subjectId,
    required this.subjectName,
    this.color,
    required this.lessonsCount,
    required this.percentage,
    this.avgLessonCost = 0,
    this.paidLessonsCount = 0,
  });
}

/// Статистика по преподавателю
class TeacherStats {
  final String teacherId;
  final String teacherName;
  final int lessonsCount;
  final List<String> subjects;
  final double avgLessonCost; // Средняя стоимость занятия
  final int paidLessonsCount; // Количество оплаченных занятий

  const TeacherStats({
    required this.teacherId,
    required this.teacherName,
    required this.lessonsCount,
    required this.subjects,
    this.avgLessonCost = 0,
    this.paidLessonsCount = 0,
  });
}

/// Статистика по ученику
class StudentStats {
  final String studentId;
  final String studentName;
  final int lessonsCount;
  final int balance;

  const StudentStats({
    required this.studentId,
    required this.studentName,
    required this.lessonsCount,
    required this.balance,
  });
}

/// Статистика занятий ученика (проведено/отменено)
class StudentLessonStatusStats {
  final String studentId;
  final String studentName;
  final int completedCount;
  final int cancelledCount;

  const StudentLessonStatusStats({
    required this.studentId,
    required this.studentName,
    required this.completedCount,
    required this.cancelledCount,
  });

  int get totalCount => completedCount + cancelledCount;
  double get cancellationRate => totalCount > 0 ? (cancelledCount / totalCount) * 100 : 0;
}

/// Статистика по тарифам оплаты
class PaymentPlanStats {
  final String? planId;
  final String planName;
  final int purchaseCount;
  final double totalAmount;
  final int totalLessons;
  // Статистика по способам оплаты
  final double cashTotal;
  final double cardTotal;
  final int cashCount;
  final int cardCount;

  const PaymentPlanStats({
    this.planId,
    required this.planName,
    required this.purchaseCount,
    required this.totalAmount,
    required this.totalLessons,
    this.cashTotal = 0,
    this.cardTotal = 0,
    this.cashCount = 0,
    this.cardCount = 0,
  });
}

/// Статистика стоимости занятий ученика
class StudentLessonCostStats {
  final double avgLessonCost;
  final int paidLessonsCount;
  final double totalCost;
  final double approxAvgCost; // Приблизительная стоимость (оплаты / занятия)
  final bool isApproximate; // Используется ли приблизительное значение

  const StudentLessonCostStats({
    required this.avgLessonCost,
    required this.paidLessonsCount,
    required this.totalCost,
    this.approxAvgCost = 0,
    this.isApproximate = false,
  });

  /// Получить отображаемую стоимость (точную или приблизительную)
  double get displayCost => avgLessonCost > 0 ? avgLessonCost : approxAvgCost;

  /// Есть ли какие-либо данные для отображения
  bool get hasData => avgLessonCost > 0 || approxAvgCost > 0;
}

/// Репозиторий статистики
class StatisticsRepository {
  final _client = SupabaseConfig.client;

  /// Получить общую статистику за период
  Future<GeneralStats> getGeneralStats({
    required String institutionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      // Получаем занятия за период с subscription_id
      final lessonsData = await _client
          .from('lessons')
          .select('id, status, start_time, end_time, student_id, subscription_id')
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null);

      final lessons = lessonsData as List;
      final totalLessons = lessons.length;
      final completedLessons = lessons.where((l) => l['status'] == 'completed').length;
      final cancelledLessons = lessons.where((l) => l['status'] == 'cancelled').length;
      final scheduledLessons = lessons.where((l) => l['status'] == 'scheduled').length;

      // Считаем часы
      double roomHours = 0;
      for (final lesson in lessons) {
        if (lesson['status'] == 'completed' || lesson['status'] == 'scheduled') {
          final startParts = (lesson['start_time'] as String).split(':');
          final endParts = (lesson['end_time'] as String).split(':');
          final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          roomHours += (endMinutes - startMinutes) / 60;
        }
      }

      // Получаем оплаты за период
      final paymentsData = await _client
          .from('payments')
          .select('id, amount, comment, lessons_count, payment_method')
          .eq('institution_id', institutionId)
          .gte('paid_at', startDate.toIso8601String())
          .lte('paid_at', endDate.toIso8601String());

      double totalPayments = 0;
      double totalDiscounts = 0;
      int discountedPaymentsCount = 0;
      // Статистика по способам оплаты
      double cashTotal = 0;
      double cardTotal = 0;
      int cashCount = 0;
      int cardCount = 0;

      // Регулярка для парсинга скидки из комментария: "Скидка: 2000 ₸"
      final discountRegex = RegExp(r'Скидка:\s*(\d+(?:\.\d+)?)\s*₸?');

      // Карта: payment_id -> cost_per_lesson
      final paymentCostMap = <String, double>{};

      for (final p in paymentsData as List) {
        final amount = (p['amount'] as num).toDouble();
        final lessonsCount = p['lessons_count'] as int? ?? 1;
        final paymentMethod = p['payment_method'] as String? ?? 'cash';
        totalPayments += amount;

        // Статистика по способам оплаты
        if (paymentMethod == 'card') {
          cardTotal += amount;
          cardCount++;
        } else {
          cashTotal += amount;
          cashCount++;
        }

        // Сохраняем стоимость за занятие
        paymentCostMap[p['id'] as String] = lessonsCount > 0 ? amount / lessonsCount : 0;

        // Проверяем комментарий на наличие скидки
        final comment = p['comment'] as String?;
        if (comment != null) {
          final match = discountRegex.firstMatch(comment);
          if (match != null) {
            final discountAmount = double.tryParse(match.group(1) ?? '0') ?? 0;
            totalDiscounts += discountAmount;
            discountedPaymentsCount++;
          }
        }
      }

      // Считаем среднюю стоимость занятия
      double totalLessonsCost = 0;
      int paidLessonsCount = 0;

      // Собираем subscription_id занятий за период
      final subscriptionIds = <String>{};
      for (final lesson in lessons) {
        if (lesson['subscription_id'] != null) {
          subscriptionIds.add(lesson['subscription_id'] as String);
        }
      }

      // Получаем подписки и их оплаты
      if (subscriptionIds.isNotEmpty) {
        final subscriptionsData = await _client
            .from('subscriptions')
            .select('id, payment_id')
            .inFilter('id', subscriptionIds.toList());

        // Карта subscription_id -> payment_id
        final subscriptionPaymentMap = <String, String>{};
        for (final sub in subscriptionsData as List) {
          if (sub['payment_id'] != null) {
            subscriptionPaymentMap[sub['id'] as String] = sub['payment_id'] as String;
          }
        }

        // Получаем оплаты подписок (могут быть из другого периода)
        final subPaymentIds = subscriptionPaymentMap.values.toSet();
        if (subPaymentIds.isNotEmpty) {
          final subPaymentsData = await _client
              .from('payments')
              .select('id, amount, lessons_count')
              .inFilter('id', subPaymentIds.toList());

          for (final p in subPaymentsData as List) {
            final amount = (p['amount'] as num).toDouble();
            final lessonsCount = p['lessons_count'] as int? ?? 1;
            paymentCostMap[p['id'] as String] = lessonsCount > 0 ? amount / lessonsCount : 0;
          }
        }

        // Теперь считаем стоимость занятий
        for (final lesson in lessons) {
          final subId = lesson['subscription_id'] as String?;
          if (subId != null && subscriptionPaymentMap.containsKey(subId)) {
            final paymentId = subscriptionPaymentMap[subId]!;
            if (paymentCostMap.containsKey(paymentId)) {
              totalLessonsCost += paymentCostMap[paymentId]!;
              paidLessonsCount++;
            }
          }
        }
      }

      final avgLessonCost = paidLessonsCount > 0 ? totalLessonsCost / paidLessonsCount : 0.0;

      // Считаем уникальных учеников с занятиями
      final studentIds = <String>{};
      for (final lesson in lessons) {
        if (lesson['student_id'] != null) {
          studentIds.add(lesson['student_id'] as String);
        }
      }

      return GeneralStats(
        totalLessons: totalLessons,
        completedLessons: completedLessons,
        cancelledLessons: cancelledLessons,
        scheduledLessons: scheduledLessons,
        totalPayments: totalPayments,
        totalDiscounts: totalDiscounts,
        discountedPaymentsCount: discountedPaymentsCount,
        activeStudents: studentIds.length,
        roomHours: roomHours,
        avgLessonCost: avgLessonCost,
        paidLessonsCount: paidLessonsCount,
        cashTotal: cashTotal,
        cardTotal: cardTotal,
        cashCount: cashCount,
        cardCount: cardCount,
      );
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики: $e');
    }
  }

  /// Получить статистику по предметам
  Future<List<SubjectStats>> getSubjectStats({
    required String institutionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      // Получаем занятия с предметами и subscription_id
      final lessonsData = await _client
          .from('lessons')
          .select('id, subject_id, subscription_id, subjects(id, name, color)')
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null)
          .not('subject_id', 'is', null);

      final lessons = lessonsData as List;
      final totalCount = lessons.length;

      // Группируем по предметам и собираем subscription_id
      final subjectData = <String, Map<String, dynamic>>{};
      final allSubscriptionIds = <String>{};

      for (final lesson in lessons) {
        final subjectId = lesson['subject_id'] as String;
        final subject = lesson['subjects'] as Map<String, dynamic>?;

        if (subject != null) {
          if (!subjectData.containsKey(subjectId)) {
            subjectData[subjectId] = {
              'name': subject['name'],
              'color': subject['color'],
              'count': 0,
              'lessons': <Map<String, dynamic>>[],
            };
          }
          subjectData[subjectId]!['count'] = (subjectData[subjectId]!['count'] as int) + 1;
          (subjectData[subjectId]!['lessons'] as List<Map<String, dynamic>>).add(lesson);

          if (lesson['subscription_id'] != null) {
            allSubscriptionIds.add(lesson['subscription_id'] as String);
          }
        }
      }

      // Получаем информацию о стоимости занятий
      final paymentCostMap = <String, double>{};
      final subscriptionPaymentMap = <String, String>{};

      if (allSubscriptionIds.isNotEmpty) {
        final subscriptionsData = await _client
            .from('subscriptions')
            .select('id, payment_id')
            .inFilter('id', allSubscriptionIds.toList());

        final paymentIds = <String>{};
        for (final sub in subscriptionsData as List) {
          if (sub['payment_id'] != null) {
            subscriptionPaymentMap[sub['id'] as String] = sub['payment_id'] as String;
            paymentIds.add(sub['payment_id'] as String);
          }
        }

        if (paymentIds.isNotEmpty) {
          final paymentsData = await _client
              .from('payments')
              .select('id, amount, lessons_count')
              .inFilter('id', paymentIds.toList());

          for (final p in paymentsData as List) {
            final amount = (p['amount'] as num).toDouble();
            final lessonsCount = p['lessons_count'] as int? ?? 1;
            paymentCostMap[p['id'] as String] = lessonsCount > 0 ? amount / lessonsCount : 0;
          }
        }
      }

      return subjectData.entries.map((e) {
        final count = e.value['count'] as int;

        // Считаем среднюю стоимость для предмета
        double totalCost = 0;
        int paidCount = 0;
        for (final lesson in (e.value['lessons'] as List<Map<String, dynamic>>)) {
          final subId = lesson['subscription_id'] as String?;
          if (subId != null && subscriptionPaymentMap.containsKey(subId)) {
            final paymentId = subscriptionPaymentMap[subId]!;
            if (paymentCostMap.containsKey(paymentId)) {
              totalCost += paymentCostMap[paymentId]!;
              paidCount++;
            }
          }
        }

        return SubjectStats(
          subjectId: e.key,
          subjectName: e.value['name'] as String,
          color: e.value['color'] as String?,
          lessonsCount: count,
          percentage: totalCount > 0 ? (count / totalCount) * 100 : 0,
          avgLessonCost: paidCount > 0 ? totalCost / paidCount : 0,
          paidLessonsCount: paidCount,
        );
      }).toList()
        ..sort((a, b) => b.lessonsCount.compareTo(a.lessonsCount));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики по предметам: $e');
    }
  }

  /// Получить статистику по преподавателям
  Future<List<TeacherStats>> getTeacherStats({
    required String institutionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      // Получаем занятия с subscription_id
      final lessonsData = await _client
          .from('lessons')
          .select('id, teacher_id, subject_id, subscription_id, subjects(name)')
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null);

      final lessons = lessonsData as List;

      // Группируем по преподавателям
      final teacherData = <String, Map<String, dynamic>>{};
      final allSubscriptionIds = <String>{};

      for (final lesson in lessons) {
        final teacherId = lesson['teacher_id'] as String;

        if (!teacherData.containsKey(teacherId)) {
          teacherData[teacherId] = {
            'count': 0,
            'subjects': <String>{},
            'lessons': <Map<String, dynamic>>[],
          };
        }
        teacherData[teacherId]!['count'] = (teacherData[teacherId]!['count'] as int) + 1;
        (teacherData[teacherId]!['lessons'] as List<Map<String, dynamic>>).add(lesson);

        final subject = lesson['subjects'] as Map<String, dynamic>?;
        if (subject != null) {
          (teacherData[teacherId]!['subjects'] as Set<String>).add(subject['name'] as String);
        }

        if (lesson['subscription_id'] != null) {
          allSubscriptionIds.add(lesson['subscription_id'] as String);
        }
      }

      // Получаем имена преподавателей
      final teacherIds = teacherData.keys.toList();
      if (teacherIds.isEmpty) return [];

      final profilesData = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', teacherIds);

      final profilesMap = <String, String>{};
      for (final p in profilesData as List) {
        profilesMap[p['id'] as String] = p['full_name'] as String;
      }

      // Получаем информацию о стоимости занятий
      final paymentCostMap = <String, double>{};
      final subscriptionPaymentMap = <String, String>{};

      if (allSubscriptionIds.isNotEmpty) {
        final subscriptionsData = await _client
            .from('subscriptions')
            .select('id, payment_id')
            .inFilter('id', allSubscriptionIds.toList());

        final paymentIds = <String>{};
        for (final sub in subscriptionsData as List) {
          if (sub['payment_id'] != null) {
            subscriptionPaymentMap[sub['id'] as String] = sub['payment_id'] as String;
            paymentIds.add(sub['payment_id'] as String);
          }
        }

        if (paymentIds.isNotEmpty) {
          final paymentsData = await _client
              .from('payments')
              .select('id, amount, lessons_count')
              .inFilter('id', paymentIds.toList());

          for (final p in paymentsData as List) {
            final amount = (p['amount'] as num).toDouble();
            final lessonsCount = p['lessons_count'] as int? ?? 1;
            paymentCostMap[p['id'] as String] = lessonsCount > 0 ? amount / lessonsCount : 0;
          }
        }
      }

      return teacherData.entries.map((e) {
        // Считаем среднюю стоимость для преподавателя
        double totalCost = 0;
        int paidCount = 0;
        for (final lesson in (e.value['lessons'] as List<Map<String, dynamic>>)) {
          final subId = lesson['subscription_id'] as String?;
          if (subId != null && subscriptionPaymentMap.containsKey(subId)) {
            final paymentId = subscriptionPaymentMap[subId]!;
            if (paymentCostMap.containsKey(paymentId)) {
              totalCost += paymentCostMap[paymentId]!;
              paidCount++;
            }
          }
        }

        return TeacherStats(
          teacherId: e.key,
          teacherName: profilesMap[e.key] ?? 'Неизвестный',
          lessonsCount: e.value['count'] as int,
          subjects: (e.value['subjects'] as Set<String>).toList(),
          avgLessonCost: paidCount > 0 ? totalCost / paidCount : 0,
          paidLessonsCount: paidCount,
        );
      }).toList()
        ..sort((a, b) => b.lessonsCount.compareTo(a.lessonsCount));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики по преподавателям: $e');
    }
  }

  /// Получить топ учеников по занятиям
  Future<List<StudentStats>> getTopStudents({
    required String institutionId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;

      // Получаем занятия со студентами
      final lessonsData = await _client
          .from('lessons')
          .select('student_id, students(id, name, prepaid_lessons_count)')
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null)
          .not('student_id', 'is', null);

      final lessons = lessonsData as List;

      // Группируем по ученикам
      final studentData = <String, Map<String, dynamic>>{};
      for (final lesson in lessons) {
        final studentId = lesson['student_id'] as String;
        final student = lesson['students'] as Map<String, dynamic>?;

        if (student != null) {
          if (!studentData.containsKey(studentId)) {
            studentData[studentId] = {
              'name': student['name'],
              'balance': student['prepaid_lessons_count'],
              'count': 0,
            };
          }
          studentData[studentId]!['count'] = (studentData[studentId]!['count'] as int) + 1;
        }
      }

      final result = studentData.entries.map((e) {
        return StudentStats(
          studentId: e.key,
          studentName: e.value['name'] as String,
          lessonsCount: e.value['count'] as int,
          balance: e.value['balance'] as int,
        );
      }).toList()
        ..sort((a, b) => b.lessonsCount.compareTo(a.lessonsCount));

      return result.take(limit).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки топа учеников: $e');
    }
  }

  /// Получить список должников
  Future<List<StudentStats>> getDebtors({
    required String institutionId,
  }) async {
    try {
      final studentsData = await _client
          .from('students')
          .select('id, name, prepaid_lessons_count')
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .lt('prepaid_lessons_count', 0)
          .order('prepaid_lessons_count');

      return (studentsData as List).map((s) {
        return StudentStats(
          studentId: s['id'] as String,
          studentName: s['name'] as String,
          lessonsCount: 0,
          balance: s['prepaid_lessons_count'] as int,
        );
      }).toList();
    } catch (e) {
      throw DatabaseException('Ошибка загрузки должников: $e');
    }
  }

  /// Получить статистику по тарифам оплаты
  Future<List<PaymentPlanStats>> getPaymentPlanStats({
    required String institutionId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Получаем оплаты за период с тарифами
      final paymentsData = await _client
          .from('payments')
          .select('id, amount, lessons_count, payment_plan_id, payment_method, comment, payment_plans(id, name)')
          .eq('institution_id', institutionId)
          .gte('paid_at', startDate.toIso8601String())
          .lte('paid_at', endDate.toIso8601String());

      final payments = paymentsData as List;

      // Группируем по тарифам
      final planData = <String, Map<String, dynamic>>{};
      for (final payment in payments) {
        final planId = payment['payment_plan_id'] as String?;
        final plan = payment['payment_plans'] as Map<String, dynamic>?;
        final comment = payment['comment'] as String?;
        final paymentMethod = payment['payment_method'] as String? ?? 'cash';
        final amount = (payment['amount'] as num).toDouble();

        // Определяем название: тариф, тип занятия из comment, или "Свой вариант"
        String planName;
        String groupKey;

        if (plan != null) {
          planName = plan['name'] as String;
          groupKey = planId!;
        } else if (comment != null && comment.startsWith('lesson:')) {
          // Формат: lesson:ID|TYPE_NAME
          final pipeIndex = comment.indexOf('|');
          planName = pipeIndex != -1 ? comment.substring(pipeIndex + 1) : 'Оплата занятия';
          groupKey = 'lesson_type:$planName';
        } else {
          planName = 'Свой вариант';
          groupKey = 'custom';
        }

        if (!planData.containsKey(groupKey)) {
          planData[groupKey] = {
            'name': planName,
            'count': 0,
            'amount': 0.0,
            'lessons': 0,
            'cashTotal': 0.0,
            'cardTotal': 0.0,
            'cashCount': 0,
            'cardCount': 0,
          };
        }
        planData[groupKey]!['count'] = (planData[groupKey]!['count'] as int) + 1;
        planData[groupKey]!['amount'] = (planData[groupKey]!['amount'] as double) + amount;
        planData[groupKey]!['lessons'] =
            (planData[groupKey]!['lessons'] as int) + (payment['lessons_count'] as int);

        // Статистика по способам оплаты
        if (paymentMethod == 'card') {
          planData[groupKey]!['cardTotal'] = (planData[groupKey]!['cardTotal'] as double) + amount;
          planData[groupKey]!['cardCount'] = (planData[groupKey]!['cardCount'] as int) + 1;
        } else {
          planData[groupKey]!['cashTotal'] = (planData[groupKey]!['cashTotal'] as double) + amount;
          planData[groupKey]!['cashCount'] = (planData[groupKey]!['cashCount'] as int) + 1;
        }
      }

      return planData.entries.map((e) {
        return PaymentPlanStats(
          planId: e.key,
          planName: e.value['name'] as String,
          purchaseCount: e.value['count'] as int,
          totalAmount: e.value['amount'] as double,
          totalLessons: e.value['lessons'] as int,
          cashTotal: e.value['cashTotal'] as double,
          cardTotal: e.value['cardTotal'] as double,
          cashCount: e.value['cashCount'] as int,
          cardCount: e.value['cardCount'] as int,
        );
      }).toList()
        ..sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики по тарифам: $e');
    }
  }

  /// Получить среднюю стоимость занятия для ученика
  Future<StudentLessonCostStats> getStudentAvgLessonCost({
    required String studentId,
  }) async {
    try {
      // Получаем ВСЕ завершённые занятия ученика
      final allLessonsData = await _client
          .from('lessons')
          .select('id, subscription_id')
          .eq('student_id', studentId)
          .eq('status', 'completed')
          .isFilter('archived_at', null);

      final allLessons = allLessonsData as List;
      final totalCompletedLessons = allLessons.length;

      // Получаем оплаты ученика для приблизительного расчёта
      final studentPaymentsData = await _client
          .from('payments')
          .select('amount')
          .eq('student_id', studentId);

      double totalStudentPayments = 0;
      for (final p in studentPaymentsData as List) {
        totalStudentPayments += (p['amount'] as num).toDouble();
      }

      // Приблизительная стоимость: все оплаты / все завершённые занятия
      final double approxAvgCost = totalCompletedLessons > 0 && totalStudentPayments > 0
          ? totalStudentPayments / totalCompletedLessons
          : 0;

      // Занятия с subscription_id для точного расчёта
      final lessonsWithSub = allLessons.where((l) => l['subscription_id'] != null).toList();

      if (lessonsWithSub.isEmpty) {
        return StudentLessonCostStats(
          avgLessonCost: 0,
          paidLessonsCount: 0,
          totalCost: 0,
          approxAvgCost: approxAvgCost,
          isApproximate: approxAvgCost > 0,
        );
      }

      // Собираем subscription_id
      final subscriptionIds = <String>{};
      for (final lesson in lessonsWithSub) {
        subscriptionIds.add(lesson['subscription_id'] as String);
      }

      // Получаем подписки и их payment_id
      final subscriptionsData = await _client
          .from('subscriptions')
          .select('id, payment_id')
          .inFilter('id', subscriptionIds.toList());

      final subscriptionPaymentMap = <String, String>{};
      final paymentIds = <String>{};
      for (final sub in subscriptionsData as List) {
        if (sub['payment_id'] != null) {
          subscriptionPaymentMap[sub['id'] as String] = sub['payment_id'] as String;
          paymentIds.add(sub['payment_id'] as String);
        }
      }

      if (paymentIds.isEmpty) {
        return StudentLessonCostStats(
          avgLessonCost: 0,
          paidLessonsCount: lessonsWithSub.length,
          totalCost: 0,
          approxAvgCost: approxAvgCost,
          isApproximate: approxAvgCost > 0,
        );
      }

      // Получаем оплаты
      final paymentsData = await _client
          .from('payments')
          .select('id, amount, lessons_count')
          .inFilter('id', paymentIds.toList());

      final paymentCostMap = <String, double>{};
      for (final p in paymentsData as List) {
        final amount = (p['amount'] as num).toDouble();
        final lessonsCount = p['lessons_count'] as int? ?? 1;
        paymentCostMap[p['id'] as String] = lessonsCount > 0 ? amount / lessonsCount : 0;
      }

      // Считаем общую стоимость
      double totalCost = 0;
      int paidCount = 0;
      for (final lesson in lessonsWithSub) {
        final subId = lesson['subscription_id'] as String;
        if (subscriptionPaymentMap.containsKey(subId)) {
          final paymentId = subscriptionPaymentMap[subId]!;
          if (paymentCostMap.containsKey(paymentId)) {
            totalCost += paymentCostMap[paymentId]!;
            paidCount++;
          }
        }
      }

      final exactAvgCost = paidCount > 0 ? totalCost / paidCount : 0.0;

      return StudentLessonCostStats(
        avgLessonCost: exactAvgCost,
        paidLessonsCount: paidCount,
        totalCost: totalCost,
        approxAvgCost: approxAvgCost,
        isApproximate: exactAvgCost <= 0 && approxAvgCost > 0,
      );
    } catch (e) {
      throw DatabaseException('Ошибка расчёта средней стоимости: $e');
    }
  }

  /// Получить статистику занятий ученика (проведено/отменено)
  /// Учитывает как индивидуальные занятия, так и групповые
  Future<({int completed, int cancelled})> getStudentLessonStats({
    required String studentId,
  }) async {
    try {
      // 1. Индивидуальные занятия (student_id в lessons)
      final individualData = await _client
          .from('lessons')
          .select('status')
          .eq('student_id', studentId)
          .isFilter('archived_at', null);

      final individualLessons = individualData as List;
      int completed = individualLessons.where((l) => l['status'] == 'completed').length;
      int cancelled = individualLessons.where((l) => l['status'] == 'cancelled').length;

      // 2. Групповые занятия (через lesson_students)
      final groupData = await _client
          .from('lesson_students')
          .select('attended, lessons(status, archived_at)')
          .eq('student_id', studentId);

      final groupLessons = groupData as List;
      for (final ls in groupLessons) {
        final lesson = ls['lessons'];
        if (lesson == null || lesson['archived_at'] != null) continue;

        final status = lesson['status'] as String?;
        if (status == 'completed') {
          completed++;
        } else if (status == 'cancelled') {
          cancelled++;
        }
      }

      return (completed: completed, cancelled: cancelled);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики занятий: $e');
    }
  }

  /// Получить статистику занятий всех учеников заведения
  Future<List<StudentLessonStatusStats>> getAllStudentsLessonStats({
    required String institutionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('lessons')
          .select('student_id, status, students(id, name)')
          .eq('institution_id', institutionId)
          .isFilter('archived_at', null)
          .not('student_id', 'is', null);

      // Добавляем фильтр по датам если указаны
      if (startDate != null) {
        final startStr = startDate.toIso8601String().split('T').first;
        query = query.gte('date', startStr);
      }
      if (endDate != null) {
        final endStr = endDate.toIso8601String().split('T').first;
        query = query.lte('date', endStr);
      }

      final data = await query;
      final lessons = data as List;

      // Группируем по ученикам
      final studentData = <String, Map<String, dynamic>>{};
      for (final lesson in lessons) {
        final studentId = lesson['student_id'] as String;
        final student = lesson['students'] as Map<String, dynamic>?;
        final status = lesson['status'] as String;

        if (student != null) {
          if (!studentData.containsKey(studentId)) {
            studentData[studentId] = {
              'name': student['name'],
              'completed': 0,
              'cancelled': 0,
            };
          }
          if (status == 'completed') {
            studentData[studentId]!['completed'] = (studentData[studentId]!['completed'] as int) + 1;
          } else if (status == 'cancelled') {
            studentData[studentId]!['cancelled'] = (studentData[studentId]!['cancelled'] as int) + 1;
          }
        }
      }

      return studentData.entries.map((e) {
        return StudentLessonStatusStats(
          studentId: e.key,
          studentName: e.value['name'] as String,
          completedCount: e.value['completed'] as int,
          cancelledCount: e.value['cancelled'] as int,
        );
      }).toList()
        ..sort((a, b) => b.completedCount.compareTo(a.completedCount));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики учеников: $e');
    }
  }

  /// Realtime стрим статистики занятий ученика (проведено/отменено)
  /// Обновляется при любых изменениях в таблице lessons
  /// Использует StreamController для устойчивой обработки ошибок Realtime
  Stream<({int completed, int cancelled})> watchStudentLessonStats({
    required String studentId,
  }) {
    final controller = StreamController<({int completed, int cancelled})>.broadcast();

    Future<void> loadAndEmit() async {
      try {
        final stats = await getStudentLessonStats(studentId: studentId);
        if (!controller.isClosed) {
          controller.add(stats);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // 1. Сразу загружаем начальные данные
    loadAndEmit();

    // 2. Подписываемся на изменения с обработкой ошибок
    final subscription = _client.from('lessons').stream(primaryKey: ['id']).listen(
      (_) => loadAndEmit(),
      onError: (e) {
        debugPrint('[StatisticsRepository] watchStudentLessonStats error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      },
    );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }
}
