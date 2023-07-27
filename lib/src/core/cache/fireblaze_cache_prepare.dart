class FireblazeCachePrepare<T> {
  T? data;
  Future<void> Function(dynamic)? action;

  FireblazeCachePrepare({required this.data, required this.action});
}