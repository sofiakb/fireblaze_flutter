import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:localstorage/localstorage.dart';
import 'package:sofiakb_fireblaze_flutter/sofiakb_fireblaze_flutter.dart';

/// Stockage en mémoire conforme à l'interface de localstorage >= 5.
class MemoryStorage implements LocalStorage {
  final Map<String, String> items = {};

  @override
  int get length => items.length;

  @override
  String? key(int index) => items.keys.elementAt(index);

  @override
  String? getItem(String key) => items[key];

  @override
  void setItem(String key, String value) => items[key] = value;

  @override
  void removeItem(String key) => items.remove(key);

  @override
  void clear() => items.clear();
}

void main() {
  // Les dates sont sérialisées avec DateFormat(..., 'fr').
  setUpAll(() => initializeDateFormatting('fr'));

  test('get() stocke en JSON puis relit depuis le cache, dates comprises',
      () async {
    final storage = MemoryStorage();
    const key = 'test/roundTrip';
    FireblazeCache.instance.add(
      key,
      FireblazeCacheSettings<List<Map<String, dynamic>>>(
        toJson: (List<Map<String, dynamic>> v) =>
            v.map((e) => Map<String, dynamic>.of(e)).toList(),
        fromJson: (dynamic r) => (r as List).cast<Map<String, dynamic>>(),
        localStorage: storage,
      ),
    );

    int calls = 0;
    Future<List<Map<String, dynamic>>> remote() async {
      calls++;
      return [
        {'name': 'janaza', 'at': DateTime(2026, 10, 27, 14, 30)}
      ];
    }

    final first = await FireblazeCache.instance
        .get<List<Map<String, dynamic>>>(key, callback: remote);
    expect(calls, 1);
    expect(first.single['name'], 'janaza');
    expect(storage.items.keys, ['fireblaze_cache_$key']);

    final second = await FireblazeCache.instance
        .get<List<Map<String, dynamic>>>(key, callback: remote);
    expect(calls, 1, reason: 'servi par le cache');
    expect(second.single['name'], 'janaza');
    expect(second.single['at'], isA<Timestamp>());
    expect((second.single['at'] as Timestamp).toDate(),
        DateTime(2026, 10, 27, 14, 30));
  });

  test('add() sur une clé existante garde toJson/fromJson et le stockage', () {
    final storage = MemoryStorage();
    const key = 'test/readd';
    toJson(v) => v;
    fromJson(v) => v;
    FireblazeCache.instance.add(key,
        FireblazeCacheSettings(toJson: toJson, localStorage: storage));
    FireblazeCache.instance
        .add(key, FireblazeCacheSettings(toJson: toJson, fromJson: fromJson));
    final settings = FireblazeCache.instance.caches[key]!;
    expect(settings.toJson, toJson);
    expect(settings.fromJson, fromJson);
    expect(settings.localStorage, same(storage));
  });
}
