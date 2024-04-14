import 'package:cloud_firestore/cloud_firestore.dart';

import 'date.dart';

Map<String, dynamic>? convertDates(Map<String, dynamic>? json) {
  json?.forEach((key, value) {
    if (value is DateTime) {
      json[key] = "DATECONV--${toDateTimeStringDefault(value)}";
    } else if (value is Timestamp) {
      json[key] =
          "DATECONV--${toDateTimeStringDefault(value.toDate())}";
    } else if (value is Map) {
      json[key] = convertDates(json[key]);
    } else if (value is List) {
      json[key] = json[key].map((m) => convertDates(m)).toList();
    }
  });
  return json;
}

Map<String, dynamic>? reconvertDates(Map<String, dynamic>? json) {
  if (json == null) return null;
  json.forEach((key, value) {
    if (value is Map) {
      json[key] = reconvertDates(json[key]);
    } else if (value is List) {
      json[key] = json[key].map((m) => reconvertDates(m)).toList();
    } else if (value?.toString().contains("DATECONV--") == true) {
      json[key] = Timestamp.fromDate(fromDateTimeString(
          value!.toString().replaceAll("DATECONV--", "")));
    }
  });
  return json;
}

Object toEncodable(object) =>
    (object is Iterable
        ? object
        .map((e) => convertDates(e as Map<String, dynamic>))
        .toList()
        : convertDates(object as Map<String, dynamic>)) ??
        {};