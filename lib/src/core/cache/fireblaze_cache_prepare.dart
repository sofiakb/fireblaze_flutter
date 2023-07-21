class FireblazeCachePrepare {
  Future<void> Function() action;
  Future<void> Function() reverseAction;

  FireblazeCachePrepare({required this.action, required this.reverseAction});
}