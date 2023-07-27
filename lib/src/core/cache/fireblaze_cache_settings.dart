class FireblazeCacheSettings<T> {
  DateTime? latest;
  final Duration interval;
  final dynamic Function(T)? toJson;
  final T Function(dynamic)? fromJson;

  FireblazeCacheSettings(
      {this.latest, this.interval = const Duration(minutes: 5), this.toJson, this.fromJson});
}