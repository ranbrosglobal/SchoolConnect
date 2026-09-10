/// Converts a 24-hour time string ("09:00:00" or "09:00") to 12-hour
/// "h:mm AM/PM" form (no seconds). Returns '' for null/empty/unparseable input.
String formatTime12h(String? time) {
  if (time == null || time.trim().isEmpty) return '';
  final parts = time.trim().split(':');
  final hour = int.tryParse(parts[0]);
  if (hour == null || hour < 0 || hour > 23) return '';
  final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final period = hour < 12 ? 'AM' : 'PM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  return '$h12:$mm $period';
}
