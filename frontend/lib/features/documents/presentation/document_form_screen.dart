import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/services/picked_file.dart';
import '../../../core/ui/date_form_field.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/ui/text_field_helpers.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../data/document_repository.dart';
import '../domain/vehicle_document.dart';
import 'document_controllers.dart';
import 'document_labels.dart';

/// Adds a document with its file for [vehicleId], or edits the details of
/// [documentId] (its file stays the same).
class DocumentFormScreen extends ConsumerWidget {
  const DocumentFormScreen({
    required this.vehicleId,
    this.documentId,
    super.key,
  });

  final String vehicleId;
  final String? documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = documentId;
    if (id == null) return _DocumentForm(vehicleId: vehicleId);

    final l10n = AppLocalizations.of(context);
    final key = (vehicleId: vehicleId, documentId: id);
    return ref
        .watch(documentProvider(key))
        .when(
          data: (document) =>
              _DocumentForm(vehicleId: vehicleId, initial: document),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.editDocumentTitle)),
            body: LoadingState(semanticsLabel: l10n.loadingRecord),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text(l10n.editDocumentTitle)),
            body: ErrorState(
              title: l10n.recordLoadErrorTitle,
              message: errorText(l10n, error),
              retryLabel: l10n.retryAction,
              onRetry: () => ref.invalidate(documentProvider(key)),
            ),
          ),
        );
  }
}

abstract final class _Fields {
  static const type = 'type';
  static const issueDate = 'issueDate';
  static const expiryDate = 'expiryDate';
  static const notes = 'notes';
}

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm({required this.vehicleId, this.initial});

  final String vehicleId;
  final VehicleDocument? initial;

  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm>
    with SubmissionStatus {
  static const int _maxNotesLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  /// One ID per add attempt: saving again after a failure resumes the same
  /// document instead of leaving a half-finished one behind.
  late final String _documentId;
  DocumentType? _type;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  PickedFile? _file;
  bool _preparingFile = false;
  String? _fileError;
  double? _progress;
  Map<String, String> _serverErrors = const {};

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _documentId =
        initial?.id ?? ref.read(documentRepositoryProvider).newDocumentId();
    if (initial != null) {
      _type = initial.type;
      _issueDate = initial.issueDate;
      _expiryDate = initial.expiryDate;
      _notes.text = initial.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _pick(
    Future<PickedFile?> Function(FilePickerService) pick,
  ) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _preparingFile = true;
      _fileError = null;
    });
    try {
      final file = await pick(ref.read(filePickerServiceProvider));
      if (!mounted) return;
      if (file != null) setState(() => _file = file);
    } on FilePickException catch (error) {
      if (!mounted) return;
      setState(
        () => _fileError = switch (error) {
          FileAccessDeniedException(camera: true) => l10n.errorCameraDenied,
          FileAccessDeniedException() => l10n.errorPhotosDenied,
          FileTooLargeException() => l10n.errorFileTooLarge,
          UnreadableFileException() => l10n.errorFileUnreadable,
        },
      );
    } finally {
      if (mounted) setState(() => _preparingFile = false);
    }
  }

  void _takePhoto() => _pick((picker) => picker.pickPhoto(PhotoSource.camera));
  void _choosePhoto() =>
      _pick((picker) => picker.pickPhoto(PhotoSource.gallery));
  void _choosePdf() => _pick((picker) => picker.pickPdf());

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    await settleFields();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final fileMissing = !_editing && _file == null;
    if (fileMissing) setState(() => _fileError = l10n.fileRequired);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || fileMissing) return;

    final messenger = ScaffoldMessenger.of(context);
    final draft = DocumentDraft(
      type: _type!,
      issueDate: _issueDate,
      expiryDate: _expiryDate,
      notes: _notes.text.trim(),
    );
    await submit(() async {
      final mutations = ref.read(documentMutationsProvider);
      if (_editing) {
        await mutations.edit(widget.vehicleId, _documentId, draft);
        messenger.showSnackBar(SnackBar(content: Text(l10n.changesSaved)));
      } else {
        setState(() => _progress = 0);
        try {
          await mutations.add(
            widget.vehicleId,
            draft,
            _file!,
            id: _documentId,
            onProgress: (fraction) {
              if (mounted) setState(() => _progress = fraction);
            },
          );
        } finally {
          if (mounted) setState(() => _progress = null);
        }
        messenger.showSnackBar(SnackBar(content: Text(l10n.documentAdded)));
      }
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final fieldError = switch (error.code) {
        ApiErrorCodes.documentDatesInvalid => {
          _Fields.expiryDate: l10n.errorExpiryBeforeIssue,
        },
        ApiErrorCodes.validationFailed when error.fieldErrors.isNotEmpty =>
          error.fieldErrors,
        _ => null,
      };
      if (fieldError != null) {
        setState(() => _serverErrors = fieldError);
        return null;
      }
      return switch (error.code) {
        ApiErrorCodes.fileTooLarge => l10n.errorFileTooLarge,
        ApiErrorCodes.unsupportedFileType => l10n.errorUnsupportedFile,
        ApiErrorCodes.documentLimitReached => l10n.errorDocumentLimit,
        ApiErrorCodes.uploadNotFound ||
        ApiErrorCodes.uploadMismatch => l10n.errorUploadIncomplete,
        ApiErrorCodes.documentNotFound => l10n.errorDocumentNotFound,
        ApiErrorCodes.vehicleNotFound => l10n.errorVehicleNotFound,
        _ => errorText(l10n, error),
      };
    }
    return errorText(l10n, error);
  }

  String? _validateExpiry(AppLocalizations l10n, DateTime? expiry) {
    final issue = _issueDate;
    if (expiry != null && issue != null && !expiry.isAfter(issue)) {
      return l10n.errorExpiryBeforeIssue;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = today();
    const gap = SizedBox(height: DrivonSpacing.lg);
    final progress = _progress;
    final locked = busy || _preparingFile;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.editDocumentTitle : l10n.addDocumentTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ContentWidth(
            maxWidth: DrivonSpacing.formMaxWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DrivonSpacing.screenGutter,
                DrivonSpacing.lg,
                DrivonSpacing.screenGutter,
                DrivonSpacing.xxxl,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (!_editing) ...[
                  _FileSection(
                    file: _file,
                    preparing: _preparingFile,
                    enabled: !locked,
                    error: _fileError,
                    onTakePhoto: _takePhoto,
                    onChoosePhoto: _choosePhoto,
                    onChoosePdf: _choosePdf,
                    onClear: () => setState(() => _file = null),
                  ),
                  const SizedBox(height: DrivonSpacing.xxl),
                ],
                _TypeField(
                  initialValue: _type,
                  enabled: !locked,
                  serverError: _serverErrors[_Fields.type],
                  validator: (value) =>
                      value == null ? l10n.documentTypeRequired : null,
                  onChanged: (value) {
                    setState(() => _type = value);
                    _clearServerError(_Fields.type);
                  },
                ),
                const SizedBox(height: DrivonSpacing.xl),
                DateFormField(
                  label: l10n.issueDateLabel,
                  doneLabel: l10n.doneAction,
                  initialValue: _issueDate,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(now.year + 1, now.month, now.day),
                  enabled: !locked,
                  errorText: _serverErrors[_Fields.issueDate],
                  clearTooltip: l10n.clearDateTooltip,
                  onCleared: () => setState(() => _issueDate = null),
                  onChanged: (date) {
                    setState(() => _issueDate = date);
                    _clearServerError(_Fields.issueDate);
                  },
                ),
                gap,
                DateFormField(
                  label: l10n.expiryDateLabel,
                  doneLabel: l10n.doneAction,
                  helperText: l10n.expiryDateHelper,
                  initialValue: _expiryDate,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(now.year + 10, now.month, now.day),
                  enabled: !locked,
                  errorText: _serverErrors[_Fields.expiryDate],
                  clearTooltip: l10n.clearDateTooltip,
                  validator: (value) => _validateExpiry(l10n, value),
                  onCleared: () => setState(() => _expiryDate = null),
                  onChanged: (date) {
                    setState(() => _expiryDate = date);
                    _clearServerError(_Fields.expiryDate);
                  },
                ),
                gap,
                TextFormField(
                  controller: _notes,
                  enabled: !locked,
                  decoration: InputDecoration(
                    labelText: l10n.notesLabel,
                    hintText: l10n.documentNotesHint,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: _maxNotesLength,
                  buildCounter: hiddenCounter,
                  forceErrorText: _serverErrors[_Fields.notes],
                  onChanged: (_) => _clearServerError(_Fields.notes),
                ),
                const SizedBox(height: DrivonSpacing.xxl),
                if (error != null) ...[InlineNotice(message: error!), gap],
                if (slow && progress == null) ...[
                  InlineNotice(
                    message: l10n.slowServerNotice,
                    tone: InlineNoticeTone.info,
                  ),
                  gap,
                ],
                if (progress != null) ...[
                  _UploadProgress(fraction: progress),
                  gap,
                ],
                PrimaryButton(
                  label: _editing
                      ? l10n.saveChangesAction
                      : l10n.saveDocumentAction,
                  busyLabel: l10n.uploadingDocument,
                  busy: busy,
                  onPressed: _preparingFile ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the file comes from, and what was chosen.
class _FileSection extends StatelessWidget {
  const _FileSection({
    required this.file,
    required this.preparing,
    required this.enabled,
    required this.error,
    required this.onTakePhoto,
    required this.onChoosePhoto,
    required this.onChoosePdf,
    required this.onClear,
  });

  final PickedFile? file;
  final bool preparing;
  final bool enabled;
  final String? error;
  final VoidCallback onTakePhoto;
  final VoidCallback onChoosePhoto;
  final VoidCallback onChoosePdf;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chosen = file;
    final message = error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.fileSectionTitle, style: textTheme.titleMedium),
        ),
        const SizedBox(height: DrivonSpacing.xs),
        Text(l10n.fileSectionHint, style: textTheme.bodyMedium),
        const SizedBox(height: DrivonSpacing.md),
        if (preparing)
          SizedBox(
            height: DrivonSpacing.huge * 2,
            child: LoadingState(semanticsLabel: l10n.preparingFile),
          )
        else if (chosen != null)
          _ChosenFile(file: chosen, enabled: enabled, onClear: onClear)
        else
          Wrap(
            spacing: DrivonSpacing.sm,
            runSpacing: DrivonSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? onTakePhoto : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.takePhotoAction),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onChoosePhoto : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.choosePhotoAction),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onChoosePdf : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.choosePdfAction),
              ),
            ],
          ),
        if (message != null) ...[
          const SizedBox(height: DrivonSpacing.md),
          InlineNotice(message: message),
        ],
      ],
    );
  }
}

/// A thumbnail (or PDF icon), the file's name and size, and a way to pick
/// another one.
class _ChosenFile extends StatelessWidget {
  const _ChosenFile({
    required this.file,
    required this.enabled,
    required this.onClear,
  });

  final PickedFile file;
  final bool enabled;
  final VoidCallback onClear;

  static const double _thumbnail = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DrivonCard(
      padding: const EdgeInsets.all(DrivonSpacing.md),
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Row(
            children: [
              ClipRRect(
                borderRadius: DrivonRadii.smAll,
                child: SizedBox.square(
                  dimension: _thumbnail,
                  child: file.isImage
                      ? Image.memory(
                          file.bytes,
                          fit: BoxFit.cover,
                          cacheWidth: _thumbnail.toInt() * 3,
                          excludeFromSemantics: true,
                        )
                      : ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            color: context.drivonColors.accentText,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: DrivonSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DrivonSpacing.xxs),
                    Text(
                      '${file.isImage ? l10n.fileKindPhoto : l10n.fileKindPdf} · '
                      '${fileSizeLabel(context, l10n, file.sizeBytes)}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: enabled ? onClear : null,
                child: Text(l10n.changeFileAction),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = (fraction * 100).clamp(0, 100).round();
    final label = l10n.uploadingProgress(percent);
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: DrivonSpacing.sm),
          ClipRRect(
            borderRadius: DrivonRadii.pill,
            child: LinearProgressIndicator(value: fraction, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

/// Document type as wrapping choice chips, validated like a form field.
class _TypeField extends FormField<DocumentType> {
  _TypeField({
    required ValueChanged<DocumentType> onChanged,
    required String? serverError,
    super.validator,
    super.initialValue,
    super.enabled,
  }) : super(
         forceErrorText: serverError,
         builder: (state) {
           final context = state.context;
           final l10n = AppLocalizations.of(context);
           final textTheme = Theme.of(context).textTheme;
           return Semantics(
             label: l10n.documentTypeLabel,
             container: true,
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 ExcludeSemantics(
                   child: Text(
                     l10n.documentTypeLabel,
                     style: textTheme.labelLarge,
                   ),
                 ),
                 const SizedBox(height: DrivonSpacing.sm),
                 Wrap(
                   spacing: DrivonSpacing.sm,
                   runSpacing: DrivonSpacing.sm,
                   children: [
                     for (final type in DocumentType.values)
                       ChoiceChip(
                         label: Text(type.label(l10n)),
                         selected: state.value == type,
                         onSelected: state.widget.enabled
                             ? (_) {
                                 state.didChange(type);
                                 onChanged(type);
                               }
                             : null,
                       ),
                   ],
                 ),
                 if (state.hasError) ...[
                   const SizedBox(height: DrivonSpacing.xs),
                   Text(
                     state.errorText!,
                     style: textTheme.bodySmall?.copyWith(
                       color: context.drivonColors.danger,
                     ),
                   ),
                 ],
               ],
             ),
           );
         },
       );
}
