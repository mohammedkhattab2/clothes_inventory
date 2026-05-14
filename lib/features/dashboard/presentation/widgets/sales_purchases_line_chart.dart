import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';

class SalesPurchasesLineChart extends StatelessWidget {
  const SalesPurchasesLineChart({required this.points, super.key});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dense = MediaQuery.sizeOf(context).height < 820;

    if (points.isEmpty) {
      return AppEmptyState(
        icon: Icons.show_chart_outlined,
        title: 'No trend data for selected range.'.tr(),
        compact: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final values = <double>[
          ...points.map((e) => e.sales),
          ...points.map((e) => e.purchases),
        ];
        final maxValue = values.fold<double>(0, (p, v) => v > p ? v : p);
        if (maxValue <= 0 || points.length < 2) {
          return AppEmptyState(
            icon: Icons.timeline_outlined,
            title: 'Not enough trend points.'.tr(),
            compact: true,
          );
        }

        const left = 35.0;
        const right = 15.0;
        const top = 30.0;
        const bottom = 40.0;

        final width = constraints.maxWidth - left - right;
        final height = constraints.maxHeight - top - bottom;
        final money = intl.NumberFormat.currency(symbol: '', decimalDigits: 2);

        final salesColor = colorScheme.primary;
        final purchasesColor = colorScheme.tertiary;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _SalesPurchasesLinePainter(
                  points,
                  maxValue,
                  width,
                  height,
                  left,
                  top,
                  salesColor,
                  purchasesColor,
                  colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              ...List.generate(points.length, (i) {
                final point = points[i];
                final x = left + (width * i / (points.length - 1));
                final salesY =
                    top + height - ((point.sales / maxValue) * height);
                final purchasesY =
                    top + height - ((point.purchases / maxValue) * height);

                return Stack(
                  children: [
                    Positioned(
                      left: x - (dense ? 5 : 6),
                      top: salesY - (dense ? 5 : 6),
                      child: Tooltip(
                        message:
                            '${point.label}\n${'Sales'.tr()}: ${money.format(point.sales)}\n${'Purchases'.tr()}: ${money.format(point.purchases)}',
                        child: Container(
                          width: dense ? 10 : 12,
                          height: dense ? 10 : 12,
                          decoration: BoxDecoration(
                            color: salesColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: x - (dense ? 4.5 : 5),
                      top: purchasesY - (dense ? 4.5 : 5),
                      child: Tooltip(
                        message:
                            '${point.label}\n${'Sales'.tr()}: ${money.format(point.sales)}\n${'Purchases'.tr()}: ${money.format(point.purchases)}',
                        child: Container(
                          width: dense ? 9 : 10,
                          height: dense ? 9 : 10,
                          decoration: BoxDecoration(
                            color: purchasesColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              Positioned(
                left: 0,
                right: 0,
                bottom: dense ? 8 : 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(label: 'Sales'.tr(), color: salesColor),
                    SizedBox(width: dense ? 14 : 20),
                    _LegendDot(label: 'Purchases'.tr(), color: purchasesColor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dense = MediaQuery.sizeOf(context).height < 820;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dense ? 10 : 12,
          height: dense ? 10 : 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: dense ? 6 : 8),
        Text(
          label,
          style:
              (dense
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
        ),
      ],
    );
  }
}

class _SalesPurchasesLinePainter extends CustomPainter {
  _SalesPurchasesLinePainter(
    this.points,
    this.maxValue,
    this.width,
    this.height,
    this.left,
    this.top,
    this.salesColor,
    this.purchasesColor,
    this.gridColor,
  );

  final List<TrendPoint> points;
  final double maxValue;
  final double width;
  final double height;
  final double left;
  final double top;
  final Color salesColor;
  final Color purchasesColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (maxValue <= 0 || points.length < 2) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = top + (height * i / 4);
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);
    }

    final salesPath = Path();
    final purchasePath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = left + (width * i / (points.length - 1));
      final salesY = top + height - ((points[i].sales / maxValue) * height);
      final purchasesY =
          top + height - ((points[i].purchases / maxValue) * height);

      if (i == 0) {
        salesPath.moveTo(x, salesY);
        purchasePath.moveTo(x, purchasesY);
      } else {
        salesPath.lineTo(x, salesY);
        purchasePath.lineTo(x, purchasesY);
      }
    }

    canvas.drawPath(
      salesPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            salesColor.withValues(alpha: 0.7),
            salesColor.withValues(alpha: 0.2),
          ],
          stops: const [0.1, 0.9],
        ).createShader(Rect.fromLTWH(0, 0, width, height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.drawPath(
      purchasePath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            purchasesColor.withValues(alpha: 0.7),
            purchasesColor.withValues(alpha: 0.2),
          ],
          stops: const [0.1, 0.9],
        ).createShader(Rect.fromLTWH(0, 0, width, height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _SalesPurchasesLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.salesColor != salesColor ||
        oldDelegate.purchasesColor != purchasesColor ||
        oldDelegate.gridColor != gridColor;
  }
}
