import 'package:cloud_firestore/cloud_firestore.dart';

class PreparedData {
  DocumentReference documentReference;
  Map<String, dynamic> data;

  PreparedData({required this.documentReference, required this.data});
}
