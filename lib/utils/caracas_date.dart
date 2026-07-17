/// Fecha calendario en zona America/Caracas (UTC−4, sin DST).
String caracasDateString([DateTime? date]) {
  final utc = (date ?? DateTime.now()).toUtc();
  final caracas = utc.subtract(const Duration(hours: 4));
  final y = caracas.year.toString().padLeft(4, '0');
  final m = caracas.month.toString().padLeft(2, '0');
  final d = caracas.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

bool isDateInCaracasRange(dynamic startDate, dynamic endDate, [String? dateStr]) {
  final start = startDate?.toString().trim() ?? '';
  final end = endDate?.toString().trim() ?? '';
  if (start.isEmpty || end.isEmpty) return false;
  final today = dateStr ?? caracasDateString();
  return today.compareTo(start) >= 0 && today.compareTo(end) <= 0;
}
