import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import 'paged_list_controller.dart';

/// The end of a paged list: a "Show more" button while more pages exist, a
/// spinner while one loads, and a retry with [failedMessage] if it failed.
/// Renders nothing once everything is loaded.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    required this.list,
    required this.onLoadMore,
    required this.failedMessage,
    super.key,
  });

  final PagedList<Object?> list;
  final VoidCallback onLoadMore;
  final String failedMessage;

  @override
  Widget build(BuildContext context) {
    if (!list.hasMore) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DrivonSpacing.md),
      child: list.loadingMore
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.loadingMore,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.loadMoreFailed) ...[
                  InlineNotice(message: failedMessage),
                  const SizedBox(height: DrivonSpacing.sm),
                ],
                OutlinedButton(
                  onPressed: onLoadMore,
                  child: Text(
                    list.loadMoreFailed
                        ? l10n.retryAction
                        : l10n.showMoreAction,
                  ),
                ),
              ],
            ),
    );
  }
}
