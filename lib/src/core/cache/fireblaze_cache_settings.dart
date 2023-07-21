class FireblazeCacheSettings {
  DateTime? latest;
  final Duration interval;

  FireblazeCacheSettings(
      {this.latest, this.interval = const Duration(minutes: 5)});
}