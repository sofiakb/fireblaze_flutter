List chunk<T>(List<T> list, int chunkSize) {
  List<List<T>> chunks = [];
  int len = list.length;
  for (var i = 0; i < len; i += chunkSize) {
    int size = i + chunkSize;
    chunks.add(list.sublist(i, size > len ? len : size));
  }
  return chunks;
}
