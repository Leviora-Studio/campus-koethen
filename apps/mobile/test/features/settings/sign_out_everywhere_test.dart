// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/grades/application/grade_account_controller.dart';
import 'package:campus_koethen/features/grades/application/grades_providers.dart';
import 'package:campus_koethen/features/grades/domain/grade_credentials.dart';
import 'package:campus_koethen/features/mail/application/mail_account_controller.dart';
import 'package:campus_koethen/features/mail/application/mail_providers.dart';
import 'package:campus_koethen/features/mail/data/mail_cache.dart';
import 'package:campus_koethen/features/mail/data/mail_local_data_coordinator.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/moodle/application/moodle_account_controller.dart';
import 'package:campus_koethen/features/moodle/application/moodle_providers.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_account.dart';
import 'package:campus_koethen/features/settings/application/sign_out_everywhere_controller.dart';
import 'package:campus_koethen/features/settings/domain/direct_service.dart';
import 'package:campus_koethen/features/settings/presentation/sign_out_everywhere_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grades.dart';
import '../../support/fake_mail.dart';
import '../../support/fake_moodle.dart';
import '../../support/pump_app.dart';

const MailCredentials _mailCreds = MailCredentials(
  emailAddress: 'stud@hs-anhalt.de',
  password: 'pw',
);
const GradeCredentials _gradeCreds = GradeCredentials(
  username: 'stud',
  password: 'pw',
);
final MoodleToken _moodleToken = MoodleToken(
  value: 'tok',
  userId: 7,
  username: 'stud',
);

/// A token store that fails to clear exactly [failTimes] times, then succeeds
/// — mimics a transient "secure storage busy" failure a retry can recover
/// from.
class _FlakyMoodleTokenStore extends InMemoryMoodleTokenStore {
  _FlakyMoodleTokenStore({this.failTimes = 0});

  int failTimes;

  @override
  Future<void> clear() async {
    if (failTimes > 0) {
      failTimes--;
      throw Exception('secure storage unavailable');
    }
    await super.clear();
  }
}

class _Fixtures {
  _Fixtures({
    InMemoryMailCredentialStore? mailStore,
    InMemoryGradeCredentialStore? gradeStore,
    InMemoryMoodleTokenStore? moodleStore,
  }) : mailStore = mailStore ?? InMemoryMailCredentialStore(),
       gradeStore = gradeStore ?? InMemoryGradeCredentialStore(),
       moodleStore = moodleStore ?? InMemoryMoodleTokenStore();

  final InMemoryMailCredentialStore mailStore;
  final InMemoryGradeCredentialStore gradeStore;
  final InMemoryMoodleTokenStore moodleStore;
  final InMemoryGradeCacheStore gradeCache = InMemoryGradeCacheStore();
  final InMemoryGradePortalStore gradePortalStore = InMemoryGradePortalStore();
  final InMemoryMoodleCacheStore moodleCache = InMemoryMoodleCacheStore();

  List<Override> get overrides => <Override>[
    mailCredentialStoreProvider.overrideWithValue(mailStore),
    mailGatewayProvider.overrideWithValue(FakeMailGateway()),
    mailLocalDataCoordinatorProvider.overrideWithValue(
      MailLocalDataCoordinator(
        credentials: mailStore,
        cache: MemoryMailCache(),
        wipeIntent: MemoryMailWipeIntentStore(),
      ),
    ),
    gradeCredentialStoreProvider.overrideWithValue(gradeStore),
    gradeCacheStoreProvider.overrideWithValue(gradeCache),
    gradePortalStoreProvider.overrideWithValue(gradePortalStore),
    gradesGatewayProvider.overrideWithValue(FakeGradesGateway()),
    moodleTokenStoreProvider.overrideWithValue(moodleStore),
    moodleCacheStoreProvider.overrideWithValue(moodleCache),
  ];

  Future<void> signInAll() async {
    await mailStore.write(_mailCreds);
    await gradeStore.write(_gradeCreds);
    await moodleStore.write(_moodleToken);
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Fixtures fixtures, {
  Locale locale = AppLocales.german,
}) => pumpScreen(
  tester,
  const Scaffold(body: SignOutEverywhereTile()),
  overrides: fixtures.overrides,
  locale: locale,
);

void main() {
  group('nobody signed in', () {
    testWidgets('the tile is disabled and names no service', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Fixtures());
      await tester.pump();

      final ListTile tile = tester.widget(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
      expect(find.text('Nirgends angemeldet'), findsOneWidget);
    });
  });

  group('cancel', () {
    testWidgets('changes nothing', (WidgetTester tester) async {
      final _Fixtures fixtures = _Fixtures();
      await fixtures.mailStore.write(_mailCreds);
      final ProviderContainer container = await _pump(tester, fixtures);
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // The confirmation names exactly the connected service.
      expect(find.text('Überall abmelden?'), findsOneWidget);
      expect(find.textContaining('Studentische E-Mail'), findsWidgets);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(await fixtures.mailStore.read(), isNotNull);
      expect(
        container.read(mailAccountControllerProvider).value?.isSignedIn,
        isTrue,
      );
      expect(find.text('Überall abgemeldet.'), findsNothing);
    });
  });

  group('full success', () {
    testWidgets('signs every connected service out through its own path', (
      WidgetTester tester,
    ) async {
      final _Fixtures fixtures = _Fixtures();
      await fixtures.signInAll();
      final ProviderContainer container = await _pump(tester, fixtures);
      await tester.pump();

      expect(
        container.read(connectedDirectServicesProvider),
        containsAll(<DirectService>[
          DirectService.mail,
          DirectService.moodle,
          DirectService.grades,
        ]),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      // Confirmation names every connected service.
      expect(find.textContaining('Studentische E-Mail'), findsWidgets);
      expect(find.textContaining('Moodle'), findsWidgets);
      expect(find.textContaining('Noten'), findsWidgets);

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Überall abgemeldet.'), findsOneWidget);
      expect(await fixtures.mailStore.read(), isNull);
      expect(await fixtures.gradeStore.read(), isNull);
      expect(await fixtures.moodleStore.read(), isNull);
      expect(fixtures.gradeCache.clears, greaterThanOrEqualTo(1));
      expect(fixtures.moodleCache.clears, greaterThanOrEqualTo(1));
      expect(container.read(connectedDirectServicesProvider), isEmpty);
    });
  });

  group('partial failure', () {
    testWidgets('reports only the failed service and allows a scoped retry', (
      WidgetTester tester,
    ) async {
      final _FlakyMoodleTokenStore flakyMoodle = _FlakyMoodleTokenStore(
        failTimes: 1,
      );
      final _Fixtures fixtures = _Fixtures(moodleStore: flakyMoodle);
      await fixtures.signInAll();
      final ProviderContainer container = await _pump(tester, fixtures);
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();

      // Mail and grades succeeded and STAY signed out even though Moodle
      // failed — a partial result never reads as a full success.
      expect(find.text('Teilweise abgemeldet'), findsOneWidget);
      expect(find.textContaining('Moodle'), findsWidgets);
      expect(await fixtures.mailStore.read(), isNull);
      expect(await fixtures.gradeStore.read(), isNull);
      expect(await fixtures.moodleStore.read(), isNotNull);
      expect(container.read(connectedDirectServicesProvider), <DirectService>[
        DirectService.moodle,
      ]);

      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();

      expect(find.text('Überall abgemeldet.'), findsOneWidget);
      expect(await fixtures.moodleStore.read(), isNull);
      expect(container.read(connectedDirectServicesProvider), isEmpty);
    });
  });

  group('after restart', () {
    testWidgets('every signed-out service asks for sign-in again', (
      WidgetTester tester,
    ) async {
      final _Fixtures fixtures = _Fixtures();
      await fixtures.signInAll();
      await _pump(tester, fixtures);
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();

      // Simulate a process restart: a brand-new container reading the very
      // same (now cleared) stores.
      final ProviderContainer restarted = ProviderContainer(
        overrides: fixtures.overrides,
      );
      addTearDown(restarted.dispose);

      expect(
        (await restarted.read(mailAccountControllerProvider.future)).isSignedIn,
        isFalse,
      );
      expect(
        await restarted.read(moodleAccountControllerProvider.future),
        isNull,
      );
      expect(
        (await restarted.read(
          gradeAccountControllerProvider.future,
        )).isSignedIn,
        isFalse,
      );
    });
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    final _Fixtures fixtures = _Fixtures();
    await fixtures.mailStore.write(_mailCreds);
    await _pump(tester, fixtures, locale: AppLocales.english);
    await tester.pump();

    expect(find.text('Sign out everywhere'), findsOneWidget);
    expect(find.text('Signed in to 1 service'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.text('Sign out everywhere?'), findsOneWidget);
  });

  testWidgets('the tile exposes an accessible label for screen readers', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Fixtures fixtures = _Fixtures();
    await fixtures.mailStore.write(_mailCreds);
    await _pump(tester, fixtures);
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('Überall abmelden')), findsOneWidget);
    handle.dispose();
  });
}
