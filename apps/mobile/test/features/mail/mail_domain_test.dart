// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:campus_koethen/features/mail/domain/hsa_mail_profile.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:campus_koethen/features/mail/domain/mail_search_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HsaMailProfile', () {
    test('pins the verified HSA endpoints', () {
      const HsaMailProfile p = HsaMailProfile();
      expect(p.imapHost, 'mail.hs-anhalt.de');
      expect(p.imapPort, 993);
      expect(p.smtpHost, 'mail.hs-anhalt.de');
      expect(p.smtpPort, 587);
    });

    test(
      'mandates TLS for IMAP and STARTTLS for SMTP, with no plaintext option',
      () {
        const HsaMailProfile p = HsaMailProfile();
        expect(p.imapImplicitTls, isTrue);
        expect(p.smtpStartTlsRequired, isTrue);
        // A profile that could ever describe plaintext is a security defect;
        // there are simply no ports 143 / 25 / 465 anywhere in it.
        final String s = '${p.imapPort} ${p.smtpPort}';
        expect(s.contains('143'), isFalse);
        expect(s.contains('25 '), isFalse);
        expect(s.contains('465'), isFalse);
      },
    );

    test('official webmail link is https', () {
      expect(const HsaMailProfile().webmailUrl, 'https://mail.hs-anhalt.de/');
      expect(Uri.parse(const HsaMailProfile().webmailUrl).scheme, 'https');
    });
  });

  group('MailCredentials', () {
    test(
      'uses the email address as IMAP username, SMTP username and sender',
      () {
        const MailCredentials c = MailCredentials(
          emailAddress: 'stud@hs-anhalt.de',
          password: 'irrelevant',
        );
        // There is deliberately no separate username / matrikel / login field:
        // the address is all three.
        expect(c.emailAddress, 'stud@hs-anhalt.de');
      },
    );

    test('NEVER exposes the password through toString', () {
      const MailCredentials c = MailCredentials(
        emailAddress: 'stud@hs-anhalt.de',
        password: 'super-secret-pw-123',
      );
      expect(c.toString().contains('super-secret-pw-123'), isFalse);
      expect(c.toString().contains('password'), isFalse);
      // The address may appear; it is not a secret.
      expect(c.toString().contains('MailCredentials'), isTrue);
    });

    test('equality is by value so state comparisons work', () {
      const MailCredentials a = MailCredentials(
        emailAddress: 'a@x',
        password: 'p',
      );
      const MailCredentials b = MailCredentials(
        emailAddress: 'a@x',
        password: 'p',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('email validation', () {
    test('accepts a plausible address and trims surrounding whitespace', () {
      expect(
        normalizeEmailAddress('  stud@hs-anhalt.de '),
        'stud@hs-anhalt.de',
      );
    });

    test('rejects obviously invalid input', () {
      for (final String bad in <String>[
        '',
        'no-at',
        'a@',
        '@b',
        'a b@c.de',
        'a@b',
      ]) {
        expect(isValidEmailAddress(bad), isFalse, reason: bad);
      }
    });

    test('does not lowercase or otherwise rewrite the local part', () {
      // The local part is case-sensitive per spec; we must not "helpfully" alter it.
      expect(
        normalizeEmailAddress('Stud.Name@hs-anhalt.de'),
        'Stud.Name@hs-anhalt.de',
      );
    });
  });

  group('OutgoingMessage attachments', () {
    test('defaults to no attachments', () {
      const OutgoingMessage message = OutgoingMessage(
        to: <String>['a@b.de'],
        subject: 's',
        text: 't',
      );
      expect(message.attachments, isEmpty);
    });

    test('OutgoingAttachment carries filename, media type and exact bytes', () {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final OutgoingAttachment attachment = OutgoingAttachment(
        filename: 'foto.png',
        mediaType: 'image/png',
        bytes: bytes,
      );
      expect(attachment.filename, 'foto.png');
      expect(attachment.mediaType, 'image/png');
      expect(attachment.bytes, same(bytes));
    });

    test('a message can carry several attachments', () {
      final OutgoingMessage message = OutgoingMessage(
        to: const <String>['a@b.de'],
        subject: 's',
        text: 't',
        attachments: <OutgoingAttachment>[
          OutgoingAttachment(
            filename: 'a.png',
            mediaType: 'image/png',
            bytes: Uint8List.fromList(<int>[1]),
          ),
          OutgoingAttachment(
            filename: 'b.pdf',
            mediaType: 'application/pdf',
            bytes: Uint8List.fromList(<int>[2]),
          ),
        ],
      );
      expect(message.attachments, hasLength(2));
      expect(message.attachments.map((a) => a.filename), <String>[
        'a.png',
        'b.pdf',
      ]);
    });
  });

  group('mail search matching', () {
    const MailMessageHeader header = MailMessageHeader(
      id: '1',
      subject: 'Prüfungsanmeldung',
      from: MailAddress(
        email: 'pruefungsamt@hs-anhalt.de',
        name: 'Prüfungsamt',
      ),
      date: null,
      isSeen: false,
      hasAttachments: false,
    );
    const MailMessageDetail detail = MailMessageDetail(
      id: '1',
      subject: 'Prüfungsanmeldung',
      from: MailAddress(email: 'pruefungsamt@hs-anhalt.de'),
      to: <MailAddress>[MailAddress(email: 'stud@hs-anhalt.de')],
      cc: <MailAddress>[MailAddress(email: 'sekretariat@hs-anhalt.de')],
      date: null,
      body: 'Die Anmeldung läuft bis Freitag.',
    );

    test('normalises case and surrounding whitespace', () {
      expect(normalizeMailSearchTerm('  PRÜFUNG \n'), 'prüfung');
      expect(normalizeMailSearchTerm('   '), isEmpty);
    });

    test('matches a header by subject and by sender', () {
      expect(
        mailTextMatches(mailHeaderSearchFields(header), 'prüfungs'),
        isTrue,
      );
      expect(
        mailTextMatches(mailHeaderSearchFields(header), 'pruefungsamt@'),
        isTrue,
      );
      expect(mailTextMatches(mailHeaderSearchFields(header), 'mensa'), isFalse);
    });

    test('matches a message by body, recipients and Cc', () {
      expect(
        mailTextMatches(mailDetailSearchFields(detail), 'freitag'),
        isTrue,
      );
      expect(mailTextMatches(mailDetailSearchFields(detail), 'stud@'), isTrue);
      expect(
        mailTextMatches(mailDetailSearchFields(detail), 'sekretariat'),
        isTrue,
      );
    });

    test('an empty term never matches anything', () {
      expect(mailTextMatches(mailDetailSearchFields(detail), ''), isFalse);
    });
  });
}
