import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart' as ls;
import 'package:sofiakb_fireblaze_flutter/src/utils/functions.dart';

import 'fireblaze_cache_prepare.dart';
import 'fireblaze_cache_settings.dart';

class FireblazeCache {
  static final FireblazeCache instance = FireblazeCache._internal();

  factory FireblazeCache() {
    return instance;
  }

  FireblazeCache._internal();

  final Map<String, FireblazeCacheSettings> caches = {};

  /// Initialisation unique du stockage global de localstorage (>= 5).
  static Future<void>? _storageInit;

  void add(String key, [FireblazeCacheSettings? settings]) {
    settings ??= FireblazeCacheSettings();
    caches[key] = caches[key] == null
        ? settings
        : settings.copyWith(
            localStorage: caches[key]!.localStorage,
            latest: caches[key]!.latest,
          );
  }

  /// Clé de l'entrée dans le stockage, partagé entre tous les caches.
  String storageKey(String key) => "$prefix$key";

  Future<void> _ensureStorage(FireblazeCacheSettings settings) async {
    if (settings.localStorage != null) return;
    _storageInit ??= ls.initLocalStorage();
    await _storageInit;
  }

  bool hasKey(String key) => caches.containsKey(key);

  void invalidate(String key) => caches[key]?.latest = null;

  Future<FireblazeCachePrepare> _prepare<T>(String key,
      {bool refresh = false, Function? toJson, Function? fromJson}) async {
    if (!hasKey(key)) {
      add(key);
    }

    if (refresh) {
      invalidate(key);
    }

    T? data;
    Function? action;

    await _ensureStorage(caches[key]!);

    if (caches[key]?.latest == null ||
        DateTime.now().difference(caches[key]!.latest!).inMinutes >
            caches[key]!.interval.inMinutes) {
      caches[key]!.latest = DateTime.now();

      if (toJson != null || caches[key]!.toJson != null) {
        action = (T value) async {
          if (caches[key]!.toJson == null && toJson == null) {
            return;
          }

          dynamic json =
              toJson == null ? caches[key]?.toJson!(value) : toJson(value);

          json = toEncodable(json);

          try {
            caches[key]!.storage.setItem(
                storageKey(key),
                jsonEncode(json,
                    toEncodable: (object) =>
                        (object is Iterable
                            ? object
                                .map((e) =>
                                    convertDates(e as Map<String, dynamic>))
                                .toList()
                            : convertDates(object as Map<String, dynamic>)) ??
                        {}));
          } catch (e, stackTrace) {
            debugPrint(e.toString());
            debugPrintStack(stackTrace: stackTrace);
          }
        };
      }
    } else {
      if (fromJson != null || caches[key]!.fromJson != null) {
        final String? raw = caches[key]!.storage.getItem(storageKey(key));
        dynamic result = raw == null ? null : jsonDecode(raw);

        if (result is List) {
          result = result.map((e) => reconvertDates(e)).toList();
        } else {
          result = reconvertDates(result);
        }

        data = fromJson == null
            ? caches[key]!.fromJson!(result)
            : fromJson(result);
      }
    }

    return FireblazeCachePrepare<T>(action: action, data: data);
  }

  Stream<T> snapshots<T>(String key,
      {required Stream<T> Function() callback, bool refresh = false}) async* {
    FireblazeCachePrepare prepare = await _prepare<T>(key, refresh: refresh);
    Function? action = prepare.action;

    if (prepare.data != null) {
      StreamController<T> controller = StreamController<T>();
      controller.add(prepare.data);

      yield* controller.stream;
    } else {
      yield* callback().map((event) {
        if (action != null) action(event);
        return event;
      });
    }
  }

  Future<T> get<T>(String key,
      {required Future<T> Function() callback, bool refresh = false}) async {
    FireblazeCachePrepare prepare = await _prepare<T>(key, refresh: refresh);
    Function? action = prepare.action;

    if (prepare.data != null) {
      return prepare.data;
    }

    return await callback().then((data) {
      if (action != null) action(data);
      return data;
    });
  }
}
