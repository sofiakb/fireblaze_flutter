class FireblazeCacheSettings<T> {
  DateTime? latest;
  final Duration interval;
  final Map<String, dynamic> Function(T)? toJson;
  final T Function(Map<String, dynamic>)? fromJson;

  FireblazeCacheSettings(
      {this.latest, this.interval = const Duration(minutes: 5), this.toJson, this.fromJson});
}