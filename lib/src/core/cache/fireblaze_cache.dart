import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'fireblaze_cache_prepare.dart';
import 'fireblaze_cache_settings.dart';

class FireblazeCache {
  static final FireblazeCache instance = FireblazeCache._internal();

  factory FireblazeCache() {
    return instance;
  }

  FireblazeCache._internal();

  final Map<String, FireblazeCacheSettings> caches = {};

  void add(String key, [FireblazeCacheSettings? settings]) {
    caches[key] = settings ?? FireblazeCacheSettings();
  }

  bool hasKey(String key) {
    return caches.containsKey(key);
  }

  void invalidate(String key) {
    caches[key]?.latest = null;
  }

  Stream<T> snapshots<T>(String key,
      {required Stream<T> Function() callback, bool refresh = false}) async* {
    FireblazeCachePrepare prepare = _prepare(key, refresh: refresh);
    Future<void> Function() action = prepare.action;
    Future<void> Function() reverseAction = prepare.reverseAction;

    yield* await action().then((value) => callback().map((event) {
          reverseAction();
          return event;
        }));
  }

  Future<T> get<T>(String key,
      {required Future<T> Function() callback, bool refresh = false}) async {
    FireblazeCachePrepare prepare = _prepare(key, refresh: refresh);
    Future<void> Function() action = prepare.action;
    Future<void> Function() reverseAction = prepare.reverseAction;

    return await action().then((value) => callback().then((data) {
          reverseAction();
          return data;
        }));
  }

  FireblazeCachePrepare _prepare(String key, {bool refresh = false}) {
    if (!hasKey(key)) {
      add(key);
    }

    if (refresh) {
      invalidate(key);
    }

    Future<void> Function()? action;
    Future<void> Function()? reverseAction;

    if (caches[key]?.latest == null ||
        DateTime.now().difference(caches[key]!.latest!) >
            caches[key]!.interval) {
      caches[key]!.latest = DateTime.now();
      action = FirebaseFirestore.instance.enableNetwork;
      reverseAction = FirebaseFirestore.instance.disableNetwork;
    } else {
      if (kIsWeb) {
        FirebaseFirestore.instance.enablePersistence(
            const PersistenceSettings(synchronizeTabs: true));
      }
      FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
      action = FirebaseFirestore.instance.disableNetwork;
      reverseAction = FirebaseFirestore.instance.enableNetwork;
    }

    return FireblazeCachePrepare(action: action, reverseAction: reverseAction);
  }
}
