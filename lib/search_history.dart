import 'package:flutter/foundation.dart';

/// In-memory recent searches. Newest first, max [_max] entries, no duplicates.
class SearchHistory extends ChangeNotifier {
  SearchHistory._();

  static final SearchHistory instance = SearchHistory._();

  static const int _max = 8;
  final List<String> _items = [];

  List<String> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    _items.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    _items.insert(0, q);
    if (_items.length > _max) {
      _items.removeRange(_max, _items.length);
    }
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}



