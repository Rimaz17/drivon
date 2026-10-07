import 'package:flutter/foundation.dart';

/// One page of a list endpoint: its items and whether more pages follow.
@immutable
class Paged<T> {
  const Paged({required this.items, required this.hasMore});

  /// Reads the API's `{content, hasNext, ...}` page, converting each item.
  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItem,
  ) => Paged(
    items: (json['content'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(fromItem)
        .toList(),
    hasMore: json['hasNext'] as bool,
  );

  final List<T> items;
  final bool hasMore;

  Paged<R> map<R>(R Function(T item) convert) =>
      Paged(items: items.map(convert).toList(), hasMore: hasMore);
}
