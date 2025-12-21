import 'package:kabinet/core/config/supabase_config.dart';
import 'package:kabinet/core/exceptions/app_exceptions.dart';

/// Модель общей статистики
class GeneralStats {
  final int totalLessons;
  final int completedLessons;
  final int cancelledLessons;
  final int scheduledLessons;
  final double totalPayments;
  final int activeStudents;
  final double roomHours;

  const GeneralStats({
    required this.totalLessons,
    required this.completedLessons,
    required this.cancelledLessons,
    required this.scheduledLessons,
    required this.totalPayments,
    required this.activeStudents,
    required this.roomHours,
  });
}

/// Статистика по предмету
class SubjectStats {
  final String subjectId;
  final String subjectName;
  final String? color;
  final int lessonsCount;
  final double percentage;

  const SubjectStats({
    required this.subjectId,
    required this.subjectName,
    this.color,
    required this.lessonsCount,
    required this.percentage,
  });
}

/// Статистика по преподавателю
class TeacherStats {
  final String teacherId;
  final String teacherName;
  final int lessonsCount;
  final List<String> subjects;

  const TeacherStats({
    required this.teacherId,
    required this.teacherName,
    required this.lessonsCount,
    required this.subjects,
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

/// Статистика по тарифам оплаты
class PaymentPlanStats {
  final String? planId;
  final String planName;
  final int purchaseCount;
  final double totalAmount;
  final int totalLessons;

  const PaymentPlanStats({
    this.planId,
    required this.planName,
    required this.purchaseCount,
    required this.totalAmount,
    required this.totalLessons,
  });
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

      // Получаем занятия за период
      final lessonsData = await _client
          .from('lessons')
          .select('id, status, start_time, end_time, student_id')
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
          .select('amount')
          .eq('institution_id', institutionId)
          .gte('paid_at', startDate.toIso8601String())
          .lte('paid_at', endDate.toIso8601String());

      double totalPayments = 0;
      for (final p in paymentsData as List) {
        totalPayments += (p['amount'] as num).toDouble();
      }

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
        activeStudents: studentIds.length,
        roomHours: roomHours,
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

      // Получаем занятия с предметами
      final lessonsData = await _client
          .from('lessons')
          .select('subject_id, subjects(id, name, color)')
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null)
          .not('subject_id', 'is', null);

      final lessons = lessonsData as List;
      final totalCount = lessons.length;

      // Группируем по предметам
      final subjectCounts = <String, Map<String, dynamic>>{};
      for (final lesson in lessons) {
        final subjectId = lesson['subject_id'] as String;
        final subject = lesson['subjects'] as Map<String, dynamic>?;

        if (subject != null) {
          if (!subjectCounts.containsKey(subjectId)) {
            subjectCounts[subjectId] = {
              'name': subject['name'],
              'color': subject['color'],
              'count': 0,
            };
          }
          subjectCounts[subjectId]!['count'] = (subjectCounts[subjectId]!['count'] as int) + 1;
        }
      }

      return subjectCounts.entries.map((e) {
        final count = e.value['count'] as int;
        return SubjectStats(
          subjectId: e.key,
          subjectName: e.value['name'] as String,
          color: e.value['color'] as String?,
          lessonsCount: count,
          percentage: totalCount > 0 ? (count / totalCount) * 100 : 0,
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

      // Получаем занятия
      final lessonsData = await _client
          .from('lessons')
          .select('teacher_id, subject_id, subjects(name)')
          .eq('institution_id', institutionId)
          .gte('date', startStr)
          .lte('date', endStr)
          .isFilter('archived_at', null);

      final lessons = lessonsData as List;

      // Группируем по преподавателям
      final teacherData = <String, Map<String, dynamic>>{};
      for (final lesson in lessons) {
        final teacherId = lesson['teacher_id'] as String;

        if (!teacherData.containsKey(teacherId)) {
          teacherData[teacherId] = {
            'count': 0,
            'subjects': <String>{},
          };
        }
        teacherData[teacherId]!['count'] = (teacherData[teacherId]!['count'] as int) + 1;

        final subject = lesson['subjects'] as Map<String, dynamic>?;
        if (subject != null) {
          (teacherData[teacherId]!['subjects'] as Set<String>).add(subject['name'] as String);
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

      return teacherData.entries.map((e) {
        return TeacherStats(
          teacherId: e.key,
          teacherName: profilesMap[e.key] ?? 'Неизвестный',
          lessonsCount: e.value['count'] as int,
          subjects: (e.value['subjects'] as Set<String>).toList(),
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
          .select('id, amount, lessons_count, payment_plan_id, payment_plans(id, name)')
          .eq('institution_id', institutionId)
          .gte('paid_at', startDate.toIso8601String())
          .lte('paid_at', endDate.toIso8601String());

      final payments = paymentsData as List;

      // Группируем по тарифам
      final planData = <String?, Map<String, dynamic>>{};
      for (final payment in payments) {
        final planId = payment['payment_plan_id'] as String?;
        final plan = payment['payment_plans'] as Map<String, dynamic>?;
        final planName = plan?['name'] as String? ?? 'Свой вариант';

        if (!planData.containsKey(planId)) {
          planData[planId] = {
            'name': planName,
            'count': 0,
            'amount': 0.0,
            'lessons': 0,
          };
        }
        planData[planId]!['count'] = (planData[planId]!['count'] as int) + 1;
        planData[planId]!['amount'] =
            (planData[planId]!['amount'] as double) + (payment['amount'] as num).toDouble();
        planData[planId]!['lessons'] =
            (planData[planId]!['lessons'] as int) + (payment['lessons_count'] as int);
      }

      return planData.entries.map((e) {
        return PaymentPlanStats(
          planId: e.key,
          planName: e.value['name'] as String,
          purchaseCount: e.value['count'] as int,
          totalAmount: e.value['amount'] as double,
          totalLessons: e.value['lessons'] as int,
        );
      }).toList()
        ..sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));
    } catch (e) {
      throw DatabaseException('Ошибка загрузки статистики по тарифам: $e');
    }
  }
}
