import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localstorage/localstorage.dart';

import '../../utils/date.dart';
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
    if (caches[key] == null) {
      caches[key] = settings ?? FireblazeCacheSettings();
    } else {
      DateTime? latest = caches[key]!.latest;
      caches[key] = settings ?? FireblazeCacheSettings();
      caches[key]!.latest = latest;
    }
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
    Function? action = prepare.action;

    if (prepare.data != null) {
      StreamController<T> controller = StreamController<T>();
      controller.add(prepare.data);

      yield* controller.stream;
    }

    yield* await callback().map((event) {
      if (action != null) action(event);
      return event;
    });
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

    await storage.ready;

    if (caches[key]?.latest == null ||
        DateTime.now().difference(caches[key]!.latest!) >
            caches[key]!.interval) {
      caches[key]!.latest = DateTime.now();

      if (toJson != null || caches[key]!.toJson != null) {
        action = (T value) async {
          dynamic json =
              toJson == null ? caches[key]!.toJson!(value) : toJson(value);

          _convertDates(Map<String, dynamic>? json) {
            json?.forEach((key, value) {
              if (value is DateTime) {
                json[key] = "DATECONV--" + toDateTimeStringDefault(value);
              } else if (value is Timestamp) {
                json[key] =
                    "DATECONV--" + toDateTimeStringDefault(value.toDate());
              } else if (value is Map) {
                json[key] = _convertDates(json[key]);
              }
            });
            return json;
          }

          if (json is List) {
            json = json.map((e) => _convertDates(e)).toList();
          } else {
            json = _convertDates(json);
          }

          try {
            await storage.setItem(key, json);
          } catch (e, stackTrace) {
            print(e);
            print(stackTrace.toString());
            log(json);
          }
        };
      }
    } else {
      if (fromJson != null || caches[key]!.fromJson != null) {
        dynamic result = await storage.getItem(key);

        _reconvertDates(Map<String, dynamic>? json) {
          if (json == null) return null;
          json.forEach((key, value) {
            if (value is Map) {
              json[key] = _reconvertDates(json[key]);
            } else if (value?.toString().contains("DATECONV--") == true) {
              json[key] = Timestamp.fromDate(fromDateTimeString(
                  value!.toString().replaceAll("DATECONV--", "")));
            }
          });
          return json;
        }

        if (result is List) {
          result = result.map((e) => _reconvertDates(e)).toList();
        } else {
          result = _reconvertDates(result);
        }

        data = fromJson == null
            ? caches[key]!.fromJson!(result)
            : fromJson(result);
      }
    }

    return FireblazeCachePrepare<T>(action: action, data: data);
  }
}
