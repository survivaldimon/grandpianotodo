import 'package:flutter/material.dart';

/// Shimmer-эффект для анимации загрузки
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.grey[800]!,
                      Colors.grey[700]!,
                      Colors.grey[600]!,
                      Colors.grey[700]!,
                      Colors.grey[800]!,
                    ]
                  : [
                      Colors.grey[300]!,
                      Colors.grey[200]!,
                      Colors.grey[100]!,
                      Colors.grey[200]!,
                      Colors.grey[300]!,
                    ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// Скелетон-блок для shimmer
class ShimmerBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Скелетон расписания - пустая сетка с shimmer-эффектом
class ScheduleSkeletonLoader extends StatelessWidget {
  final int roomCount;
  final int startHour;
  final int endHour;

  const ScheduleSkeletonLoader({
    super.key,
    this.roomCount = 3,
    this.startHour = 8,
    this.endHour = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourHeight = 60.0;
    final roomWidth = 120.0;
    final timeColumnWidth = 50.0;
    final hours = endHour - startHour;

    return ShimmerLoading(
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Колонка времени
            SizedBox(
              width: timeColumnWidth,
              child: Column(
                children: [
                  const SizedBox(height: 48), // Header height
                  for (int i = 0; i < hours; i++)
                    Container(
                      height: hourHeight,
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 4),
                      child: ShimmerBlock(
                        width: 35,
                        height: 16,
                        borderRadius: 4,
                      ),
                    ),
                ],
              ),
            ),
            // Колонки кабинетов
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(roomCount, (roomIndex) {
                    return SizedBox(
                      width: roomWidth,
                      child: Column(
                        children: [
                          // Header кабинета
                          Container(
                            height: 48,
                            padding: const EdgeInsets.all(8),
                            child: ShimmerBlock(
                              width: 80,
                              height: 32,
                              borderRadius: 8,
                            ),
                          ),
                          // Пустая сетка часов (БЕЗ блоков занятий)
                          ...List.generate(hours, (hourIndex) {
                            return Container(
                              height: hourHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                  left: BorderSide(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Компактный скелетон для недельного режима - пустая сетка с shimmer-эффектом
class WeekScheduleSkeletonLoader extends StatelessWidget {
  final int dayCount;

  const WeekScheduleSkeletonLoader({
    super.key,
    this.dayCount = 7,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShimmerLoading(
      child: Column(
        children: [
          // Header с днями недели
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const SizedBox(width: 50), // Time column
                ...List.generate(dayCount, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ShimmerBlock(height: 40, borderRadius: 8),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Сетка
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Колонка времени
                  SizedBox(
                    width: 50,
                    child: Column(
                      children: List.generate(14, (i) {
                        return Container(
                          height: 60,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 4),
                          child: ShimmerBlock(
                            width: 35,
                            height: 16,
                            borderRadius: 4,
                          ),
                        );
                      }),
                    ),
                  ),
                  // Колонки дней (БЕЗ блоков занятий)
                  ...List.generate(dayCount, (dayIndex) {
                    return Expanded(
                      child: Column(
                        children: List.generate(14, (hourIndex) {
                          return Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                                  width: 0.5,
                                ),
                                left: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
