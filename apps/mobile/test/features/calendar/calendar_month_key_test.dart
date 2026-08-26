// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/time/clock.dart';
import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:campus_koethen/features/calendar/application/public_calendar_providers.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
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

  late List<RequestOptions> requests;

  ProviderContainer container() {
    requests = <RequestOptions>[];
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions options) {
      requests.add(options);
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

  Iterable<String> eventRequests() => requests
      .map((RequestOptions request) => request.path)
      .where((String path) => path.contains('/calendars/events'));

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

  test('the list requests exactly 120 days from today', () async {
    final ProviderContainer c = container();
    await loadCatalogue(c);

    await c.read(
      publicCalendarListEntriesProvider(DateTime(2026, 8, 27, 18)).future,
    );

    final RequestOptions request = requests.singleWhere(
      (RequestOptions request) => request.path.contains('/calendars/events'),
    );
    expect(request.queryParameters['from'], '2026-08-27');
    expect(request.queryParameters['to'], '2026-12-24');
  });

  test('the list window includes today through day 119 only', () {
    final CalendarDateWindow window = calendarListWindow(
      DateTime(2026, 8, 27, 18),
    );
    final List<CalendarEntry> entries = <CalendarEntry>[
      _entry('before', DateTime(2026, 8, 26, 12)),
      _entry('today', DateTime(2026, 8, 27, 12)),
      _entry('last', DateTime(2026, 12, 24, 12)),
      _entry('after', DateTime(2026, 12, 25, 12)),
    ];

    expect(
      calendarEntriesInWindow(
        entries,
        window,
      ).map((CalendarEntry entry) => entry.id),
      <String>['today', 'last'],
    );
  });

  test('focused calendar uses the rolling window only in list mode', () {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        calendarClockProvider.overrideWithValue(
          _FixedClock(DateTime(2026, 8, 27, 18)),
        ),
        calendarDataProvider.overrideWith(
          (Ref ref, DateTime day) => CalendarData(
            entries: <CalendarEntry>[_entry('month', day)],
            enabledSources: const <CalendarSource>{},
          ),
        ),
        calendarListDataProvider.overrideWith(
          (Ref ref, DateTime day) => CalendarData(
            entries: <CalendarEntry>[_entry('list-${day.day}', day)],
            enabledSources: const <CalendarSource>{},
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    expect(c.read(focusedCalendarDataProvider).entries.single.id, 'month');
    c.read(calendarViewModeProvider.notifier).set(CalendarViewMode.list);
    expect(c.read(focusedCalendarDataProvider).entries.single.id, 'list-27');
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

CalendarEntry _entry(String id, DateTime start) => CalendarEntry(
  id: id,
  source: CalendarSource.publicCalendar,
  title: id,
  start: start,
);

class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
