import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class DateFilterButton extends StatelessWidget {
  const DateFilterButton({
    required this.label,
    required this.value,
    required this.onPick,
    super.key,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (dialogContext, child) {
            return Theme(
              data: Theme.of(dialogContext).copyWith(
                colorScheme: Theme.of(
                  dialogContext,
                ).colorScheme.copyWith(primary: colorScheme.primary),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onPick(picked);
      },
      icon: Icon(Icons.calendar_today_outlined, color: colorScheme.primary),
      label: Text(
        '$label: ${intl.DateFormat('yyyy-MM-dd').format(value)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
