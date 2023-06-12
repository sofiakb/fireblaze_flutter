import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../exceptions/empty_snapshot_exception.dart';
import '../utils/chunk.dart';
import '../utils/date.dart';
import 'prepared_data.dart';

class FirestoreRepository<T> {
  CollectionReference collection;
  FirebaseFirestore instance = FirebaseFirestore.instance;
  Query? query;
  bool softDeletes;

  T? Function(Map<String, Object?> json) casts;

  FirestoreRepository(
      {required this.collection,
      required this.casts,
      this.softDeletes = false});

  T? _cast(Map<String, dynamic>? item) => item == null ? null : casts(item);

  List<T?> _castAll(List docs) => docs.map((e) {
        var data = e.data();
        return data == null ? null : casts(e.data() as Map<String, dynamic>);
      }).toList();

  Future<List<T?>> all() {
    query = collection;
    return softDeletes
        ? this.where(column: "deletedAt", isNull: true).get()
        : this.get();
  }

  FirestoreRepository<T> where({
    required String column,
    dynamic value,
    operator = "==",
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    bool? isNull,
  }) {
    this.query = _query().where(
      column,
      isEqualTo: isEqualTo ?? (operator == '==' ? value : null),
      isNotEqualTo: isNotEqualTo ?? (operator == '!=' ? value : null),
      isLessThan: isLessThan ?? (operator == '<' ? value : null),
      isLessThanOrEqualTo:
          isLessThanOrEqualTo ?? (operator == '<=' ? value : null),
      isGreaterThan: isGreaterThan ?? (operator == '>' ? value : null),
      isGreaterThanOrEqualTo:
          isGreaterThanOrEqualTo ?? (operator == '>=' ? value : null),
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
    //query(this.#snapshot ?? this.#collection, where(column, operator, value));
    return this;
  }

  Future<T?> find(String? docID, {bool cast = true}) async =>
      docID?.isNotEmpty == true
          ? _cast((await collection.doc(docID).get()).data()
              as Map<String, dynamic>?)
          : null;

  Future<T?> findOneByID(String? docID, {bool cast = true}) async =>
      docID?.isNotEmpty == true
          ? _cast((await collection.doc(docID).get()).data()
              as Map<String, dynamic>?)
          : null;

  DocumentReference? documentReference(String? docID) =>
      docID?.isNotEmpty == true ? collection.doc(docID) : null;

  Future<T?> doc(String? docID,
      {bool cast = true, bool withSoftDelete = false}) async {
    if (docID?.isNotEmpty == false) return null;

    return collection.doc(docID).get().then((value) {
      DocumentSnapshot documentData = value;
      return documentData.exists &&
              softDeletes &&
              (withSoftDelete == true ||
                  (documentData.data()
                          as Map<String, dynamic>?)?["deletedAt"] ==
                      null)
          ? _cast(value.data() as Map<String, dynamic>)
          : null;
    });
  }

  Future<bool> exists(String docID) async =>
      (await collection.doc(docID).get()).exists == true;

  String id() => collection.doc().id;

  PreparedData prepareData(Map<String, dynamic> data) {
    data['id'] = data['id'] ?? '';

    data['createdAt'] = toTimestamp(data['createdAt']);
    data['updatedAt'] = toTimestamp(data['updatedAt']);

    if (softDeletes) {
      data["deletedAt"] = data["deletedAt"] != null
          ? toTimestamp(data["deletedAt"] ?? FirestoreRepository._now())
          : null;
    }

    DocumentReference documentReference = data['id'].toString().isNotEmpty
        ? collection.doc(data['id'])
        : collection.doc();

    data['id'] = documentReference.id;

    return PreparedData(
        documentReference: documentReference,
        data: data.map((key, value) =>
            MapEntry(key, value is String && value.isEmpty ? null : value)));
  }

  Future<T?> store(dynamic data) async {
    PreparedData prepared = prepareData(data);
    await prepared.documentReference.set(prepared.data);

    return _cast(prepared.data);
  }

  storeMultiple(List values) async {
    List chunkValues = chunk(values, 500);

    chunkValues.forEach((chunkValue) async {
      WriteBatch batch = instance.batch();

      chunkValue.each((data) {
        PreparedData prepared = this.prepareData(data);
        batch.set(prepared.documentReference, prepared.data);
      });

      await batch.commit();
    });
  }

  Future<T?> update(String docID, Map<String, dynamic> data,
      {bool force = false}) async {
    if (docID.isEmpty) return null;

    DocumentReference? documentReference = this.documentReference(docID);

    if (documentReference != null) {
      data['updatedAt'] = FirestoreRepository._now();
      data.remove("createdAt");
      if (force) {
        await documentReference.set(data.map((key, value) =>
            MapEntry(key, value is String && value.isEmpty ? null : value)));
      } else {
        await documentReference.update(data.map((key, value) =>
            MapEntry(key, value is String && value.isEmpty ? null : value)));
      }
    }

    return this.find(docID);
  }

  Future<bool> delete(String? docID) async {
    if (docID == null || docID.isEmpty) return this._deleteWhere();

    DocumentReference? documentReference = this.documentReference(docID);

    if (documentReference != null) {
      await documentReference.delete();
      return true;
    }

    return false;
  }

  Future<bool> softDelete(String? docID) async {
    if (docID == null || docID.isEmpty) return this._deleteWhere();

    DocumentReference? documentReference = this.documentReference(docID);

    if (documentReference != null) {
      await documentReference.update({"deletedAt": FirestoreRepository._now()});
      return true;
    }

    return false;
  }

  _deleteWhere() async {
    if (query == null) throw new EmptySnapshotException();

    List<Map<String, dynamic>> items =
        (await this.get()) as List<Map<String, dynamic>>;

    items.forEach((doc) => (doc['id'] != null ? this.delete(doc['id']) : null));
  }

  Future<int> count({bool currentQuery = false}) async {
    const int limit = 500;

    int count = 0;

    Query<Object?> query = (currentQuery ? _query() : this.collection)
        .orderBy('id', descending: true)
        .limit(limit);

    QuerySnapshot<Object?> snapshot = await query.get();

    while (snapshot.size > 0) {
      count += snapshot.size;
      snapshot = await query
          .startAfterDocument(snapshot.docs[snapshot.size - 1])
          .get();
    }

    return count;
  }

  FirestoreRepository<T> orderBy(String fieldPath, {bool descending = false}) {
    this.query = _query().orderBy(fieldPath, descending: descending);
    return this;
  }

  FirestoreRepository<T> limit([int limit = 1]) {
    this.query = _query().limit(limit);
    return this;
  }

  FirestoreRepository<T> startAt(startAt) {
    this.query = _query().startAt(startAt is List ? startAt : [startAt]);
    return this;
  }

  FirestoreRepository<T> endAt(endAt) {
    this.query = _query().startAt(endAt is List ? endAt : [endAt]);
    return this;
  }

  FirestoreRepository<T> startAfter(startAfter) {
    this.query =
        _query().startAfter(startAfter is List ? startAfter : [startAfter]);
    return this;
  }

  FirestoreRepository<T> limitToLast([int limit = 1]) {
    this.query = _query().limitToLast(limit);
    return this;
  }

  Future<T?> first() async => (await this.limit(1).get()).firstOrNull;

  Future<List<T?>> get() async {
    if (query == null) {
      return throw new EmptySnapshotException();
    }

    try {
      Query _query = query!;

      var data = await _query.get();
      query = null;
      return _castAll(data.docs);
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot<Object?>> snapshots() {
    if (query == null) {
      return throw new EmptySnapshotException();
    }

    try {
      Query _query = query!;

      Stream<QuerySnapshot<Object?>> querySnapshot = _query.snapshots();
      query = null;
      return querySnapshot;
    } catch (e) {
      rethrow;
    }
  }

  Query _query() => (this.query ?? this.collection);

  static _now() {
    return Timestamp.now().toDate();
  }
}
