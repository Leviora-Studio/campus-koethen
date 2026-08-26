# Studentische E-Mail (IMAP/SMTP)

Ein minimaler E-Mail-Client, der sich **direkt vom Gerät** mit dem Mailserver der
Hochschule Anhalt verbindet. Es gibt bewusst **keinen** serverseitigen Mail-Proxy.

## Architektur — nicht verhandelbar

- Die App verbindet sich **direkt** mit `mail.hs-anhalt.de`:
  - **IMAP** über `993` mit implizitem TLS (kein Fallback auf `143`/Klartext).
  - **SMTP-Submission** über `587` mit **verpflichtendem STARTTLS** (kein Fallback auf
    `25`/`465`/Klartext; Abbruch, wenn der Server STARTTLS nicht anbietet).
- Zertifikats- **und** Hostname-Prüfung sind aktiv. `allowBadCertificates` wird
  **nirgends** verwendet. Kein Certificate-Pinning.
- Die Campus-Köthen-API, Strapi und der Worker sind **nie** an Mail beteiligt. Sie
  erhalten **weder Zugangsdaten noch E-Mails**.
- Genau **zwei** Eingaben: E-Mail-Adresse + Passwort. Die Adresse ist zugleich
  IMAP-Benutzername, SMTP-Benutzername und Absender. Es gibt **kein** separates Feld
  für Matrikelnummer, Benutzername, Login, Absender oder Domain.

## Sicherheit

- Passwort und Adresse liegen **ausschließlich** im geräteeigenen sicheren Speicher
  (`flutter_secure_storage`, iOS Keychain / Android Keystore). **Nie** in
  `SharedPreferences` oder Hive. Kein unsicherer Fallback: Ist der sichere Speicher nicht
  verfügbar, wird **nicht** gespeichert und ein klarer Fehler gezeigt.
- Das Passwort erscheint **nie** in Logs, Exceptions, Telemetrie, `toString()` oder
  Debug-Ausgaben. Das Protokoll-Debugging von `enough_mail` ist **aus**
  (`isLogEnabled: false`).
- **Offline-Cache (bewusste Entscheidung):** Für schnelles und offline-fähiges Öffnen
  werden INBOX-Kopfzeilen und -Inhalte, der daraus gebildete Adressindex und, wenn
  eingeschaltet, Anhangbytes in der **verschlüsselten** Hive-Box
  `campus_mail_cache_secure_v2` zwischengespeichert. Ihr gerätegebundener 256-Bit-Schlüssel
  `mail.cache.key.v2` liegt ausschließlich in iOS Keychain beziehungsweise Android Keystore.
  Adresse und Passwort bleiben getrennte Secure-Storage-Daten und liegen **nie** im Cache.
- **Upgrade:** Der frühere unverschlüsselte Testcache `campus_mail_cache_v1` wird ungeöffnet und
  idempotent entfernt. Seine Inhalte werden weder gelesen noch in die neue Box migriert. Kann
  seine Abwesenheit nicht bestätigt werden oder ist der sichere Speicher nicht verfügbar, bleibt
  Mail für diese Sitzung ohne persistente Mailablage; es gibt keinen Klartext-Fallback.
- HTML-Mails werden zu **reinem Text** reduziert. Kein WebView, kein JavaScript, **keine**
  automatische Nachladung entfernter Bilder. Links laufen nur über den bestehenden
  sicheren URL-Launcher (`https`/`mailto`/`tel`).
- Verbindungen werden je Aufruf geöffnet und geschlossen. „Account entfernen“ sperrt zuerst die
  laufende Mailsitzung und entfernt dann logisch Adresse, Passwort, alten und neuen Cache,
  Cache-Schlüssel sowie den zugehörigen In-Memory-/Riverpod-State. Erfolg wird erst nach
  bestätigter Abwesenheit der persistenten Artefakte gemeldet; ein Teilfehler bleibt gesperrt und
  wird per dauerhaftem Lösch-Intent beim Retry oder nächsten App-Start fortgesetzt. Die
  Servermails bleiben unverändert. Dateilöschung und verworfener Schlüssel sind keine Zusage eines
  forensischen Secure Erase für Flash-Zellen, Betriebssystem-Snapshots oder Backups.

## Offline & Synchronisierung

- Der Posteingang wird aus dem Cache angezeigt — sofort und offline. Ein
  Hintergrund-Sync (`MailSyncController`) hält ihn frisch, ohne die Bedienung zu
  blockieren.
- **Ausgelöst** wird der Sync beim **App-Start**, bei **Anmeldung**, **alle 10 Minuten**
  (`kMailSyncInterval`, geplant im App-Shell) und **manuell** (Sync-Button /
  Pull-to-Refresh).
- Der Sync holt die **50 neuesten** INBOX-Header, **akkumuliert** sie in den Cache
  (nichts wird gelöscht — der Offline-Bestand wächst über 50 hinaus) und lädt die
  vollständigen Inhalte **neuer** Nachrichten im Hintergrund nach.
- **Anhänge herunterladen** ist optional (Einstellungen → Studentische E-Mail). Nur bei
  aktivierter Einstellung werden auch Nicht-Bild-Anhänge für die Offline-Nutzung geladen
  und lassen sich über das OS-Teilen-Menü (`share_plus`) teilen/speichern; Bilder werden
  ohnehin inline aus dem Speicher angezeigt.
- **Empfängervorschläge:** Beim Verfassen schlägt das An-/Cc-Feld Adressen aus der
  gecachten Mailhistorie (From/To/Cc) vor.

> Anmerkung: Es gibt **kein** Sync, während die App vollständig geschlossen ist — dafür
> wären native Hintergrunddienste (WorkManager/BGTaskScheduler) nötig, die dieses MVP
> bewusst nicht einbindet. Sync läuft, solange die App läuft, plus beim nächsten Start.

## Suche

- **Lokal zuerst:** Das Abschicken der Suche durchsucht ausschließlich den verschlüsselten
  Gerätecache des aktiven Kontos — Absender, Empfänger (To/Cc), Betreff und den bereits als
  Text vorliegenden Nachrichtentext. Treffer erscheinen sofort und **ohne Netz**. Es wird
  **kein** zusätzlicher Index angelegt; gesucht wird auf den Daten, die der Offline-Cache
  ohnehin hält. Anhangbytes werden **nicht** durchsucht.
- **Robustheit:** Der Suchbegriff wird getrimmt und Unicode-korrekt kleingeschrieben, damit
  deutsche Groß-/Kleinschreibung (`Prüfung`/`PRÜFUNG`) und umgebende Leerzeichen keine Rolle
  spielen. `ß`/`ss` werden **nicht** aufeinander abgebildet — dafür bleibt die Serversuche.
- **Nur die INBOX ist gecacht.** In einem anderen Ordner sagt die Suche das ausdrücklich und
  zeigt keine lokalen Ergebnisse; dieser Ordner wird dadurch auch nicht zusätzlich gecacht.
- **Serversuche als zweiter, ausdrücklicher Schritt:** „Zusätzlich auf dem Server suchen“ führt
  **IMAP SEARCH** über denselben Begriff und denselben Ordner aus und findet damit auch
  Nachrichten, die nicht auf dem Gerät liegen.
- **Deduplizierung und Reihenfolge:** Serverergebnisse werden über die stabile Nachrichten-ID
  (IMAP-UID im selben Ordner) gegen die lokalen Treffer abgeglichen; dieselbe Nachricht
  erscheint genau einmal. Angezeigt werden erst die lokalen Treffer, dann die zusätzlichen
  Servertreffer — jeweils neueste zuerst, sodass sich die Liste beim Eintreffen der
  Serverantwort nicht umsortiert.
- **Fehler trennen die beiden Hälften:** Ein IMAP-Fehler (offline, Timeout, Server nicht
  erreichbar) erscheint als eigener Hinweis mit „Erneut versuchen“ und lässt die lokalen
  Treffer stehen. Umgekehrt heißt „keine lokalen Treffer“ ausdrücklich noch nicht „nichts
  gefunden“, solange der Server nicht gefragt wurde.
- Ein Servertreffer öffnet sich wie jede andere Nachricht: fehlende Inhalte werden geladen und
  anschließend (INBOX) gecacht.
- **Kontowechsel:** „Account entfernen“ verwirft Cache und Suchzustand (Begriff, lokale und
  Servertreffer, Fehler) über dieselbe Session-Generation wie der übrige Mail-State.

## Schichten

```
features/mail/
  domain/         Reine Modelle + Ports: MailGateway, MailCredentialStore, MailCacheStore
                  (inkl. searchHeaders für die lokale Suche), MailCredentials,
                  MailMessage*, mail_search_match (Normalisierung + Feldabgleich),
                  MailFailure, HsaMailProfile
  data/           Adapter: EnoughMailGateway (kapselt enough_mail vollständig),
                  mail_mime_builder (MIME-Aufbau inkl. Anhänge, von Send und
                  Sent-Kopie geteilt), MailAttachmentPicker (kapselt file_selector),
                  SecureMailCredentialStore, EncryptedMailCache, MailCacheManager,
                  MailLocalDataCoordinator, html_to_text
  application/    Riverpod-Controller: Account, Inbox, Compose, Search (lokal + Server),
                  Provider
  presentation/   Screens: Setup, Inbox, Message, Compose + Fehler-Mapping
```

Die UI und die Riverpod-Controller kennen **keine** `enough_mail`-Typen — die Bibliothek
liegt vollständig hinter `MailGateway`. Ebenso kennt die UI keinen Picker-/Dateisystemtyp:
`MailAttachmentPicker` liefert Anhänge als domänen­eigene Handles (`PickedMailFile`), nicht
als `XFile`. Tests nutzen ausschließlich In-Memory-Fakes (`FakeMailGateway`,
`InMemoryMailCredentialStore`, `FakeMailAttachmentPicker`) und verbinden sich **nie** mit dem
echten Server oder einem echten Dateidialog.

`EncryptedMailCache` serialisiert Maildaten über den Port `MailCacheStore` und den gemeinsamen
Kryptobaustein in die verschlüsselte Mailbox. `MailCacheManager` besitzt deren Lebenszyklus:
Aktivierung, Memory-only-Degradation, Altcache-Entfernung, Write-Fence und verifizierte
Artefaktlöschung.
`MailLocalDataCoordinator` koordiniert diesen Adapter mit Credentials und Lösch-Intent vor der
Kontowiederherstellung sowie beim Entfernen des Accounts.

## Automatisierte Tests

```bash
flutter test test/features/mail/
```

- `mail_domain_test.dart` — Profil-Endpunkte, Credentials-Redaction, E-Mail-Validierung,
  `OutgoingMessage.attachments` (Default leer, mehrere Anhänge).
- `mail_mime_builder_test.dart` — MIME-Aufbau mit und ohne Anhänge: Dateiname, Media-Type und
  Bytes überleben byteidentisch den Roundtrip, mehrere Anhänge gleichzeitig, Text bleibt neben
  Anhängen erhalten, zweimaliger Aufbau aus derselben Nachricht liefert identischen Anhangsinhalt
  (Grundlage dafür, dass Sent-Kopie und SMTP-Versand exakt dieselben Bytes tragen).
- `mail_cache_test.dart` — verschlüsselter Roundtrip einschließlich Anhängen und Adressindex,
  Altcache-Verwerfung, Schlüssel-/Speicherfehler, Restart-Recovery, idempotenter Wipe und die
  lokale Suche über den verschlüsselten Cache (Betreff/Text/Empfänger, Reihenfolge, keine
  Anhangbytes, Header-Rekonstruktion, nach dem Wipe keine Treffer mehr).
- `mail_controller_test.dart` — Anmelden/Abmelden, unvollständigen Wipe erneut versuchen,
  Write-Fence bei laufendem Sync, Inbox-Laden, typisierte Fehler, Doppel-Send-Schutz (auch mit
  Anhängen), Sent-Kopie-Ergebnis, dass Anhänge unverändert bis zum Gateway durchgereicht werden,
  sowie die Suche: lokaler Treffer ohne IMAP-Aufruf, deutsche Groß-/Kleinschreibung und
  Leerzeichen, Nichttreffer, nicht gecachter Ordner, Deduplizierung Cache↔IMAP, IMAP-Fehler mit
  erhaltenen lokalen Treffern und Retry, verworfene verspätete Antwort, Kontoentfernung.
- `mail_ui_test.dart` — Gate (Setup ↔ Inbox), Anmeldeformular-Validierung, Account
  entfernen, Nachricht anzeigen (+ als gelesen markieren), Verfassen/Senden inkl. Anhänge:
  auswählen und mit Name/Größe anzeigen, vor dem Senden entfernen, abgebrochener Picker lässt
  den Entwurf unverändert, gesendete Nachricht enthält den Anhang, eine beim Senden nicht mehr
  lesbare Datei zeigt einen verständlichen Fehler und lässt Screen/Entwurf unangetastet, Senden
  deaktiviert Anhang-Auswahl und Entfernen-Buttons; Suche: gecachter Treffer ohne Serverkontakt,
  zusätzliche Servertreffer ohne Dubletten, IMAP-Fehler mit erhaltenen lokalen Treffern und
  Retry, klarer Leerzustand, Öffnen eines nur serverseitigen Treffers (wird dabei gecacht).

## Manuelle Testcheckliste (echter Server, echtes Konto)

> Nie echte Zugangsdaten in Code, Tests, Fixtures oder Commits ablegen. Diese Liste wird
> mit einem **persönlichen** Hochschulkonto auf einem Gerät durchgeführt.

Einrichtung / Sicherheit

- [ ] Setup-Screen zeigt Unabhängigkeitshinweis, Erklärung der Direktverbindung, den
      Hinweis, dass Campus-Server keine Zugangsdaten/Mails erhalten, und den externen Link
      auf `https://mail.hs-anhalt.de/`.
- [ ] Anmeldung mit korrekten Daten führt in den Posteingang.
- [ ] Falsches Passwort → verständliche Fehlermeldung, **keine** rohen Serverdaten,
      **kein** Speichern.
- [ ] Ungültige Adresse → lokale Validierung, Server wird **nicht** kontaktiert.
- [ ] Upgrade einer präparierten Testinstallation mit befülltem `campus_mail_cache_v1`: Start
      ohne Absturz, keine alten Nachrichten oder Empfängervorschläge, neuer Cache zunächst leer;
      nach erneutem App-Start bleibt der Altcache abwesend.
- [ ] Nach erfolgreichem „Account entfernen“ ist wieder der Setup-Screen sichtbar; erneuter
      App-Start landet im Setup und zeigt weder alte Nachrichten/Details noch alte
      Empfängervorschläge.
- [ ] Ein simulierter Teilfehler beim Entfernen meldet keinen Erfolg, hält Mail gesperrt und lässt
      den logischen Wipe erneut versuchen; nach erfolgreichem Retry bleibt der Zustand auch nach
      Neustart leer.

Posteingang / Detail

- [ ] Es werden bis zu 50 aktuelle Nachrichten des gewählten Ordners (neueste zuerst)
      angezeigt.
- [ ] Ungelesene sind nicht nur über Farbe erkennbar (Icon/Fettung).
- [ ] Öffnen einer Nachricht zeigt reinen Text; sie wird als gelesen markiert.
- [ ] HTML-Mail wird als Text dargestellt; entfernte Bilder werden **nicht** geladen.
- [ ] Mail mit Anhang zeigt die Anhänge; empfangene Bild-Anhänge (mit lokalen Bytes)
      erscheinen unabhängig vom Absender automatisch inline; fehlerhafte Bilddaten
      zeigen einen Platzhalter.
- [ ] Tippen auf einen Anhang öffnet ihn **in der App**: Bilder zoombar, PDFs im
      nativen Renderer (kein WebView), Textdateien als Text; andere Typen bieten
      „Teilen/Speichern“.
- [ ] Flugmodus → Aktualisieren zeigt einen Fehler mit „Erneut versuchen“, kein Absturz.

Suche

- [ ] Das Lupen-Symbol öffnet die Suche; ein Begriff aus einer bereits geladenen Mail
      (Absender, Empfänger, Betreff oder Text) liefert **sofort** einen Treffer.
- [ ] Groß-/Kleinschreibung und umgebende Leerzeichen ändern nichts am Ergebnis
      (zwei Leerzeichen vor und eines nach `prüfung` finden `Prüfungsanmeldung`).
- [ ] **Flugmodus:** Die lokalen Treffer erscheinen weiterhin; „Zusätzlich auf dem Server
      suchen“ endet mit einer verständlichen Meldung und „Erneut versuchen“, ohne die
      lokalen Treffer zu entfernen.
- [ ] „Zusätzlich auf dem Server suchen“ findet über **IMAP SEARCH** eine Mail, die noch
      **nicht** lokal vorliegt.
- [ ] Eine Mail, die Cache **und** Server liefern, erscheint genau **einmal**.
- [ ] Ein Treffer öffnet die Nachricht (wird bei Bedarf nachgeladen und gecacht).
- [ ] In einem anderen Ordner weist die Suche darauf hin, dass er nicht lokal vorliegt, und
      zeigt keine lokalen Treffer.
- [ ] Nach „Account entfernen“ zeigt die Suche keine Ergebnisse des vorherigen Kontos.

Ordner

- [ ] Das Ordner-Symbol öffnet die Liste **aller** Server-Ordner (IMAP LIST); ein
      Sonderordner (Gesendet/Entwürfe/Papierkorb/Spam/Archiv) trägt Symbol und
      lokalisierten Namen.
- [ ] Auswahl eines Ordners lädt dessen Nachrichten; der Titel zeigt den Ordnernamen.
- [ ] Öffnen einer Nachricht in einem anderen Ordner liest aus **diesem** Ordner.

Verfassen / Senden

- [ ] „Von” ist die eigene Kontoadresse (nicht editierbar); ist beim Einrichten ein
      Anzeigename gesetzt, sehen Empfänger `”Name” <adresse>`.
- [ ] Senden an eine gültige Adresse: die App kehrt **sofort** nach dem SMTP-Versand
      zum Posteingang zurück (kein Verweilen im Sende-Screen); die Kopie im Ordner
      „Gesendet” wird im Hintergrund abgelegt, ein Hinweis erscheint nur, wenn das
      nicht klappt.
- [ ] Mehrere Empfänger in „An”/„Cc” mit Komma getrennt werden alle adressiert.
- [ ] Schnelles Doppeltippen auf „Senden” verschickt **nur einmal**.
- [ ] Ungültiger Empfänger → Validierung, kein Sendeversuch.
- [ ] „Datei anhängen” öffnet den OS-Dateidialog **ohne** Typfilter; mehrere Dateien lassen
      sich auf einmal wählen; jede erscheint mit Dateiname und formatierter Größe und ist
      einzeln entfernbar; ein abgebrochener Dialog lässt den Entwurf unverändert.
- [ ] Anhang-Auswahl und „Entfernen” sind während des Sendens deaktiviert.
- [ ] **Mit echtem Testpostfach:** Nachricht mit mindestens einem Bild- und einem
      Dokumentanhang (z. B. PNG + PDF) an eine echte Adresse senden; im Zielpostfach prüfen,
      dass beide Anhänge mit korrektem Dateinamen, Media-Type und unveränderten Bytes
      ankommen; danach die Kopie im eigenen Ordner „Gesendet” öffnen und denselben Anhang
      dort ebenfalls unverändert vorfinden.
- [ ] Eine beim Senden nicht mehr lesbare, zuvor ausgewählte Datei (z. B. in der Zwischenzeit
      gelöscht) zeigt einen verständlichen Fehler; Empfänger, Betreff, Text und die übrige
      Anhangliste bleiben erhalten; es gibt **keinen** automatischen zweiten Sendeversuch.

Antworten

- [ ] „Antworten” öffnet den Verfassen-Screen mit dem Absender als Empfänger,
      „Re: …”-Betreff und zitiertem Originaltext.
- [ ] „Allen antworten” adressiert zusätzlich alle ursprünglichen Empfänger (Cc),
      **ohne** die eigene Adresse.

Barrierefreiheit / i18n

- [ ] Deutsch und Englisch: alle neuen Texte übersetzt, keine hartkodierten Strings.
- [ ] Ausreichende Kontraste in Light **und** Dark Theme.
- [ ] Touch-Ziele ≥ 48 dp; doppelte Schriftgröße ohne Überlauf.

## Bekannte Grenzen (bewusst)

Kein Hintergrund-Sync, kein IMAP IDLE, kein Verschieben/Löschen, keine Ordnerverwaltung
(nur Lesen/Wechseln, kein Anlegen/Umbenennen), keine mehrfachen Konten. Empfangene Anhänge
werden **angezeigt** und lassen sich **in der App öffnen** (Bilder, PDF, Text) sowie über das
OS-Menü teilen/speichern. Beim Verfassen lassen sich beliebige Dateien über den OS-Dateidialog
anhängen (kein Typfilter, kein Upload-Limit über die Gerätespeichergrenzen hinaus) — es gibt
weiterhin **keinen** eigenen Entwürfe-Ordner, **keine** automatische Kompression und **keinen**
Cloud-Speicher für Anhänge; sie leben nur im Arbeitsspeicher des Compose-Screens bis zum Senden.

**Screenshot- und App-Switcher-Schutz gilt nur für den Anmeldebildschirm** (`ProtectedScreen` in
`mail_setup_screen.dart`), nicht für die Nachrichtenansicht. Mailinhalte sind im App-Switcher
lesbar und lassen sich per Screenshot teilen. Das ist der in LEVIORA-179 entschiedene und in
LEVIORA-181 bestätigte Umfang — geschützt wird, wo ein Passwort eingegeben wird, nicht, was man
absichtlich weiterleiten können soll. Begründung und Gesamtumfang: [grades.md](grades.md),
Abschnitt „App-Switcher-Vorschau".
