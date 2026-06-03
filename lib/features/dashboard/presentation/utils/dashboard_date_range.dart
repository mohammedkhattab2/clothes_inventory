class DashboardDateRange {
  DashboardDateRange._();

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static ({DateTime from, DateTime to}) forGranularity(
    String granularity, {
    DateTime? anchor,
  }) {
    final today = dateOnly(anchor ?? DateTime.now());
    switch (granularity) {
      case 'week':
        return (
          from: today.subtract(Duration(days: today.weekday - 1)),
          to: today,
        );
      case 'month':
        return (from: DateTime(today.year, today.month, 1), to: today);
      case 'day':
      default:
        return (from: today, to: today);
    }
  }
}
