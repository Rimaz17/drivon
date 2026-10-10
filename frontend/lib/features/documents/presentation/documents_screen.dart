import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/load_more_footer.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/vehicle_document.dart';
import 'document_controllers.dart';
import 'widgets/document_tile.dart';
import 'widgets/expiry_attention_card.dart';

/// A vehicle's documents: the one that needs attention first on the canvas,
/// every stored document as rows on the sheet.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({required this.vehicleId, super.key});

  final String vehicleId;

  /// Space below the list so the last row clears the floating button.
  static const double _fabClearance = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(documentListProvider(vehicleId));
    final expiring = ref.watch(expiringDocumentsProvider);
    final now = today();

    void open(VehicleDocument document) =>
        context.push(AppRoutes.documentPath(vehicleId, document.id));
    void add() => context.push(AppRoutes.addDocumentPath(vehicleId));
    void retry() => ref
      ..invalidate(documentListProvider(vehicleId))
      ..invalidate(expiringDocumentsProvider);

    final hasDocuments = list.value?.items.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      floatingActionButton: hasDocuments
          ? FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addDocumentAction),
            )
          : null,
      body: SafeArea(
        child: list.when(
          loading: () => LoadingState(semanticsLabel: l10n.loadingDocuments),
          error: (error, _) => ErrorState(
            title: l10n.documentsLoadErrorTitle,
            message: errorText(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: retry,
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return EmptyState(
                icon: Icons.folder_open_outlined,
                title: l10n.documentsEmptyTitle,
                message: l10n.documentsEmptyMessage,
                actionLabel: l10n.addDocumentAction,
                onAction: add,
              );
            }
            final attention = [
              for (final document
                  in expiring.value ?? const <VehicleDocument>[])
                if (document.vehicleId == vehicleId) document,
            ];
            return RefreshIndicator.adaptive(
              onRefresh: () async {
                retry();
                await ref.read(documentListProvider(vehicleId).future);
              },
              child: ContentWidth(
                child: SheetScrollView(
                  bottomPadding: _fabClearance,
                  header: [
                    if (attention.isNotEmpty)
                      ExpiryAttentionCard(
                        documents: attention,
                        today: now,
                        onOpen: open,
                      )
                    else if (expiring.hasValue)
                      _AllCurrent(),
                  ],
                  sheet: [
                    SectionTitle(l10n.storedDocumentsTitle),
                    const SizedBox(height: DrivonSpacing.xs),
                    for (final (index, document) in page.items.indexed) ...[
                      if (index > 0) const Divider(),
                      DocumentTile(
                        document: document,
                        today: now,
                        onTap: () => open(document),
                      ),
                    ],
                    LoadMoreFooter(
                      list: page,
                      failedMessage: l10n.documentsLoadMoreFailed,
                      onLoadMore: () => ref
                          .read(documentListProvider(vehicleId).notifier)
                          .loadMore(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A calm line on the canvas when nothing expires soon.
class _AllCurrent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.drivonColors;
    return Semantics(
      label: l10n.documentsAllCurrentSemantics,
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: colors.success),
          const SizedBox(width: DrivonSpacing.sm),
          Expanded(
            child: Text(
              l10n.documentsAllCurrent,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
