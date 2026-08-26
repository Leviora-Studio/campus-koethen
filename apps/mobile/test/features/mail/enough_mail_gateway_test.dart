// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/mail/data/enough_mail_gateway.dart';
import 'package:campus_koethen/features/mail/domain/hsa_mail_profile.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_failure.dart';
import 'package:campus_koethen/features/mail/domain/mail_folder.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_imap_server.dart';

/// Points [EnoughMailGateway] at a loopback [FakeImapServer] instead of the
/// real `mail.hs-anhalt.de`. Plain TCP, not TLS: the fake server only speaks
/// plaintext IMAP, and TLS handshake mechanics are no part of what these
/// tests exercise.
class _LoopbackMailProfile extends HsaMailProfile {
  const _LoopbackMailProfile(this._port);

  final int _port;

  @override
  String get imapHost => '127.0.0.1';

  @override
  int get imapPort => _port;

  @override
  bool get imapImplicitTls => false;
}

const MailCredentials _credentials = MailCredentials(
  emailAddress: 'stud@hs-anhalt.de',
  password: 'pw',
);

void main() {
  late FakeImapServer server;

  Future<EnoughMailGateway> gatewayFor(
    List<String> Function(String tag, String command) onSearch,
    List<String> Function(String tag, String command) onFetch,
  ) async {
    server = await FakeImapServer.start(
      fakeImapHandler(onSearch: onSearch, onFetch: onFetch),
    );
    return EnoughMailGateway(_LoopbackMailProfile(server.port));
  }

  tearDown(() async {
    await server.close();
  });

  group('EnoughMailGateway.searchMessages', () {
    test('returns matching headers newest first', () async {
      final EnoughMailGateway gateway = await gatewayFor(
        fakeSearchHits(<int>[5, 7]),
        fakeFetchHandler(<int, FakeImapMessage>{
          5: const FakeImapMessage(
            uid: 5,
            subject: 'Older',
            fromName: 'Alice',
            fromLocal: 'alice',
            fromDomain: 'hs-anhalt.de',
            date: 'Mon, 1 Jun 2026 08:00:00 +0200',
          ),
          7: const FakeImapMessage(
            uid: 7,
            subject: 'Newer',
            fromName: 'Bob',
            fromLocal: 'bob',
            fromDomain: 'hs-anhalt.de',
            date: 'Tue, 2 Jun 2026 08:00:00 +0200',
          ),
        }),
      );

      final List<MailMessageHeader> result = await gateway.searchMessages(
        _credentials,
        mailboxPath: kInboxPath,
        query: 'Bob',
      );

      expect(result.map((MailMessageHeader h) => h.id), <String>['7', '5']);
      expect(result.map((MailMessageHeader h) => h.subject), <String>[
        'Newer',
        'Older',
      ]);
    });

    test('sends a properly quoted CHARSET so the query is not rejected '
        'regardless of content — the fixed regression path', () async {
      final EnoughMailGateway gateway = await gatewayFor(
        fakeSearchHits(const <int>[]),
        fakeFetchHandler(const <int, FakeImapMessage>{}),
      );

      await gateway.searchMessages(
        _credentials,
        mailboxPath: kInboxPath,
        query: 'irrelevant',
      );

      final String searchCommand = server.receivedCommands.singleWhere(
        (String c) => c.contains('UID SEARCH'),
      );
      // The historic bug sent an unquoted `CHARSET UTF-8` clause that a
      // strict server rejects outright for every query; the fix quotes it
      // like every other astring the client sends.
      expect(searchCommand, contains('CHARSET "UTF-8"'));
      expect(searchCommand, isNot(contains('CHARSET UTF-8 ')));
    });

    test('escapes quotes and backslashes in the query', () async {
      final EnoughMailGateway gateway = await gatewayFor(
        fakeSearchHits(const <int>[]),
        fakeFetchHandler(const <int, FakeImapMessage>{}),
      );

      await gateway.searchMessages(
        _credentials,
        mailboxPath: kInboxPath,
        query: 'a "quote" and a \\backslash',
      );

      final String searchCommand = server.receivedCommands.singleWhere(
        (String c) => c.contains('UID SEARCH'),
      );
      expect(searchCommand, contains(r'TEXT "a \"quote\" and a \\backslash"'));
    });

    test('returns an empty list, not an error, when nothing matches', () async {
      final EnoughMailGateway gateway = await gatewayFor(
        fakeSearchHits(const <int>[]),
        fakeFetchHandler(const <int, FakeImapMessage>{}),
      );

      final List<MailMessageHeader> result = await gateway.searchMessages(
        _credentials,
        mailboxPath: kInboxPath,
        query: 'nothing matches this',
      );

      expect(result, isEmpty);
    });

    test('a blank query never reaches the server', () async {
      final EnoughMailGateway gateway = await gatewayFor(
        fakeSearchHits(const <int>[]),
        fakeFetchHandler(const <int, FakeImapMessage>{}),
      );

      final List<MailMessageHeader> result = await gateway.searchMessages(
        _credentials,
        mailboxPath: kInboxPath,
        query: '   ',
      );

      expect(result, isEmpty);
      expect(server.receivedCommands, isEmpty);
    });

    test(
      'falls back to a charset-less search instead of a blanket protocol '
      'error when the server rejects the charset declaration entirely',
      () async {
        final EnoughMailGateway gateway = await gatewayFor(
          fakeSearchRejectsCharset(fallbackUids: <int>[9]),
          fakeFetchHandler(<int, FakeImapMessage>{
            9: const FakeImapMessage(
              uid: 9,
              subject: 'Ascii only',
              fromName: 'Carla',
              fromLocal: 'carla',
              fromDomain: 'hs-anhalt.de',
            ),
          }),
        );

        final List<MailMessageHeader> result = await gateway.searchMessages(
          _credentials,
          mailboxPath: kInboxPath,
          query: 'carla',
        );

        expect(result.single.id, '9');
        final Iterable<String> searchCommands = server.receivedCommands.where(
          (String c) => c.contains('UID SEARCH'),
        );
        expect(searchCommands, hasLength(2));
        expect(searchCommands.last, isNot(contains('CHARSET')));
      },
    );

    test('a server that rejects every search attempt still surfaces a typed '
        'MailFailure, never raw server text', () async {
      server = await FakeImapServer.start(
        fakeImapHandler(
          onSearch: (String tag, String command) => <String>[
            '$tag NO search failed unexpectedly',
          ],
          onFetch: fakeFetchHandler(const <int, FakeImapMessage>{}),
        ),
      );
      final EnoughMailGateway gateway = EnoughMailGateway(
        _LoopbackMailProfile(server.port),
      );

      await expectLater(
        gateway.searchMessages(
          _credentials,
          mailboxPath: kInboxPath,
          query: 'anything',
        ),
        throwsA(
          isA<MailFailure>().having(
            (MailFailure f) => f.kind,
            'kind',
            MailFailureKind.protocol,
          ),
        ),
      );
    });
  });
}
