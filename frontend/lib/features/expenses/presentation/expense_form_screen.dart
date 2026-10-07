import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/confirm_dialog.dart';
import '../../../core/ui/date_form_field.dart';
import '../../../core/ui/decimal_input.dart';
import '../../../core/ui/submission_status.dart';
import '../../../core/ui/text_field_helpers.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/fixed_decimal.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/expense.dart';
import 'category_label.dart';
import 'expense_controllers.dart';

/// Adds an expense for [vehicleId], or edits/deletes one when [expenseId]
/// is given.
class ExpenseFormScreen extends ConsumerWidget {
  const ExpenseFormScreen({required this.vehicleId, this.expenseId, super.key});

  final String vehicleId;
  final String? expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = expenseId;
    if (id == null) return _ExpenseForm(vehicleId: vehicleId);

    final l10n = AppLocalizations.of(context);
    final key = (vehicleId: vehicleId, expenseId: id);
    return ref
        .watch(expenseProvider(key))
        .when(
          data: (expense) =>
              _ExpenseForm(vehicleId: vehicleId, initial: expense),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.editExpenseTitle)),
            body: LoadingState(semanticsLabel: l10n.loadingRecord),
          ),
          error: (error, _) {
            final missing =
                error is ApiProblemException &&
                (error.code == ApiErrorCodes.expenseNotFound ||
                    error.code == ApiErrorCodes.vehicleNotFound);
            return Scaffold(
              appBar: AppBar(title: Text(l10n.editExpenseTitle)),
              body: missing
                  ? ErrorState(
                      title: l10n.errorExpenseNotFound,
                      message: l10n.recordMissingMessage,
                      retryLabel: l10n.backAction,
                      onRetry: () => context.pop(),
                    )
                  : ErrorState(
                      title: l10n.recordLoadErrorTitle,
                      message: errorText(l10n, error),
                      retryLabel: l10n.retryAction,
                      onRetry: () => ref.invalidate(expenseProvider(key)),
                    ),
            );
          },
        );
  }
}

abstract final class _Fields {
  static const category = 'category';
  static const amount = 'amount';
  static const date = 'date';
  static const notes = 'notes';
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({required this.vehicleId, this.initial});

  final String vehicleId;
  final Expense? initial;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm>
    with SubmissionStatus {
  static const int _maxAmountUnits = 999999999;
  static const int _maxNotesLength = 500;

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  ExpenseCategory? _category;
  late DateTime _date;
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date ?? today();
    if (initial != null) {
      _category = initial.category;
      _amount.text = initial.amount.fractionPart == 0
          ? '${initial.amount.wholePart}'
          : initial.amount.toPlainString();
      _notes.text = initial.notes ?? '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    await settleFields();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = ExpenseDraft(
      category: _category!,
      amount: FixedDecimal.parse(_amount.text, scale: FixedDecimal.moneyScale),
      date: _date,
      notes: _notes.text.trim(),
    );
    await submit(() async {
      final mutations = ref.read(expenseMutationsProvider);
      final initial = widget.initial;
      if (initial != null) {
        await mutations.edit(widget.vehicleId, initial.id, draft);
      } else {
        await mutations.add(widget.vehicleId, draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            initial != null ? l10n.changesSaved : l10n.expenseAdded,
          ),
        ),
      );
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  Future<void> _delete(Expense expense) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteExpenseTitle,
      message: l10n.deleteExpenseMessage,
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await submit(() async {
      await ref
          .read(expenseMutationsProvider)
          .remove(widget.vehicleId, expense.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.expenseDeleted)));
      if (mounted) context.pop();
    }, describe: (error) => _describe(l10n, error));
  }

  String? _describe(AppLocalizations l10n, Object error) {
    if (error is ApiProblemException) {
      final fieldError = switch (error.code) {
        ApiErrorCodes.dateInFuture => {_Fields.date: l10n.errorDateInFuture},
        ApiErrorCodes.validationFailed when error.fieldErrors.isNotEmpty =>
          error.fieldErrors,
        _ => null,
      };
      if (fieldError != null) {
        setState(() => _serverErrors = fieldError);
        return null;
      }
      switch (error.code) {
        case ApiErrorCodes.expenseNotFound:
          return l10n.errorExpenseNotFound;
        case ApiErrorCodes.vehicleNotFound:
          return l10n.errorVehicleNotFound;
      }
    }
    return errorText(l10n, error);
  }

  String? _validateAmount(AppLocalizations l10n, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.amountRequired;
    final amount = FixedDecimal.tryParse(text, scale: FixedDecimal.moneyScale);
    if (amount == null || amount.isZero || amount.units > _maxAmountUnits) {
      return l10n.amountInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initial = widget.initial;
    final category = _category;
    const gap = SizedBox(height: DrivonSpacing.lg);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          initial != null ? l10n.editExpenseTitle : l10n.addExpenseTitle,
        ),
        actions: [
          if (initial != null)
            IconButton(
              tooltip: l10n.deleteExpenseTooltip,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: busy ? null : () => _delete(initial),
            ),
        ],
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
                _CategoryField(
                  initialValue: _category,
                  enabled: !busy,
                  serverError: _serverErrors[_Fields.category],
                  validator: (value) =>
                      value == null ? l10n.categoryRequired : null,
                  onChanged: (value) {
                    setState(() => _category = value);
                    _clearServerError(_Fields.category);
                  },
                ),
                if (category != null && category.isFedByRecords) ...[
                  const SizedBox(height: DrivonSpacing.md),
                  InlineNotice(
                    message: category == ExpenseCategory.fuel
                        ? l10n.fuelCategoryNote
                        : l10n.maintenanceCategoryNote,
                    tone: InlineNoticeTone.info,
                  ),
                ],
                const SizedBox(height: DrivonSpacing.xl),
                TextFormField(
                  controller: _amount,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.amountLabel,
                    prefixText: l10n.rupeePrefix,
                  ),
                  keyboardType: decimalKeyboard,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    DecimalTextInputFormatter(
                      maxWhole: 7,
                      maxFraction: FixedDecimal.moneyScale,
                    ),
                  ],
                  forceErrorText: _serverErrors[_Fields.amount],
                  onChanged: (_) => _clearServerError(_Fields.amount),
                  validator: (value) => _validateAmount(l10n, value),
                ),
                gap,
                DateFormField(
                  label: l10n.fillUpDateLabel,
                  doneLabel: l10n.doneAction,
                  initialValue: _date,
                  firstDate: DateTime(1990),
                  lastDate: today(),
                  enabled: !busy,
                  errorText: _serverErrors[_Fields.date],
                  validator: (value) =>
                      value == null ? l10n.dateRequired : null,
                  onChanged: (date) {
                    _date = date;
                    _clearServerError(_Fields.date);
                  },
                ),
                gap,
                TextFormField(
                  controller: _notes,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.notesLabel,
                    hintText: l10n.expenseNotesHint,
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
                if (slow) ...[
                  InlineNotice(
                    message: l10n.slowServerNotice,
                    tone: InlineNoticeTone.info,
                  ),
                  gap,
                ],
                PrimaryButton(
                  label: initial != null
                      ? l10n.saveChangesAction
                      : l10n.addExpenseTitle,
                  busyLabel: l10n.savingExpense,
                  busy: busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Category picker as wrapping choice chips, validated like a form field.
class _CategoryField extends FormField<ExpenseCategory> {
  _CategoryField({
    required ValueChanged<ExpenseCategory> onChanged,
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
             label: l10n.categoryLabel,
             container: true,
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 ExcludeSemantics(
                   child: Text(l10n.categoryLabel, style: textTheme.labelLarge),
                 ),
                 const SizedBox(height: DrivonSpacing.sm),
                 Wrap(
                   spacing: DrivonSpacing.sm,
                   runSpacing: DrivonSpacing.sm,
                   children: [
                     for (final category in ExpenseCategory.values)
                       ChoiceChip(
                         label: Text(category.label(l10n)),
                         selected: state.value == category,
                         onSelected: state.widget.enabled
                             ? (_) {
                                 state.didChange(category);
                                 onChanged(category);
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
