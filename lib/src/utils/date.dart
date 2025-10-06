import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

Timestamp toTimestamp(dynamic dateString) {
  DateTime dateValue = DateTime.now();

  if (dateString is String) dateValue = DateTime.parse(dateString);

  return Timestamp.fromDate(dateValue);
}

DateTime? fromDateTimeString(String? dateTimeString) =>
    dateTimeString == null ? null : DateTime.parse(dateTimeString);

String toDateTimeStringDefault(DateTime date) =>
    format(date, 'yyyy-MM-dd HH:mm:ss');

String format(DateTime date, String format) =>
    DateFormat(format, 'fr').format(date);
