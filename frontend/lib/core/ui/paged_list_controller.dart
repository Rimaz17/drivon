import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../models/paged.dart';

/// The items of a paged list loaded so far.
@immutable
class PagedList<T> {
  const PagedList({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;

  /// The last attempt to load the next page failed; offer a retry.
  final bool loadMoreFailed;

  PagedList<T> copyWith({bool? loadingMore, bool? loadMoreFailed}) => PagedList(
    items: items,
    hasMore: hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// Loads a list endpoint a page at a time. The first page loads on build
/// (and again when the signed-in user changes); [loadMore] appends the next
/// one, keeping what is shown if it fails.
abstract class PagedListController<T> extends AsyncNotifier<PagedList<T>> {
  int _nextPage = 0;

  /// Fetches one page (zero-based).
  Future<Paged<T>> fetchPage(int page);

  @override
  Future<PagedList<T>> build() async {
    ref.watch(currentUserProvider);
    final page = await fetchPage(0);
    _nextPage = 1;
    return PagedList(items: page.items, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await fetchPage(_nextPage);
      _nextPage++;
      if (!ref.mounted) return;
      state = AsyncData(
        PagedList(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
        ),
      );
    } on Object {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(loadMoreFailed: true));
      }
    }
  }
}
