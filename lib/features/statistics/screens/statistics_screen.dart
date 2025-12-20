import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabinet/core/theme/app_colors.dart';
import 'package:kabinet/features/statistics/providers/statistics_provider.dart';

/// Экран статистики
class StatisticsScreen extends ConsumerWidget {
  final String institutionId;

  const StatisticsScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final params = StatsParams(institutionId: institutionId, period: period);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Статистика'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Общая'),
              Tab(text: 'Предметы'),
              Tab(text: 'Преподаватели'),
              Tab(text: 'Ученики'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Период
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: StatsPeriod.values.map((p) {
                    final isSelected = p == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_periodLabel(p)),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(statsPeriodProvider.notifier).state = p;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            // Контент
            Expanded(
              child: TabBarView(
                children: [
                  _GeneralTab(params: params),
                  _SubjectsTab(params: params),
                  _TeachersTab(params: params),
                  _StudentsTab(institutionId: institutionId, params: params),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.week:
        return 'Неделя';
      case StatsPeriod.month:
        return 'Месяц';
      case StatsPeriod.quarter:
        return 'Квартал';
      case StatsPeriod.year:
        return 'Год';
    }
  }
}

/// Вкладка общей статистики
class _GeneralTab extends ConsumerWidget {
  final StatsParams params;

  const _GeneralTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(generalStatsProvider(params));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (stats) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Занятия
          _SectionTitle(title: 'Занятия'),
          _StatsGrid(
            items: [
              _StatItem(
                label: 'Всего',
                value: stats.totalLessons.toString(),
                icon: Icons.event,
                color: AppColors.primary,
              ),
              _StatItem(
                label: 'Проведено',
                value: stats.completedLessons.toString(),
                icon: Icons.check_circle,
                color: AppColors.success,
              ),
              _StatItem(
                label: 'Отменено',
                value: stats.cancelledLessons.toString(),
                icon: Icons.cancel,
                color: AppColors.error,
              ),
              _StatItem(
                label: 'Запланировано',
                value: stats.scheduledLessons.toString(),
                icon: Icons.schedule,
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Финансы
          _SectionTitle(title: 'Финансы'),
          _StatsGrid(
            items: [
              _StatItem(
                label: 'Оплаты',
                value: _formatMoney(stats.totalPayments),
                icon: Icons.payments,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Загруженность
          _SectionTitle(title: 'Загруженность'),
          _StatsGrid(
            items: [
              _StatItem(
                label: 'Часов занятий',
                value: stats.roomHours.toStringAsFixed(1),
                icon: Icons.access_time,
                color: AppColors.primary,
              ),
              _StatItem(
                label: 'Активных учеников',
                value: stats.activeStudents.toString(),
                icon: Icons.people,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);
    return formatter.format(amount);
  }
}

/// Вкладка статистики по предметам
class _SubjectsTab extends ConsumerWidget {
  final StatsParams params;

  const _SubjectsTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(subjectStatsProvider(params));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('Нет данных за период'));
        }

        return ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            final color = stat.color != null
                ? Color(int.parse('FF${stat.color!.replaceAll('#', '')}', radix: 16))
                : AppColors.primary;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(Icons.music_note, color: color),
              ),
              title: Text(stat.subjectName),
              subtitle: Text('${stat.percentage.toStringAsFixed(1)}% от всех занятий'),
              trailing: Text(
                '${stat.lessonsCount}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Вкладка статистики по преподавателям
class _TeachersTab extends ConsumerWidget {
  final StatsParams params;

  const _TeachersTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherStatsProvider(params));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('Нет данных за период'));
        }

        return ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  stat.teacherName.isNotEmpty ? stat.teacherName[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(stat.teacherName),
              subtitle: stat.subjects.isNotEmpty
                  ? Text(stat.subjects.join(', '))
                  : null,
              trailing: Text(
                '${stat.lessonsCount}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Вкладка статистики по ученикам
class _StudentsTab extends ConsumerWidget {
  final String institutionId;
  final StatsParams params;

  const _StudentsTab({
    required this.institutionId,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topStudentsAsync = ref.watch(topStudentsProvider(params));
    final debtorsAsync = ref.watch(debtorsProvider(institutionId));

    return ListView(
      children: [
        // Топ учеников
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SectionTitle(title: 'Топ по занятиям'),
        ),
        topStudentsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Ошибка: $e'),
          ),
          data: (students) {
            if (students.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Нет данных за период'),
              );
            }

            return Column(
              children: students.asMap().entries.map((entry) {
                final index = entry.key;
                final stat = entry.value;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getMedalColor(index),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index < 3 ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(stat.studentName),
                  trailing: Text(
                    '${stat.lessonsCount} зан.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const Divider(height: 32),

        // Должники
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SectionTitle(title: 'Должники'),
        ),
        debtorsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Ошибка: $e'),
          ),
          data: (debtors) {
            if (debtors.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Должников нет'),
                  ],
                ),
              );
            }

            return Column(
              children: debtors.map((stat) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.error,
                    child: Icon(Icons.warning, color: Colors.white),
                  ),
                  title: Text(stat.studentName),
                  trailing: Text(
                    '${stat.balance}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Color _getMedalColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.surfaceVariant;
    }
  }
}

/// Заголовок секции
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// Сетка статистики
class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items.map((item) => _StatCard(item: item)).toList(),
    );
  }
}

/// Элемент статистики
class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

/// Карточка статистики
class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 20, color: item.color),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }
}
