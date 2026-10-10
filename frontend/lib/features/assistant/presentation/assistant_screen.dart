import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_text.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../domain/chat_message.dart';
import 'chat_controller.dart';

/// Ask My Vehicle: questions about the selected vehicle, answered by the
/// server from the user's own records.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final question = text ?? _input.text;
    if (question.trim().isEmpty) return;
    _input.clear();
    await ref.read(chatControllerProvider.notifier).send(question);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chat = ref.watch(chatControllerProvider);
    final vehicle = ref.watch(selectedVehicleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantTitle),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: l10n.assistantClearTooltip,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: chat.waiting
                  ? null
                  : ref.read(chatControllerProvider.notifier).clear,
            ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Expanded(
                child: chat.messages.isEmpty
                    ? _Welcome(vehicleName: vehicle?.displayName, onAsk: _send)
                    : _Conversation(chat: chat),
              ),
              _Composer(
                controller: _input,
                focusNode: _focus,
                waiting: chat.waiting,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the assistant can do, with example questions to start from.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.vehicleName, required this.onAsk});

  final String? vehicleName;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = vehicleName;
    final suggestions = [
      l10n.assistantSuggestionFuel,
      l10n.assistantSuggestionEfficiency,
      l10n.assistantSuggestionService,
      l10n.assistantSuggestionInsurance,
      l10n.assistantSuggestionCostPerKm,
    ];
    return ListView(
      padding: const EdgeInsets.all(DrivonSpacing.screenGutter),
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: DrivonSpacing.huge,
          color: context.drivonColors.accentText,
        ),
        const SizedBox(height: DrivonSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            l10n.assistantWelcomeTitle,
            style: textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: DrivonSpacing.sm),
        Text(
          name == null
              ? l10n.assistantWelcomeMessage
              : l10n.assistantWelcomeVehicle(name),
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: DrivonSpacing.xl),
        Text(l10n.assistantTryAsking, style: textTheme.titleSmall),
        const SizedBox(height: DrivonSpacing.sm),
        Wrap(
          spacing: DrivonSpacing.sm,
          runSpacing: DrivonSpacing.sm,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                label: Text(suggestion),
                onPressed: () => onAsk(suggestion),
              ),
          ],
        ),
        const SizedBox(height: DrivonSpacing.xl),
        Text(l10n.assistantPrivacyNote, style: textTheme.bodySmall),
      ],
    );
  }
}

class _Conversation extends ConsumerWidget {
  const _Conversation({required this.chat});

  final ChatState chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = chat.messages.reversed.toList();
    return ListView.builder(
      // Newest at the bottom, and the list starts there.
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: DrivonSpacing.screenGutter,
        vertical: DrivonSpacing.lg,
      ),
      itemCount: messages.length + (chat.waiting ? 1 : 0),
      itemBuilder: (context, index) {
        if (chat.waiting) {
          if (index == 0) return const _Thinking();
          index--;
        }
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DrivonSpacing.md),
          child: _Bubble(
            message: message,
            onRetry: message.failed && !chat.waiting
                ? () => ref
                      .read(chatControllerProvider.notifier)
                      .retry(message.id)
                : null,
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  /// Bubbles leave room on the other side, like any chat.
  static const double _widthFactor = 0.85;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.drivonColors;
    final mine = message.role == ChatRole.user;
    final error = message.error;

    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: mine ? colors.selectedFill : scheme.surfaceContainerHigh,
        borderRadius: DrivonRadii.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DrivonSpacing.lg,
          vertical: DrivonSpacing.md,
        ),
        child: SelectableText(
          message.text,
          style: textTheme.bodyLarge?.copyWith(
            color: mine ? colors.onSelectedFill : colors.textPrimary,
          ),
        ),
      ),
    );

    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: _widthFactor,
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              label: mine ? l10n.assistantYouSaid : l10n.assistantReplied,
              child: bubble,
            ),
            if (error != null) ...[
              const SizedBox(height: DrivonSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: DrivonSpacing.lg,
                    color: colors.danger,
                  ),
                  const SizedBox(width: DrivonSpacing.xs),
                  Flexible(
                    child: Text(
                      assistantErrorText(l10n, error),
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: Text(l10n.retryAction)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown while the answer is on its way, which can take a few seconds.
class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DrivonSpacing.md),
      child: Semantics(
        liveRegion: true,
        label: l10n.assistantThinking,
        excludeSemantics: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: DrivonSpacing.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: DrivonSpacing.sm),
            Text(
              l10n.assistantThinking,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.waiting,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool waiting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DrivonSpacing.screenGutter,
        DrivonSpacing.sm,
        DrivonSpacing.sm,
        DrivonSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  ChatController.maxQuestionLength,
                ),
              ],
              decoration: InputDecoration(hintText: l10n.assistantInputHint),
              onSubmitted: waiting ? null : (_) => onSend(),
            ),
          ),
          const SizedBox(width: DrivonSpacing.xs),
          IconButton.filled(
            tooltip: l10n.assistantSendTooltip,
            icon: const Icon(Icons.arrow_upward_rounded),
            onPressed: waiting ? null : onSend,
          ),
        ],
      ),
    );
  }
}

/// What went wrong with a question, and what to do about it.
String assistantErrorText(AppLocalizations l10n, Object error) {
  if (error is ApiProblemException) {
    switch (error.code) {
      case ApiErrorCodes.assistantUnavailable:
        return l10n.assistantUnavailable;
      case ApiErrorCodes.assistantIncomplete:
        return l10n.assistantIncomplete;
      case ApiErrorCodes.rateLimited:
        return l10n.assistantRateLimited;
    }
  }
  return errorText(l10n, error);
}
