import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/services/url_opener.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/vehicle_document.dart';
import 'document_controllers.dart';
import 'document_labels.dart';
import 'widgets/expiry_chip.dart';

/// One document: its file (a zoomable photo, or a PDF to open in a viewer)
/// on the canvas and its details on the sheet, with edit and delete.
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({
    required this.vehicleId,
    required this.documentId,
    super.key,
  });

  final String vehicleId;
  final String documentId;

  DocumentKey get _key => (vehicleId: vehicleId, documentId: documentId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(documentProvider(_key))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(),
            body: LoadingState(semanticsLabel: l10n.loadingRecord),
          ),
          error: (error, _) {
            final missing =
                error is ApiProblemException &&
                (error.code == ApiErrorCodes.documentNotFound ||
                    error.code == ApiErrorCodes.vehicleNotFound);
            return Scaffold(
              appBar: AppBar(),
              body: missing
                  ? ErrorState(
                      title: l10n.errorDocumentNotFound,
                      message: l10n.recordMissingMessage,
                      retryLabel: l10n.backAction,
                      onRetry: () => context.pop(),
                    )
                  : ErrorState(
                      title: l10n.recordLoadErrorTitle,
                      message: errorText(l10n, error),
                      retryLabel: l10n.retryAction,
                      onRetry: () => ref.invalidate(documentProvider(_key)),
                    ),
            );
          },
          data: (document) => _Detail(document: document, documentKey: _key),
        );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.document, required this.documentKey});

  final VehicleDocument document;
  final DocumentKey documentKey;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _deleting = false;

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteDocumentTitle,
      message: l10n.deleteDocumentMessage,
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(documentMutationsProvider)
          .remove(widget.documentKey.vehicleId, widget.document.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.documentDeleted)));
      if (mounted) context.pop();
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l10n, error))));
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final document = widget.document;
    return Scaffold(
      appBar: AppBar(
        title: Text(document.type.label(l10n)),
        actions: [
          IconButton(
            tooltip: l10n.editDocumentTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _deleting
                ? null
                : () => context.push(
                    AppRoutes.editDocumentPath(
                      widget.documentKey.vehicleId,
                      document.id,
                    ),
                  ),
          ),
          IconButton(
            tooltip: l10n.deleteDocumentTooltip,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: SheetScrollView(
            header: [
              if (document.isPdf)
                _PdfCard(document: document, documentKey: widget.documentKey)
              else
                _PhotoPreview(
                  document: document,
                  documentKey: widget.documentKey,
                ),
            ],
            sheet: [
              SectionTitle(l10n.documentDetailsTitle),
              const SizedBox(height: DrivonSpacing.sm),
              _Details(document: document),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo, pinch-to-zoom, loaded through a short-lived link.
class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.document, required this.documentKey});

  final VehicleDocument document;
  final DocumentKey documentKey;

  static const double _height = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final url = ref.watch(documentFileUrlProvider(documentKey));
    void retry() => ref.invalidate(documentFileUrlProvider(documentKey));
    Widget failed() => ErrorState(
      title: l10n.fileLoadFailed,
      message: l10n.errorGeneric,
      retryLabel: l10n.retryAction,
      onRetry: retry,
    );

    return SizedBox(
      height: _height,
      child: ClipRRect(
        borderRadius: DrivonRadii.lgAll,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: url.when(
            loading: () => LoadingState(semanticsLabel: l10n.loadingFile),
            error: (error, _) => ErrorState(
              title: l10n.fileLoadFailed,
              message: errorText(l10n, error),
              retryLabel: l10n.retryAction,
              onRetry: retry,
            ),
            data: (uri) => Semantics(
              image: true,
              label: l10n.documentImageSemantics(
                document.type.label(l10n).toLowerCase(),
              ),
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  uri.toString(),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: _height,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : LoadingState(semanticsLabel: l10n.loadingFile),
                  errorBuilder: (context, error, stackTrace) => failed(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// PDFs open in the phone's own viewer with a fresh short-lived link.
class _PdfCard extends ConsumerStatefulWidget {
  const _PdfCard({required this.document, required this.documentKey});

  final VehicleDocument document;
  final DocumentKey documentKey;

  @override
  ConsumerState<_PdfCard> createState() => _PdfCardState();
}

class _PdfCardState extends ConsumerState<_PdfCard> {
  bool _opening = false;

  Future<void> _open() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    try {
      // A new link each time: the previous one may have expired.
      ref.invalidate(documentFileUrlProvider(widget.documentKey));
      final url = await ref.read(
        documentFileUrlProvider(widget.documentKey).future,
      );
      final opened = await ref.read(urlOpenerProvider).openExternally(url);
      if (!opened) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.openPdfFailed)));
      }
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l10n, error))));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DrivonCard(
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 40,
                    color: context.drivonColors.accentText,
                  ),
                  const SizedBox(width: DrivonSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.fileKindPdf} · ${fileSizeLabel(context, l10n, widget.document.sizeBytes)}',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DrivonSpacing.xxs),
                        Text(l10n.pdfCardCaption, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DrivonSpacing.lg),
              PrimaryButton(
                label: l10n.openPdfAction,
                busy: _opening,
                busyLabel: l10n.loadingFile,
                onPressed: _open,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Label and value pairs on the sheet.
class _Details extends StatelessWidget {
  const _Details({required this.document});

  final VehicleDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = today();
    final issueDate = document.issueDate;
    final expiryDate = document.expiryDate;
    final notes = document.notes;
    final rows = <(String, Widget)>[
      (l10n.documentTypeLabel, _value(context, document.type.label(l10n))),
      if (issueDate != null)
        (l10n.issuedLabel, _value(context, formatDate(context, issueDate))),
      (
        l10n.expiresLabel,
        expiryDate == null
            ? _value(context, l10n.noExpiryDetail)
            : Wrap(
                spacing: DrivonSpacing.sm,
                runSpacing: DrivonSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _value(context, formatDate(context, expiryDate)),
                  ExpiryChip(state: document.expiryState(now)),
                ],
              ),
      ),
      (
        l10n.fileSectionTitle,
        _value(
          context,
          '${document.isPdf ? l10n.fileKindPdf : l10n.fileKindPhoto} · '
          '${fileSizeLabel(context, l10n, document.sizeBytes)}',
        ),
      ),
      if (notes != null && notes.isNotEmpty)
        (l10n.notesTitle, _value(context, notes)),
    ];
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, (label, value)) in rows.indexed) ...[
          if (index > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DrivonSpacing.md),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.bodySmall),
                  const SizedBox(height: DrivonSpacing.xxs),
                  value,
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Widget _value(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge);
}
