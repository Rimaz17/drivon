import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/ui/load_more_footer.dart';
import '../../../core/ui/record_tile.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/number_format.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../../vehicles/presentation/widgets/selected_vehicle_view.dart';
import '../domain/maintenance_record.dart';
import 'maintenance_controllers.dart';
import 'service_type_label.dart';
import 'widgets/upcoming_services_section.dart';

/// Service tab: what is due next and the service history of the selected
/// vehicle, filterable by service type.
class ServiceScreen extends ConsumerWidget {
  const ServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(selectedVehicleProvider);
    final type = ref.watch(serviceTypeFilterProvider);
    final hasHistory =
        vehicle != null &&
        (type != null ||
            (ref
                    .watch(
                      maintenanceHistoryProvider((
                        vehicleId: vehicle.id,
                        type: null,
                      )),
                    )
                    .value
                    ?.items
                    .isNotEmpty ??
                false));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serviceTitle)),
      body: SafeArea(
        child: SelectedVehicleView(
          builder: (context, vehicle, switcher) =>
              _ServiceBody(vehicle: vehicle, switcher: switcher),
        ),
      ),
      floatingActionButton: hasHistory
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(AppRoutes.addServicePath(vehicle.id)),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.logServiceTitle),
            )
          : null,
    );
  }
}

class _ServiceBody extends ConsumerWidget {
  const _ServiceBody({required this.vehicle, required this.switcher});

  final Vehicle vehicle;
  final Widget? switcher;

  /// Space below the list so the last row clears the floating button.
  static const double _fabClearance = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = ref.watch(serviceTypeFilterProvider);
    final query = (vehicleId: vehicle.id, type: type);
    final history = ref.watch(maintenanceHistoryProvider(query));
    final upcoming = ref.watch(upcomingServicesProvider(vehicle.id)).value;

    void retry() {
      ref
        ..invalidate(maintenanceHistoryProvider(query))
        ..invalidate(upcomingServicesProvider(vehicle.id));
    }

    void openRecord(String recordId) =>
        context.push(AppRoutes.editServicePath(vehicle.id, recordId));

    final status = history.when(
      loading: () => LoadingState(semanticsLabel: l10n.loadingServices),
      error: (error, _) => ErrorState(
        title: l10n.servicesLoadErrorTitle,
        message: errorText(l10n, error),
        retryLabel: l10n.retryAction,
        onRetry: retry,
      ),
      data: (list) => list.items.isEmpty && type == null
          ? EmptyState(
              icon: Icons.build_outlined,
              title: l10n.servicesEmptyTitle,
              message: l10n.servicesEmptyMessage,
              actionLabel: l10n.logServiceTitle,
              onAction: () =>
                  context.push(AppRoutes.addServicePath(vehicle.id)),
            )
          : null,
    );
    if (status != null) {
      return Column(
        children: [
          if (switcher != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DrivonSpacing.screenGutter,
                DrivonSpacing.sm,
                DrivonSpacing.screenGutter,
                0,
              ),
              child: switcher,
            ),
          Expanded(child: status),
        ],
      );
    }

    final list = history.value!;
    return RefreshIndicator.adaptive(
      onRefresh: () async {
        retry();
        await ref.read(maintenanceHistoryProvider(query).future);
      },
      child: ContentWidth(
        child: SheetScrollView(
          bottomPadding: _fabClearance,
          header: [
            if (switcher != null) ...[
              switcher!,
              const SizedBox(height: DrivonSpacing.lg),
            ],
            if (upcoming != null && upcoming.isNotEmpty)
              UpcomingServicesSection(
                upcoming: upcoming,
                onOpen: (item) => openRecord(item.recordId),
              ),
          ],
          sheet: [
            SectionTitle(l10n.historyTitle),
            const SizedBox(height: DrivonSpacing.sm),
            _TypeFilter(selected: type),
            const SizedBox(height: DrivonSpacing.xs),
            if (list.items.isEmpty && type != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DrivonSpacing.xxl,
                ),
                child: Builder(
                  // Reads the sheet's paper theme, not the screen's.
                  builder: (context) => Text(
                    l10n.servicesFilteredEmpty(type.label(l10n).toLowerCase()),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final (index, record) in list.items.indexed) ...[
              if (index > 0) const Divider(),
              _ServiceTile(record: record, onTap: () => openRecord(record.id)),
            ],
            LoadMoreFooter(
              list: list,
              failedMessage: l10n.servicesLoadMoreFailed,
              onLoadMore: () => ref
                  .read(maintenanceHistoryProvider(query).notifier)
                  .loadMore(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrolling chips: all services or one type.
class _TypeFilter extends ConsumerWidget {
  const _TypeFilter({required this.selected});

  final ServiceType? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.read(serviceTypeFilterProvider.notifier);
    return Semantics(
      label: l10n.serviceFilterLabel,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final type in <ServiceType?>[null, ...ServiceType.values]) ...[
              ChoiceChip(
                label: Text(
                  type == null ? l10n.allServicesFilter : type.label(l10n),
                ),
                selected: selected == type,
                onSelected: (_) => filter.select(type),
              ),
              const SizedBox(width: DrivonSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.record, required this.onTap});

  final MaintenanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = record.serviceType.label(l10n);
    final amount = formatRupees(context, record.cost);
    final date = formatDate(context, record.date);
    final km = record.odometerKm;
    final details = km == null
        ? date
        : l10n.serviceRowDetails(date, formatInteger(context, km));
    return RecordTile(
      title: title,
      amount: amount,
      details: details,
      notes: record.notes,
      semanticsLabel: '$title, $amount, $details',
      onTap: onTap,
    );
  }
}
