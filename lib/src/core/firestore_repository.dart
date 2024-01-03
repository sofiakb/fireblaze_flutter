import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../exceptions/empty_snapshot_exception.dart';
import '../utils/chunk.dart';
import '../utils/date.dart';
import 'model.dart';
import 'prepared_data.dart';

class FirestoreRepository<T extends Model> {
  CollectionReference collection;
  FirebaseFirestore instance = FirebaseFirestore.instance;
  Query? query;
  bool softDeletes;

  CollectionReference? _collectionReference;

  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  FirestoreRepository(
      {required this.collection,
      required this.fromJson,
      required this.toJson,
      this.softDeletes = false}) {
    _collectionReference = collection;
  }

  Future<List<T?>> all() {
    query = collection;
    return this.get();
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

  Future<T?> find(String? docID) async => docID?.isNotEmpty == true
      ? (await _refDocumentReferenceWithConverter(collection.doc(docID)).get())
          .data()
      : null;

  Future<T?> findOneByID(String? docID) async => find(docID);

  DocumentReference? documentReference(String? docID) =>
      docID?.isNotEmpty == true ? collection.doc(docID) : null;

  Future<T?> doc(String? docID, {bool withSoftDelete = false}) async {
    if (docID?.isNotEmpty == false) return null;

    return _refDocumentReferenceWithConverter(collection.doc(docID))
        .get()
        .then((DocumentSnapshot<T?> value) {
      DocumentSnapshot<T?> documentData = value;
      return documentData.exists &&
              softDeletes &&
              (withSoftDelete == true || documentData.data()?.deletedAt == null)
          ? value.data()
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

    return fromJson(prepared.data);
  }

  Future<T?> updateOrCreate(dynamic data) async {
    PreparedData prepared = prepareData(data);

    await update(prepared.documentReference.id, prepared.data)
        .onError((error, stackTrace) async {
      await store(data);
      return null;
    });

    // await prepared.documentReference.set(
    //     prepared.data,
    //     SetOptions(
    //         mergeFields: prepared.data.keys
    //             .toList()
    //             .whereNot((element) => element == "createdAt")
    //             .whereType<String>()
    //             .toList()));

    return fromJson(prepared.data);
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

    print("before update");
    print((await documentReference?.get())?.data());

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

    print("after update");
    print((await documentReference?.get())?.data());

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

    List<T?> items = (await this.get());

    items.forEach((doc) => (doc?.id != null ? this.delete(doc?.id) : null));
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
    this.query = _query().endAt(endAt is List ? endAt : [endAt]);
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

  queryHasParameter(String parameter) =>
      query == null ? false : query!.parameters.containsKey(parameter);

  Query<T?> _refQueryWithConverter(Query query) => query.withConverter(
      fromFirestore: _fromFirestoreSnapshot, toFirestore: _toFirestore);

  DocumentReference<T?> _refDocumentReferenceWithConverter(
          DocumentReference query) =>
      query.withConverter(
          fromFirestore: _fromFirestoreSnapshot, toFirestore: _toFirestore);

  T? _fromFirestoreSnapshot(
      DocumentSnapshot snapshot, SnapshotOptions? options) {
    Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
    return snapshot.exists && data != null ? fromJson(data) : null;
  }

  Map<String, Object?> _toFirestore(T? object, SetOptions? options) =>
      object != null ? prepareData(toJson(object)).data : {};

  Future<List<T?>> get() async {
    if (query == null) {
      return throw new EmptySnapshotException();
    }

    try {
      Query _query = query!;

      QuerySnapshot<T?> data = await _refQueryWithConverter(
              (softDeletes && !queryHasParameter("deletedAt")
                  ? _query.where("deletedAt", isNull: true)
                  : _query))
          .get();
      _reset();
      return data.docs.map((e) => e.data()).toList();
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

      Stream<QuerySnapshot<Object?>> querySnapshot =
          _refQueryWithConverter(_query).snapshots();
      _reset();
      return querySnapshot;
    } catch (e) {
      rethrow;
    }
  }

  _reset() {
    query = null;
    collection = _collectionReference!;
    return this;
  }

  Query _query() => (this.query ?? this.collection);

  static _now() => Timestamp.now().toDate();
}
