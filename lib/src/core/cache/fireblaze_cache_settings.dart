import 'package:localstorage/localstorage.dart';

const String prefix = "fireblaze_cache_";

class FireblazeCacheSettings<T> {
  DateTime? latest;
  final Duration interval;
  final Function? toJson;
  final Function? fromJson;
  final LocalStorage? localStorage;

  late LocalStorage? storage;

  FireblazeCacheSettings(
      {this.latest,
      this.interval = const Duration(minutes: 5),
      this.toJson,
      this.fromJson,
      this.localStorage}) {
    storage = localStorage ?? LocalStorage(prefix);
  }

  FireblazeCacheSettings copyWith({DateTime? latest, Duration? interval, LocalStorage? localStorage}) {
    return FireblazeCacheSettings(
      latest: latest ?? this.latest,
      interval: interval ?? this.interval,
      localStorage: localStorage ?? this.localStorage
    );
  }
}
