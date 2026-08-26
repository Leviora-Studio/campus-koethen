// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:io';

import 'package:campus_koethen/core/cache/encrypted_box.dart';
import 'package:campus_koethen/features/mail/data/mail_cache.dart';
import 'package:campus_koethen/features/mail/data/mail_local_data_coordinator.dart';
import 'package:campus_koethen/features/mail/data/secure_mail_credential_store.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_failure.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const MailCredentials _accountA = MailCredentials(
  emailAddress: 'alice@example.test',
  password: 'alice-password',
);

const MailCredentials _accountB = MailCredentials(
  emailAddress: 'bob@example.test',
  password: 'bob-password',
);

/// Fails [delete] on demand so a wipeChecked() key deletion can be made to
/// report an incomplete result without disturbing normal read/write.
class _ToggleFailDeleteStorage extends FlutterSecureStorage {
  bool failDelete = false;

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw StateError('secure storage delete unavailable');
    return super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

/// Fails the legacy-box `initializeHive` call on demand so
/// `_deleteLegacyAndConfirm()` can be made to report `legacyCleanupFailed`
/// without touching the encrypted v2 box's own Hive initialization.
class _ToggleFailInitializeHive {
  bool shouldFail = false;

  Future<void> call() async {
    if (shouldFail) throw StateError('hive unavailable');
  }
}

void main() {
  late Directory directory;
  late _ToggleFailDeleteStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mail-coordinator-test-');
    Hive.init(directory.path);
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    storage = _ToggleFailDeleteStorage();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  MailCacheManager manager({_ToggleFailInitializeHive? legacyFault}) {
    final EncryptedBox box = EncryptedBox(
      boxName: MailCacheManager.secureBoxName,
      keyStorageKey: MailCacheManager.keyStorageKey,
      storage: storage,
      hive: Hive,
      initializeHive: () async {},
    );
    return MailCacheManager(
      encryptedBox: box,
      hive: Hive,
      initializeHive: legacyFault?.call ?? (() async {}),
    );
  }

  MailLocalDataCoordinator coordinator(MailCacheManager cache) =>
      MailLocalDataCoordinator(
        credentials: SecureMailCredentialStore(storage),
        cache: cache,
        wipeIntent: SecureMailWipeIntentStore(storage),
      );

  MailMessageHeader header() => const MailMessageHeader(
    id: '1',
    subject: "Alice's confidential subject",
    from: MailAddress(email: 'sender@example.test'),
    date: null,
    isSeen: false,
    hasAttachments: false,
  );

  test('an unconfirmed legacy cleanup blocks credential reads and writes until '
      'a later recovery attempt confirms it absent', () async {
    final _ToggleFailInitializeHive fault = _ToggleFailInitializeHive()
      ..shouldFail = true;
    final MailCacheManager cache = manager(legacyFault: fault);
    final MailLocalDataCoordinator coord = coordinator(cache);

    await coord.initialize();
    await expectLater(
      coord.readCredentials(),
      throwsA(
        isA<MailFailure>().having(
          (MailFailure f) => f.kind,
          'kind',
          MailFailureKind.localDataWipeIncomplete,
        ),
      ),
    );
    await expectLater(
      coord.writeCredentials(_accountB),
      throwsA(isA<MailFailure>()),
    );

    // Recovery: the transient fault clears and a later attempt (a fresh
    // coordinator, as at the next app start) confirms the cleanup.
    fault.shouldFail = false;
    final MailLocalDataCoordinator recovered = coordinator(
      manager(legacyFault: fault),
    );
    await recovered.initialize();
    expect(await recovered.readCredentials(), isNull);
    await recovered.writeCredentials(_accountB);
    expect(
      (await recovered.readCredentials())?.emailAddress,
      'bob@example.test',
    );
  });

  test('an unconfirmed v2 cache/key wipe blocks credential reads and writes '
      'until a later recovery attempt confirms it absent', () async {
    storage.failDelete = true;
    final MailCacheManager cache = manager();
    final MailLocalDataCoordinator coord = coordinator(cache);

    await coord.initialize();
    await expectLater(coord.readCredentials(), throwsA(isA<MailFailure>()));
    await expectLater(
      coord.writeCredentials(_accountB),
      throwsA(isA<MailFailure>()),
    );

    storage.failDelete = false;
    final MailLocalDataCoordinator recovered = coordinator(manager());
    await recovered.initialize();
    expect(await recovered.readCredentials(), isNull);
    await recovered.writeCredentials(_accountB);
    expect(
      (await recovered.readCredentials())?.emailAddress,
      'bob@example.test',
    );
  });

  test('account B never activates account A\'s fully intact leftover cache '
      'after an unconfirmed legacy cleanup: sign-in only succeeds once cleanup '
      'is confirmed, and starts empty with a rotated key', () async {
    // Account A signs in normally and populates the encrypted cache.
    final MailCacheManager cacheA = manager();
    final MailLocalDataCoordinator coordA = coordinator(cacheA);
    await coordA.initialize();
    await coordA.writeCredentials(_accountA);
    await cacheA.saveHeaders(<MailMessageHeader>[header()]);
    await cacheA.saveMessage(
      MailMessageDetail(
        id: '1',
        subject: header().subject,
        from: header().from,
        to: const <MailAddress>[],
        date: DateTime.utc(2026, 8, 19),
        body: "Alice's confidential body",
        attachments: const <MailAttachment>[],
      ),
    );
    final String keyForA = (await storage.read(
      key: MailCacheManager.keyStorageKey,
    ))!;

    // Credentials become absent through another path (not a confirmed
    // wipe) while account A's populated v2 box and its key are still fully
    // intact on disk, and a restart's legacy cleanup cannot be confirmed —
    // the exact P1 scenario.
    await storage.delete(key: SecureMailCredentialStore.emailKey);
    await storage.delete(key: SecureMailCredentialStore.passwordKey);

    final _ToggleFailInitializeHive fault = _ToggleFailInitializeHive()
      ..shouldFail = true;
    final MailCacheManager cacheRestart1 = manager(legacyFault: fault);
    final MailLocalDataCoordinator restart1 = coordinator(cacheRestart1);
    await restart1.initialize();

    await expectLater(
      restart1.writeCredentials(_accountB),
      throwsA(isA<MailFailure>()),
    );
    // Account A's box and key are untouched — never reactivated as B's.
    expect(await storage.read(key: MailCacheManager.keyStorageKey), keyForA);
    expect(await Hive.boxExists(MailCacheManager.secureBoxName), isTrue);

    // Only once the cleanup genuinely succeeds on a later restart does
    // sign-in unlock again, and it must start empty with a rotated key
    // rather than reactivating account A's leftover data.
    fault.shouldFail = false;
    final MailCacheManager cacheRestart2 = manager(legacyFault: fault);
    final MailLocalDataCoordinator restart2 = coordinator(cacheRestart2);
    await restart2.initialize();
    await restart2.writeCredentials(_accountB);

    expect(await cacheRestart2.readHeaders(), isEmpty);
    expect(await cacheRestart2.readMessage('1'), isNull);
    expect(await cacheRestart2.knownAddresses(), isEmpty);
    final String? keyForB = await storage.read(
      key: MailCacheManager.keyStorageKey,
    );
    expect(keyForB, isNotNull);
    expect(keyForB, isNot(keyForA));
  });

  test('a normal restart of an already signed-in account keeps its own '
      'encrypted offline cache', () async {
    final MailCacheManager cache = manager();
    final MailLocalDataCoordinator coord = coordinator(cache);
    await coord.initialize();
    await coord.writeCredentials(_accountA);
    await cache.saveHeaders(<MailMessageHeader>[header()]);

    // Simulate a normal process restart: new manager/coordinator instances
    // reading the same persisted credentials and disk state.
    final MailCacheManager restartedCache = manager();
    final MailLocalDataCoordinator restarted = coordinator(restartedCache);
    await restarted.initialize();

    expect(
      (await restarted.readCredentials())?.emailAddress,
      'alice@example.test',
    );
    expect(
      (await restartedCache.readHeaders()).single.subject,
      header().subject,
    );
  });
}
