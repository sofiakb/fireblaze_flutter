import 'package:localstorage/localstorage.dart' as ls;

const String prefix = "fireblaze_cache_";

class FireblazeCacheSettings<T> {
  DateTime? latest;
  final Duration interval;
  final Function? toJson;
  final Function? fromJson;

  /// Stockage à utiliser. Absent : le `localStorage` global du paquet
  /// localstorage (>= 5), initialisé par [FireblazeCache] avant tout accès.
  /// Les entrées y sont rangées sous la clé `"$prefix<clé du cache>"`.
  final ls.LocalStorage? localStorage;

  FireblazeCacheSettings(
      {this.latest,
      this.interval = const Duration(minutes: 5),
      this.toJson,
      this.fromJson,
      this.localStorage});

  /// Résolu à l'usage : le stockage global n'est lisible qu'après
  /// `initLocalStorage()`.
  ls.LocalStorage get storage => localStorage ?? ls.localStorage;

  FireblazeCacheSettings copyWith(
      {DateTime? latest,
      Duration? interval,
      Function? toJson,
      Function? fromJson,
      ls.LocalStorage? localStorage}) {
    return FireblazeCacheSettings(
        latest: latest ?? this.latest,
        interval: interval ?? this.interval,
        toJson: toJson ?? this.toJson,
        fromJson: fromJson ?? this.fromJson,
        localStorage: localStorage ?? this.localStorage);
  }
}
