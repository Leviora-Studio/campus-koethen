// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/features/events/application/event_providers.dart';
import 'package:campus_koethen/features/events/application/event_source_filter.dart';
import 'package:campus_koethen/features/events/presentation/event_source_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const List<EventSourceOption> _options = <EventSourceOption>[
  EventSourceOption(key: 'campus-events', label: 'Campus Events'),
  EventSourceOption(key: 'stura-termine', label: 'StuRa Termine'),
];

Future<ProviderContainer> _pumpSheet(
  WidgetTester tester, {
  Set<String> selected = const <String>{'campus-events', 'stura-termine'},
}) async {
  final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
    PreferenceKeys.eventSourceStoreVersion:
        PreferenceKeys.eventSourceStoreCurrentVersion,
    PreferenceKeys.eventSourceSeenKeys: _options
        .map((EventSourceOption o) => o.key)
        .toList(),
    PreferenceKeys.eventSourceSelectedKeys: selected.toList(),
  });
  final ProviderContainer container = await pumpScreen(
    tester,
    Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showEventSourceFilterSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    keyValueStore: store,
    overrides: <Override>[
      eventSourceOptionsProvider.overrideWith((Ref ref) async => _options),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('lists every source with its current selection', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(tester, selected: <String>{'campus-events'});

    expect(find.text('Campus Events'), findsOneWidget);
    expect(find.text('StuRa Termine'), findsOneWidget);
    final CheckboxListTile campus = tester.widget(
      find.widgetWithText(CheckboxListTile, 'Campus Events'),
    );
    final CheckboxListTile stura = tester.widget(
      find.widgetWithText(CheckboxListTile, 'StuRa Termine'),
    );
    expect(campus.value, isTrue);
    expect(stura.value, isFalse);
  });

  testWidgets('Alle abwählen clears every checkbox', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpSheet(tester);

    await tester.tap(find.text('Alle abwählen'));
    await tester.pumpAndSettle();

    expect(container.read(eventSourceFilterProvider).selectedKeys, isEmpty);
  });

  testWidgets('Alle auswählen selects every option', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpSheet(
      tester,
      selected: const <String>{},
    );

    await tester.tap(find.text('Alle auswählen'));
    await tester.pumpAndSettle();

    expect(container.read(eventSourceFilterProvider).selectedKeys, <String>{
      'campus-events',
      'stura-termine',
    });
  });

  testWidgets('toggling one checkbox updates only that source', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpSheet(
      tester,
      selected: <String>{'campus-events'},
    );

    await tester.tap(find.text('StuRa Termine'));
    await tester.pumpAndSettle();

    expect(container.read(eventSourceFilterProvider).selectedKeys, <String>{
      'campus-events',
      'stura-termine',
    });
  });
}
