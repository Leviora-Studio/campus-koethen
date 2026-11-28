// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/public_calendars_repository.dart';
import '../domain/public_calendar.dart';

/// Every public calendar, including calendars without a linked channel.
final FutureProvider<Loaded<List<PublicCalendar>>>
publicCalendarsCatalogProvider = FutureProvider<Loaded<List<PublicCalendar>>>((
  Ref ref,
) {
  final String locale = ref.watch(localeCodeProvider);
  return ref
      .watch(publicCalendarsRepositoryProvider)
      .fetchCalendars(locale: locale);
}, retry: (_, _) => null);
