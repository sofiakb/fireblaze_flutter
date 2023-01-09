import 'package:cloud_firestore/cloud_firestore.dart';

Timestamp toTimestamp(dynamic dateString) {
  DateTime dateValue = DateTime.now();

  if (dateString is String) dateValue = DateTime.parse(dateString);

  return Timestamp.fromDate(dateValue);
}
