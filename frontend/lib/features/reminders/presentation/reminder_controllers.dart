import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../auth/presentation/session_controller.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder.dart';

/// A vehicle's reminders, most urgent first.
final vehicleRemindersProvider = FutureProvider.autoDispose
    .family<List<Reminder>, String>((ref, vehicleId) {
      ref.watch(currentUserProvider);
      return ref.read(reminderRepositoryProvider).list(vehicleId);
    }, retry: (_, _) => null);

/// The user's reminders across vehicles, most urgent first. Local
/// notifications are scheduled from this list.
final allRemindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(reminderRepositoryProvider).listAll();
}, retry: (_, _) => null);

typedef ReminderKey = ({String vehicleId, String reminderId});

/// One reminder, from the loaded list when possible.
final reminderProvider = FutureProvider.autoDispose
    .family<Reminder, ReminderKey>((ref, key) {
      final loaded = ref.read(vehicleRemindersProvider(key.vehicleId)).value;
      for (final reminder in loaded ?? const <Reminder>[]) {
        if (reminder.id == key.reminderId) return reminder;
      }
      return ref
          .read(reminderRepositoryProvider)
          .get(key.vehicleId, key.reminderId);
    }, retry: (_, _) => null);

/// Reloads every reminder list. Services, documents, fill-ups and odometer
/// readings all move reminders, so each of those features calls this after a
/// change. Accepts a `Ref` or a `WidgetRef`.
void refreshReminders(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(vehicleRemindersProvider);
  invalidate(allRemindersProvider);
}

/// Adds, edits and deletes the user's own reminders, then refreshes the
/// lists. Throws AppExceptions for forms to explain.
class ReminderMutations {
  ReminderMutations(this._ref);

  final Ref _ref;

  ReminderRepository get _repository => _ref.read(reminderRepositoryProvider);

  /// An ID to keep for one add attempt; see [ReminderRepository.create].
  String newReminderId() => _repository.newReminderId();

  Future<Reminder> add(
    String vehicleId,
    ReminderDraft draft, {
    required String id,
  }) async {
    final reminder = await _repository.create(vehicleId, draft, id: id);
    refreshReminders(_ref.invalidate);
    return reminder;
  }

  Future<void> edit(String vehicleId, String id, ReminderDraft draft) async {
    await _repository.update(vehicleId, id, draft);
    refreshReminders(_ref.invalidate);
    _ref.invalidate(reminderProvider((vehicleId: vehicleId, reminderId: id)));
  }

  Future<void> remove(String vehicleId, String id) async {
    await _repository.delete(vehicleId, id);
    refreshReminders(_ref.invalidate);
  }
}

final reminderMutationsProvider = Provider<ReminderMutations>(
  ReminderMutations.new,
);
