import 'package:localstorage/localstorage.dart';

import 'fireblaze_cache_prepare.dart';
import 'fireblaze_cache_settings.dart';

class FireblazeCache {
  static final FireblazeCache instance = FireblazeCache._internal();

  factory FireblazeCache() {
    return instance;
  }

  FireblazeCache._internal();

  final Map<String, FireblazeCacheSettings> caches = {};
  final LocalStorage storage = LocalStorage("fireblaze_cache");

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
    FireblazeCachePrepare prepare = await _prepare<T>(key, refresh: refresh);
    Future<void> Function(T)? action = prepare.action;

    if (prepare.data != null) {
      yield* prepare.data;
    }

    yield* await callback().map((event) {
      if (action != null) action(event);
      return event;
    });
  }

  Future<T> get<T>(String key,
      {required Future<T> Function() callback, bool refresh = false}) async {
    FireblazeCachePrepare prepare = await _prepare<T>(key, refresh: refresh);
    Future<void> Function(T)? action = prepare.action;

    if (prepare.data != null) {
      return prepare.data;
    }

    return await callback().then((data) {
      if (action != null) action(data);
      return data;
    });
  }

  Future<FireblazeCachePrepare> _prepare<T>(String key,
      {bool refresh = false,
      Function? toJson,
      Function? fromJson}) async {
    if (!hasKey(key)) {
      add(key);
    }

    if (refresh) {
      invalidate(key);
    }

    T? data;
    Future<void> Function(T)? action;

    await storage.ready;

    if (caches[key]?.latest == null ||
        DateTime.now().difference(caches[key]!.latest!) >
            caches[key]!.interval) {
      caches[key]!.latest = DateTime.now();

      if (toJson != null || caches[key]!.toJson != null) {
        action = (T value) async => await storage.setItem(
            key, toJson == null ? caches[key]!.toJson!(value) : toJson(value));
      }
    } else {
      if (fromJson != null || caches[key]!.fromJson != null) {
        var result = await storage.getItem(key);
        data = fromJson == null
            ? caches[key]!.fromJson!(result)
            : fromJson(result);
      }
    }

    return FireblazeCachePrepare<T>(action: action, data: data);
  }
}
