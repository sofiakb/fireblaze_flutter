class FireblazeCachePrepare<T> {
  T? data;
  Future<void> Function(T)? action;

  FireblazeCachePrepare({required this.data, required this.action});
}