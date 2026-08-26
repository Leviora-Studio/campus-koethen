// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:campus_koethen/features/calendar/application/public_calendar_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

/// The aggregated calendar covers a whole month. Everything below states that
/// the month — not the individual day the caller happens to pass — is what
/// decides how often that month is aggregated and how often its events are
/// fetched. Day-by-day keys made stepping through a week strip repeat both.

Map<String, dynamic> get _calendar => <String, dynamic>{
  'id': 'cal-1',
  'slug': 'campus',
  'name': 'Campus',
  'colorHex': '#5B3FD0',
  'sortOrder': 0,
  'defaultSubscribed': true,
  'dataStale': false,
  'googleOpenUrl': 'https://calendar.google.com/calendar/u/0',
};

void main() {
  // localeCodeProvider reads the platform locale through the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> requestedPaths;

  ProviderContainer container() {
    requestedPaths = <String>[];
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions options) {
      requestedPaths.add(options.path);
      if (options.path == '/calendars') {
        return FakeHttpResponse(envelope(<Object>[_calendar]));
      }
      return FakeHttpResponse(envelope(<Object>[]));
    });
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        contentCacheProvider.overrideWithValue(
          SafeContentCache(MemoryContentCache()),
        ),
        apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('two days of the same month share one aggregation', () {
    final ProviderContainer c = container();

    final ProviderSubscription<CalendarData> early = c.listen(
      calendarDataProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    final ProviderSubscription<CalendarData> late = c.listen(
      calendarDataProvider(DateTime(2026, 5, 27)),
      (_, _) {},
    );

    expect(
      identical(early.read(), late.read()),
      isTrue,
      reason: 'both days describe the same month, so the merge runs once',
    );
  });

  test('a different month is still aggregated separately', () {
    final ProviderContainer c = container();

    final ProviderSubscription<CalendarData> may = c.listen(
      calendarDataProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    final ProviderSubscription<CalendarData> june = c.listen(
      calendarDataProvider(DateTime(2026, 6, 4)),
      (_, _) {},
    );

    expect(identical(may.read(), june.read()), isFalse);
  });

  /// Resolves the catalogue first: without it the selection is empty and the
  /// events endpoint is deliberately never called at all.
  Future<void> loadCatalogue(ProviderContainer c) async {
    c.listen(publicCalendarsCatalogProvider, (_, _) {});
    await c.read(publicCalendarsCatalogProvider.future);
  }

  Iterable<String> eventRequests() =>
      requestedPaths.where((String p) => p.contains('/calendars/events'));

  test('the events of one month are fetched once, not once per day', () async {
    final ProviderContainer c = container();
    await loadCatalogue(c);

    await c.read(
      publicCalendarMonthEntriesProvider(DateTime(2026, 5, 4)).future,
    );
    await c.read(
      publicCalendarMonthEntriesProvider(DateTime(2026, 5, 27)).future,
    );

    expect(
      eventRequests(),
      hasLength(1),
      reason: 'both days ask for the identical window',
    );
  });

  test('a day in another month does fetch its own window', () async {
    final ProviderContainer c = container();
    await loadCatalogue(c);

    await c.read(
      publicCalendarMonthEntriesProvider(DateTime(2026, 5, 4)).future,
    );
    await c.read(
      publicCalendarMonthEntriesProvider(DateTime(2026, 6, 4)).future,
    );

    expect(eventRequests(), hasLength(2));
  });

  test('a month nobody watches any more is released', () async {
    // Without this every day someone browses to keeps its merged month —
    // entries, day index, event days — alive until the process ends.
    final ProviderContainer c = container();

    final ProviderSubscription<CalendarData> first = c.listen(
      calendarDataProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    final CalendarData held = first.read();
    first.close();
    await c.pump();

    final ProviderSubscription<CalendarData> again = c.listen(
      calendarDataProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    expect(identical(again.read(), held), isFalse);
  });

  test('returning to a released month costs no new request', () async {
    // Releasing derived state must not turn into traffic: the week and event
    // providers behind it keep their data, so the return is a re-merge.
    final ProviderContainer c = container();
    await loadCatalogue(c);

    final ProviderSubscription<CalendarData> first = c.listen(
      calendarDataProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    first.read();
    await c.read(
      publicCalendarMonthEntriesProvider(DateTime(2026, 5, 4)).future,
    );
    final int before = eventRequests().length;
    expect(before, 1);

    first.close();
    await c.pump();

    final ProviderSubscription<CalendarData> again = c.listen(
      calendarDataProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    again.read();
    await c.pump();

    expect(eventRequests(), hasLength(before));
  });
}
