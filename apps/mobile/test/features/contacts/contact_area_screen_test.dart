// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/network/api_meta.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/features/contacts/application/contacts_providers.dart';
import 'package:campus_koethen/features/contacts/data/contact_models.dart';
import 'package:campus_koethen/features/contacts/presentation/contact_area_screen.dart';
import 'package:flutter/material.dart' show BottomSheet, Material, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const ContactArea _area = ContactArea(
  slug: 'stura',
  name: 'Studierendenrat',
  sortOrder: 0,
  persons: <ContactPerson>[
    ContactPerson(
      name: 'Alex Beispiel',
      role: 'Vorsitz',
      description: 'Zuständig für die Gremienarbeit und Sprechstunden.',
      email: 'alex@example.org',
      phone: '+49 3496 000000',
      website: 'https://example.org/alex',
    ),
  ],
);

Override _areaOverride(ContactArea area, {ApiMeta meta = ApiMeta.empty}) =>
    contactAreaProvider('stura').overrideWith(
      (Ref ref) async => Loaded<ContactArea>(value: area, meta: meta),
    );

void main() {
  testWidgets('discloses when contact text fell back to German', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[
        _areaOverride(_area, meta: const ApiMeta(translationFallback: true)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('deutsche Originaltext'), findsOneWidget);
  });

  testWidgets('the person list stays compact: only name and role are shown', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[_areaOverride(_area)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex Beispiel'), findsOneWidget);
    expect(find.text('Vorsitz'), findsOneWidget);
    // The rich fields are NOT shown inline in the list.
    expect(
      find.text('Zuständig für die Gremienarbeit und Sprechstunden.'),
      findsNothing,
    );
    expect(find.text('alex@example.org'), findsNothing);
  });

  testWidgets(
    'tapping a person opens a sheet with every field Strapi delivers',
    (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ContactAreaScreen(slug: 'stura'),
        overrides: <Override>[_areaOverride(_area)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex Beispiel'));
      await tester.pumpAndSettle();

      expect(
        find.text('Zuständig für die Gremienarbeit und Sprechstunden.'),
        findsOneWidget,
      );
      expect(find.text('alex@example.org'), findsOneWidget);
      expect(find.text('+49 3496 000000'), findsOneWidget);
      expect(find.text('https://example.org/alex'), findsOneWidget);
    },
  );

  testWidgets('rooms are shown even when the area has no contact channels', (
    WidgetTester tester,
  ) async {
    // A room is not a contact channel. An area that maintains no e-mail, phone
    // or website at all — the normal state for the demo content — must still
    // offer the way into the floor plan.
    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[
        _areaOverride(
          const ContactArea(
            slug: 'stura',
            name: 'Studierendenrat',
            sortOrder: 0,
            rooms: <RoomReference>[
              RoomReference(
                roomKey: 'test-building-level2-b201',
                roomNumber: 'B.201',
                buildingName: 'Testgebäude',
                floorName: '2. Obergeschoss',
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('B.201'), findsOneWidget);
  });

  testWidgets('a person with only a name still opens without crashing', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[
        _areaOverride(
          const ContactArea(
            slug: 'stura',
            name: 'Studierendenrat',
            sortOrder: 0,
            persons: <ContactPerson>[ContactPerson(name: 'Nur Name')],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nur Name'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The name appears both in the list and in the opened sheet.
    expect(find.text('Nur Name'), findsWidgets);
  });

  testWidgets('the person sheet fills the width even with only a name', (
    WidgetTester tester,
  ) async {
    // A Material 3 bottom sheet is laid out with LOOSE width constraints, so
    // content that shrink-wraps produces a narrow card floating in the middle
    // as soon as a person has nothing but a short name.
    const Size phone = Size(390, 844);
    await tester.binding.setSurfaceSize(phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScreen(
      tester,
      const ContactAreaScreen(slug: 'stura'),
      overrides: <Override>[
        _areaOverride(
          const ContactArea(
            slug: 'stura',
            name: 'Studierendenrat',
            sortOrder: 0,
            persons: <ContactPerson>[ContactPerson(name: 'Luisa')],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Luisa'));
    await tester.pumpAndSettle();

    // Not the BottomSheet itself — that is only the layout box and is always
    // full width. What the user sees is the Material surface inside it.
    final Finder surface = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Material),
    );
    expect(tester.getSize(surface.first).width, phone.width);
  });
}
