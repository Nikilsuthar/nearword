/// Local-calendar-day helpers. Streaks and daily rewards use the device's
/// local midnight as the day boundary.
class DateHelper {
  DateHelper._();

  /// `yyyy-MM-dd` key for the local day of [date].
  static String dayKey(DateTime date) {
    final d = date.toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Key of the day before [date] (calendar arithmetic, so DST-safe).
  static String previousDayKey(DateTime date) {
    final d = date.toLocal();
    return dayKey(DateTime(d.year, d.month, d.day - 1));
  }
}
