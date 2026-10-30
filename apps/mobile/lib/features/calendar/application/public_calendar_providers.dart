// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/public_calendars_repository.dart';
import '../domain/public_calendar.dart';

/// The public-calendar catalogue: every calendar the Campus API serves, each
/// belonging to one channel. Which of them the reader sees is decided per
/// channel by the shared event-source filter, not here.
final FutureProvider<Loaded<List<PublicCalendar>>>
publicCalendarsCatalogProvider = FutureProvider<Loaded<List<PublicCalendar>>>((
  Ref ref,
) {
  final String locale = ref.watch(localeCodeProvider);
  return ref
      .watch(publicCalendarsRepositoryProvider)
      .fetchCalendars(locale: locale);
}, retry: (_, _) => null);
