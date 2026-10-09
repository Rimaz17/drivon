import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/analytics.dart';

/// A dark card on the sheet with a title, an optional caption and its chart
/// or message. Loading and failures keep the card's place so the sheet
/// doesn't jump.
class InsightCard extends StatelessWidget {
  const InsightCard({
    required this.title,
    required this.child,
    this.caption,
    super.key,
  });

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Read the theme below the card, which re-themes its content dark.
    return DrivonCard(
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          final note = caption;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: textTheme.titleMedium),
              ),
              if (note != null) ...[
                const SizedBox(height: DrivonSpacing.xxs),
                Text(note, style: textTheme.bodySmall),
              ],
              const SizedBox(height: DrivonSpacing.lg),
              child,
            ],
          );
        },
      ),
    );
  }
}

/// A short message in place of a chart: not enough data yet, or a failure
/// with a retry.
class InsightMessage extends StatelessWidget {
  const InsightMessage({
    required this.message,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        if (retry != null && retryLabel != null)
          TextButton(onPressed: retry, child: Text(retryLabel!)),
      ],
    );
  }
}

/// Space a chart takes while its data loads.
class InsightLoading extends StatelessWidget {
  const InsightLoading({this.height = 160, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: LoadingState(
      semanticsLabel: AppLocalizations.of(context).loadingInsights,
    ),
  );
}

extension CostGroupLabel on CostGroup {
  String label(AppLocalizations l10n) => switch (this) {
    CostGroup.fuel => l10n.costGroupFuel,
    CostGroup.maintenance => l10n.costGroupMaintenance,
    CostGroup.other => l10n.costGroupOther,
  };

  /// This group's series color, in the fixed fuel, maintenance, other order.
  Color color(BuildContext context) => context.drivonColors.costSeries[index];
}
