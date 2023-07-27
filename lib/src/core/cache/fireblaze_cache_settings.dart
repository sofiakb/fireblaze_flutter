class FireblazeCacheSettings<T> {
  DateTime? latest;
  final Duration interval;
  final Function? toJson;
  final Function? fromJson;

  FireblazeCacheSettings(
      {this.latest, this.interval = const Duration(minutes: 5), this.toJson, this.fromJson});
}