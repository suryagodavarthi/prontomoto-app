// date_format.dart
// Every date the app shows is day-first, DD-MM-YYYY, as the portal shows it.
// Mirrors prontofirebase's src/app/shared/date-format.ts.

import 'package:intl/intl.dart';

/// "2024-05-15T00:00:00Z" → "15-05-2024". Empty when unparseable.
String formatDdMmYyyy(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final d = DateTime.tryParse(value.trim())?.toLocal();
  return d == null ? '' : DateFormat('dd-MM-yyyy').format(d);
}

/// As above, with a 24-hour clock: "15-05-2024 14:30".
String formatDdMmYyyyHhMm(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final d = DateTime.tryParse(value.trim())?.toLocal();
  return d == null ? '' : DateFormat('dd-MM-yyyy HH:mm').format(d);
}
