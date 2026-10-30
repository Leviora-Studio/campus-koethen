// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/links/safe_link_launcher.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/features/calendar/presentation/manage_calendars_screen.dart';
import 'package:campus_koethen/features/events/application/event_source_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

Map<String, dynamic> calendarJson({
  required String slug,
  required String name,
  bool defaultSubscribed = true,
}) => <String, dynamic>{
  'id': 'id-$slug',
  'slug': slug,
  'channelSlug': 'fsr',
  'name': name,
  'description': null,
  'colorHex': '#5B3FD0',
  'sortOrder': 0,
  'defaultSubscribed': defaultSubscribed,
  'dataState': 'ready',
  'dataStale': false,
  'lastSuccessfulSyncAt': '2026-06-10T00:00:00.000Z',
  'googleOpenUrl': 'https://calendar.google.com/calendar/render?cid=abc',
};

class _FakeLauncher implements SafeLinkLauncher {
  final List<String> opened = <String>[];
  @override
  Future<LinkLaunchResult> open(String? rawUrl) async {
    opened.add(rawUrl ?? '');
    return LinkLaunchResult.opened;
  }
}

/// Fictional demo channels; only the first has a public calendar.
FakeHttpAdapter _api() => FakeHttpAdapter((RequestOptions options) {
  if (options.path.endsWith('/posts/channels')) {
    return FakeHttpResponse(
      envelope(<Map<String, dynamic>>[
        <String, dynamic>{
          'slug': 'fsr',
          'name': 'Demo-FSR',
          'colorHex': '#C2185B',
          'sortOrder': 0,
          'defaultSubscribed': true,
        },
        <String, dynamic>{
          'slug': 'stura',
          'name': 'Demo-StuRa',
          'colorHex': '#1E88E5',
          'sortOrder': 1,
          'defaultSubscribed': true,
        },
      ]),
    );
  }
  if (options.path.endsWith('/calendars/google-view-url')) {
    return FakeHttpResponse(
      envelope(<String, dynamic>{
        'url': 'https://calendar.google.com/calendar/embed?src=abc',
      }),
    );
  }
  if (options.path.endsWith('/calendars')) {
    return FakeHttpResponse(
      envelope(<Map<String, dynamic>>[
        calendarJson(slug: 'beispielkalender-a', name: 'Beispielkalender A'),
      ]),
    );
  }
  return const FakeHttpResponse('{}', statusCode: 404);
});

void main() {
  testWidgets('offers the channels of the Events tab and shares its choice', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const ManageCalendarsScreen(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(fakeApiClient(_api())),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo-FSR'), findsOneWidget);
    expect(find.text('Demo-StuRa'), findsOneWidget);
    expect(find.text('Beispielkalender A'), findsNothing);
    expect(
      find.text('Diese Auswahl gilt auch für den Reiter Events.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ManageCalendarsScreen)),
    );
    expect(
      container.read(eventSourceFilterProvider).selectedKeys,
      <String>{'fsr'},
      reason: 'the Events tab reads this very selection',
    );
    expect(find.text('Ausgeblendet'), findsOneWidget);
  });

  testWidgets('lists channels without a combined Google action', (
    WidgetTester tester,
  ) async {
    final _FakeLauncher launcher = _FakeLauncher();
    final FakeHttpAdapter adapter = _api();
    await pumpScreen(
      tester,
      const ManageCalendarsScreen(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
        linkLauncherProvider.overrideWithValue(launcher),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Ausgewählte in Google Kalender öffnen'), findsNothing);
    expect(launcher.opened, isEmpty);
  });

  testWidgets("opens a channel's calendar in Google via its googleOpenUrl", (
    WidgetTester tester,
  ) async {
    final _FakeLauncher launcher = _FakeLauncher();
    await pumpScreen(
      tester,
      const ManageCalendarsScreen(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(fakeApiClient(_api())),
        linkLauncherProvider.overrideWithValue(launcher),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byIcon(AppIcons.open_in_new),
      findsOneWidget,
      reason: 'only the channel with a public calendar links to Google',
    );
    await tester.tap(find.byIcon(AppIcons.open_in_new));
    await tester.pumpAndSettle();

    expect(launcher.opened.first, contains('calendar/render?cid=abc'));
  });
}
