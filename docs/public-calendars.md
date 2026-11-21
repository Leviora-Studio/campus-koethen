<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Leviora Studio and Jona Loreen Sommer -->

# Redaktionelle Kalender und öffentliche Google-Kalender (ICS)

Redakteur:innen legen in Strapi Kalender und eigene Termine an. Optional wird ein
**öffentlicher** Google-Kalender verknüpft. Der Campus-Worker
synchronisiert sie über den **öffentlichen ICS-Feed**, die Campus API liefert Katalog und Termine,
und die App führt sie – lokal – mit Stundenplan und Moodle-Deadlines im Kalender-Tab zusammen. Nach
der einmaligen Implementierung braucht ein weiterer Kalender **weder App- noch Backend-Änderung**.

## 1. Erlaubter Datenfluss

```
Strapi (public-calendar)  ──▶  Campus-Worker  ──ICS──▶  calendar.google.com (public/basic.ics)
   Definitionen                 │  validiert, parst, normalisiert
                                ▼
                          PostgreSQL (operatives Read-Model)  ──▶  Campus API  ──▶  Flutter
```

- **Kein** Google API Key, **kein** Google-Cloud-Projekt, **kein** Google-OAuth, **kein** SDK.
- Die **App ruft den ICS-Feed nie direkt ab**. Nur der Worker lädt ihn.
- Die **Feed-URL** bleibt backendintern (nie ein DTO-Feld, nie geloggt); dasselbe gilt für ETag
  und `lastContentHash`.
- Die **Google-Kalender-ID** ist kein DTO-Feld, steckt aber base64-kodiert im `cid` von
  `googleOpenUrl` und im Klartext in den `src`-Parametern von `/v1/calendars/google-view-url` —
  ohne sie funktionieren diese Links nicht. Das ist unkritisch: Es geht ausschließlich um Kalender,
  die die Redaktion öffentlich geteilt hat, und die ID ergibt sich ohnehin aus dem öffentlichen
  Freigabelink. Sie ist damit **kein** Geheimnis.
- Zusammenführung mit Stundenplan/Moodle passiert **ausschließlich lokal** in Flutter.

## 2. Von der Freigabe zur Feed-URL

Redakteur:innen tragen einen **öffentlichen Freigabelink** ein, z. B.
`https://calendar.google.com/calendar/u/0?cid=<base64url>`. Aus dem `cid` wird die Kalender-ID
extrahiert und daraus **serverseitig** die feste Feed-URL konstruiert:

```
https://calendar.google.com/calendar/ical/{URL-kodierte-ID}/public/basic.ics
```

Validierung (`google-calendar-url.ts`, 36 Tests): HTTPS-only · Host **exakt** `calendar.google.com`
· kein Userinfo/Port · Pfad-Allowlist (`render`, `u/N`, `u/N/r`) · genau **ein** `cid` · Base64/-URL
mit kanonischem Roundtrip · striktes UTF-8 · Längenlimits · keine Steuerzeichen/Whitespace. Abgelehnt
werden u. a. `http`, `webcal`, `calendar.google.com.attacker.example`, `user@…`, Ports, IPs sowie
direkt eingefügte `basic.ics`-/`private-…`-Links. Dieselbe Validierung läuft **erneut** an der
Backend-Vertrauensgrenze (`validateCatalog`).

## 3. SSRF-Schutz & ICS-Client

`GooglePublicIcsClient` (12 Tests): fester Scheme+Host+Pfad · Kalender-ID als **einziges**
`encodeURIComponent`-Pfadsegment · **keine** Basis-URL aus Strapi/ENV · Redirects werden **nicht**
verfolgt (3xx → abgelehnt) · harte Timeouts, begrenzte Retries (nur 5xx/429/Transport),
Request-Abstand · `Content-Length`-Vorabprüfung **und** Streaming-Byte-Limit (Abbruch bei
Überschreitung) · `Content-Type: text/calendar` (tolerant nur bei gültigem VCALENDAR-Body) ·
ETag/Last-Modified + `If-None-Match`/`If-Modified-Since` + **304** · Feed-URL/ID nie in Fehlern.

## 4. RFC-5545-Parser

`ics-parser.ts` nutzt **`ical.js`** (Mozilla, MPL-2.0, **null** Laufzeit-Abhängigkeiten) – **keine**
naive Zeilentrennung. Unterstützt (17 Tests): Zeilenfaltung, Escaping, Parameter, `VTIMEZONE`, UTC,
TZID, floating (mit kontrollierter Fallback-Zeitzone), `VALUE=DATE` mit **exklusivem** `DTEND`,
`DTSTART`+`DURATION`, `RRULE`/`RDATE`/`EXDATE`, `RECURRENCE-ID` (verschoben/abgesagt), abgesagte
Events, `SEQUENCE`/`LAST-MODIFIED`, DST-Wechsel. **Netzwerkfunktionen des Parsers werden nicht
verwendet** – ihm wird nur der bereits geladene, größenbegrenzte Text übergeben.

- **Wiederholungen** werden **nur** im Zielzeitfenster expandiert. Eine Serie ist an ihrem `DTSTART`
  verankert und lässt sich nicht vorspulen, also muss der Iterator bis zum Fenster laufen. Deshalb
  greifen **zwei** getrennte Obergrenzen:
  - `PUBLIC_CALENDAR_MAX_OCCURRENCES_PER_EVENT` zählt nur Vorkommen **eines** Events, die das
    Fenster tatsächlich erreichen. Eine seit Jahren laufende Wochenserie wird dadurch normal
    expandiert, eine „recurrence bomb“ im Fenster (`FREQ=MINUTELY`) läuft weiterhin dagegen.
  - `PUBLIC_CALENDAR_MAX_SCANNED_OCCURRENCES` begrenzt die **Iterationsschritte des gesamten Laufs**
    inklusive der vor dem Fenster übersprungenen und stoppt damit eine Hochfrequenzserie, die lange
    **vor** dem Fenster beginnt.

  Beide Verletzungen enden in `recurrenceLimitExceeded` und sind nie destruktiv.

- **Ganztägig:** lokales Kalenderdatum, exklusives Enddatum, keine UTC-/Gerätezeitzonen-Verschiebung.
- **Datenminimierung:** `ATTENDEE`/`ORGANIZER`/`CONTACT`/`ATTACH`/Konferenz/Alarme/`X-*` werden
  **nie gelesen** → keine E-Mail-Adressen. `DESCRIPTION`/`LOCATION` nur bei entsprechendem
  Strapi-Flag, immer als **Plain Text** (nie HTML).

## 5. Strapi = Quelle, PostgreSQL = resilientes Read-Model

Strapi ist die kanonische redaktionelle Quelle. Der Worker spiegelt **validierte** Definitionen in
ein minimales operatives Read-Model (`PublicCalendar`) für Google-Importe. Google-Termine erscheinen
erst nach Validierung und erfolgreichem ICS-Sync der aktuell verknüpften Quelle. Eigene Termine und
der öffentliche Kalenderkatalog werden über die Strapi-REST-API mit einem kurzen Cache gelesen;
ein Strapi-Ausfall kann deshalb einen Kalenderabruf fehlschlagen lassen. Eine
fehlerhafte/leere/unvollständige Strapi-Antwort **löscht den letzten gültigen Importbestand nie**.
Eine ausdrücklich entfernte optionale Google-Verknüpfung deaktiviert ihren Import. Roh-ICS wird
**nie** gespeichert. Quellenwechsel und Änderungen der Freigabe von Beschreibung/Ort verwerfen
alte Abrufvalidatoren. Die API prüft die aktuelle Quellenzuordnung und Freigaben ebenfalls, sodass
alte Daten nicht bis zum nächsten Worker-Lauf ungeprüft ausgeliefert werden (Katalogcache: 30 Sekunden).

## 6. Worker-Sync & Reconciliation (10 Integrationstests, echte DB)

- Getrennte Jobs `catalog` und `events`, per `PUBLIC_CALENDAR_ENABLED` schaltbar, eigener
  Overlap-Guard, unabhängig von Canteen/Timetable.
- Pro Kalender: SyncRun `running` → ICS laden (bytebegrenzt) → validieren → parsen → im Zielfenster
  expandieren → **Transaktion**: upsert + Löschen **nur** im bestätigten Fenster für nicht mehr
  gesehene `occurrenceKey` → Status/`lastSuccessfulSyncAt` setzen.
- **Leerer** Feed darf einen vorhandenen erfolgreichen Terminbestand nicht löschen. Ohne
  vorherigen Bestand ist ein leerer Erstimport zulässig.
- **Unveränderter Hash/304** = teure Parse-/Persistenzphase überspringen, Status/Zeitstempel trotzdem
  aktualisieren. Mindestens am nächsten UTC-Tag wird der Feed erneut vollständig verarbeitet,
  damit Serien auch bei unveränderter ICS-Datei in das weiterwandernde Zeitfenster hinein expandieren.
- Quellenzuordnung und Datenstand werden innerhalb derselben Datenbanktransaktion geprüft.
  Verspätete Antworten eines überholten Imports dürfen neuere Daten weder überschreiben noch löschen.
- **Temporärer Fehler** (Timeout/Netz/5xx/429): letzten Stand behalten, Kalender `stale`, weiter
  ausliefern.
- **Beschädigt/zu groß/Recurrence-Limit:** keine destruktive Übernahme; `stale` (mit Vorstand) bzw.
  `invalid` (ohne) — bei erstem Sync nicht öffentlich.
- **Freigabe entzogen** (404/410/403): Google-Status `revoked`/`unavailable`, importierte Termine
  gelöscht. Eigene Strapi-Termine und der redaktionelle Kalender bleiben verfügbar.

## 7. Campus API

- `GET /v1/calendars` — Katalog der aktiven, validen Kanal-Kalender; eigene Termine benötigen keinen Google-Sync.
  DTO: `id, slug, channelSlug, name, colorHex, sortOrder, defaultSubscribed, dataState,
lastSuccessfulSyncAt, dataStale, googleOpenUrl`. `channelSlug` verknüpft einen Kalender
  1:1 mit einem redaktionellen Kanal und ist im App-Katalog immer gesetzt. Unzugeordnete
  Kalender sind über den Website-Endpunkt erreichbar. `colorHex` ist die Farbe dieses Kanals. **Nie** Google-ID,
  Feed-URL, ETag oder interne Fehler.
- `GET /v1/calendars/all` — Website-Katalog mit demselben DTO, enthält zusätzlich Kalender ohne
  Kanal (`channelSlug` dann leerer String). Gedacht für `GET /v1/calendars/:slug/entries`.
- `GET /v1/calendars/:slug/events?from&to` — Termine eines Kalenders (Zeitraum begrenzt).
  Das Abfrageintervall ist als **Überlappung** definiert (`startsAt <= to AND endsAt >= from`).
- `GET /v1/calendars/events?calendar=…&calendar=…&from&to` — aggregiert; Slugs dedupliziert,
  begrenzt; **leere Auswahl ⇒ leere Liste** (nie „alle“); Überlappungsabfrage; pro Termin `calendarId`+`calendarSlug`;
  deterministisch sortiert. Redaktionelle Daten werden seitenweise über Strapi gelesen und kurz
  zwischengespeichert; Google-Daten kommen aus dem operativen Read-Model.
- `GET /v1/calendars/google-view-url?calendar=…` — serverseitig konstruierte
  `calendar.google.com/embed`-URL (ein `src` je Kalender, `ctz`), nur aktive/öffentliche Kalender.

## 8. App

- **Kalender-Tab:** Die Quelle „Events“ zeigt genau, was der Reiter Events zeigt: Event-Beiträge
  und Termine der öffentlichen Kalender der **ausgewählten Channels**, mit derselben Duplikatregel
  (eigener Strapi-Termin vor Event-Post vor Google-Termin; gleicher Titel und vollständiger Zeitraum). Anders als die Übersicht zeigt
  der Kalender auch Vergangenes im betrachteten Zeitraum. Termine erhalten die Channel-Farbe
  **plus** Channel- bzw. Kalendernamen/Icon (Farbe nie alleiniges Merkmal). Fallen Beiträge oder
  Kalender aus, bleibt die jeweils andere Hälfte sichtbar; ein Fehler blendet Stundenplan/Moodle
  **nicht** aus.
- **Auswahl:** Es gibt **eine** Channel-Auswahl für Reiter Events und Kalender (Quellenfilter der
  Events, lokal in SharedPreferences). „Kalender verwalten“, das Events-Sheet im Kalender und das
  Onboarding schreiben dieselbe Auswahl. Erstnutzung: alle Channels aktiv; ein neu erscheinender
  Channel wird einmal aktiviert; bewusst deaktivierte bleiben aus; keine Auswahl ⇒ keine Events.
  Das Feld `defaultSubscribed` eines Kalenders wertet die App nicht mehr aus.
- **Tageszuordnung:** Ein ganztägiger Termin nennt ein **Datum** und wird vom Worker als
  UTC-Mitternacht abgelegt; die App liest ihn genau so zurück, damit ihn keine Gerätezone
  verschiebt. Ein zeitgebundener Termin ist ein **Zeitpunkt** und wird vor der Tageszuordnung nach
  Ortszeit konvertiert. `DTEND` ist exklusiv: ein Termin, der um Mitternacht endet, erreicht den
  Folgetag nicht. Mehrtägige Termine — Prüfungszeitraum, vorlesungsfreie Zeit — erscheinen an
  **jedem** Tag, den sie berühren, in Tagesagenda, Wochenstreifen und Monatsraster. Im Zeitraster
  der Wochenansicht bleibt ein _zeitgebundener_ Termin in seiner Startspalte, weil ein Raster keine
  Box über zwei Spalten zeichnen kann; ganztägige Termine stehen dort im Band über dem Raster und
  spannen mit.
- **Google-Buttons:** „In Google Kalender öffnen“ (einzeln, `googleOpenUrl`, bei jedem Channel mit
  Google-Verknüpfung) extern via `url_launcher` (HTTPS, Browser-Fallback). Die kombinierte Embed-URL
  (`/v1/calendars/google-view-url`) stellt das Backend bereit; die App bietet dafür derzeit keinen
  Button an. Kein automatisches Hinzufügen zum persönlichen Google-Konto; Stundenplan
  und Moodle sind keine Google-Quellen und nicht Teil der kombinierten Ansicht.

## 9. Strapi-Redaktionshandbuch

1. Strapi öffnen → **Public Calendar → Create an entry**.
2. **Name** (lokalisiert) und **Slug** (nur `a-z0-9-`, stabil, nach Veröffentlichung nicht mehr
   ändern) eintragen.
3. Optional **googleShareUrl**: den **öffentlichen** Google-Freigabelink mit `cid` einfügen
   (`https://calendar.google.com/calendar/u/0?cid=…`). **Keine** geheime/private „iCal-Adresse“ und
   **keine** `basic.ics`-URL.
4. **sortOrder** wählen. Eine eigene Farbe hat der Kalender nicht: Seine Termine tragen die Farbe
   seines Channels.
5. Den Kalender am **Channel** zuordnen (Feld `publicCalendar` des Channels). Ohne Channel erscheint
   er nirgends in der App. Je Channel ist genau ein Kalender möglich: Strapi lehnt eine zweite
   Zuordnung beim Speichern ab und nennt den bereits zugeordneten Kalender. Channel und Kalender
   müssen vorher **denselben Standort** (Feld `location`, Typ **Location**) haben; fehlt er auf
   einer Seite oder unterscheidet er sich, lehnt Strapi die Verknüpfung mit einem Hinweis ab.
6. **includeEventDescription** und **includeEventLocation** datensparsam entscheiden. Die Felder
   steuern ausdrücklich, ob Beschreibungen bzw. Orte importierter Termine in API und App erscheinen.
7. **Speichern und Veröffentlichen** (Draft & Publish).
8. Auf den **ersten erfolgreichen ICS-Sync** warten; danach erscheint der Kalender in `GET
/v1/calendars` und der App.
9. Bei Entzug der Freigabe: Eintrag deaktivieren (`isActive=false`) oder Freigabe klären.

Der serverseitige read-only Strapi-Token braucht **Leserechte** für veröffentlichte
`public-calendar`-Einträge. **Keine** öffentliche anonyme Strapi-Berechtigung aktivieren.

## 10. Veröffentlichungsrechte

Technisch öffentlich lesbar ≠ rechtlich frei weiterveröffentlichbar. Vor dem produktiven Eintrag
organisatorisch klären: Zustimmung des Inhabers, zulässiger Quellenhinweis, ob Beschreibung/Ort
gezeigt werden dürfen, Ansprechpartner, Verhalten bei Entzug. Teilnehmer-/Organizer-E-Mail-Adressen
werden **nie** übernommen oder veröffentlicht.

## 11. Konfiguration & Abhängigkeit

ENV (siehe `apps/backend/src/config/env.schema.ts`): `PUBLIC_CALENDAR_ENABLED` und der `PUBLIC_CALENDAR_*`-Block.
Standardparameter: Lookahead 400 Tage, API Max Range 400 Tage, Max Occurrences per Event 2000, Max Occurrences 25000.
Für DEV muss `PUBLIC_CALENDAR_ENABLED=true` gesetzt und der Strapi-Token mit Leserechten versehen
werden. Neue Abhängigkeit: **`ical.js@2.2.1` (MPL-2.0, keine transitiven Laufzeit-Deps)** — Bewertung
in [`legal/dependency-licenses.md`](legal/dependency-licenses.md).

## Editorial calendars (1.2.5)

The existing `public-calendar` collection is now displayed as **Calendar**; its
technical UID and slugs remain unchanged. `googleShareUrl` is optional. A calendar
can contain editorial appointments without any Google import or successful ICS sync.
Assign the calendar to a channel to offer it in the app (one calendar per channel).
Channel and calendar must name the same **Location** before they can be linked;
a linked pair can never point at two different locations.

Create appointments in **Calendar Entry** and select their calendar. Fields:
`title`, stable `slug`, plain-text `description`, `location`, `start`, `end`,
IANA `timeZone` (default `Europe/Berlin`), `allDay`, `image`, labelled HTTPS `links`,
and uploaded `attachments`. German is canonical; title, description, location and
links can be translated into English. Drafts are never publicly served.
Timed start/end values are absolute ISO timestamps including an offset. End must
be after start. All-day dates use UTC midnight and an **exclusive end date**
(e.g. November 16 is `2026-11-16T00:00:00Z` to `2026-11-17T00:00:00Z`).
Recurrence, invitations, attendees and reminders are not supported.

- Existing `/v1/calendars/events` and `/v1/calendars/:slug/events` return Google
  occurrences plus editorial appointments. Existing post endpoints stay unchanged.
- **Website catalogue:** `GET /v1/calendars/all?locale=de` lists every published, active
  calendar, including calendars without a channel (`channelSlug` is then an empty string).
  `GET /v1/calendars` stays the channel-based app catalogue.
- **Locations:** every catalogue entry carries `location` (`{ slug, name }` or `null`).
  `GET /v1/locations` lists the active locations; `?location=<slug>` on
  `GET /v1/calendars/all` (and `GET /v1/calendars`) keeps only calendars of that location.
- **Website:** `GET /v1/calendars/:slug/entries?from=2026-11-01&to=2026-11-30&locale=de`
  additionally includes event posts of the linked channel, projected onto neutral
  appointment fields. No post blocks, tags or navigation options are returned.
- Fields: `id`, `calendarId`, `calendarSlug`, `title`, `description`, `location`,
  `start`, `end`, `allDay`, `status`, `source` (`editorial`, `post`, `google`),
  `timeZone`, `imageUrl`, `links` (`label`, `url`), `attachments` (`name`, `url`,
  `mimeType`). Time zone is null for sources without explicit zone metadata.
  Image/file URLs are relative to the Campus API origin; resolve them against
  that origin on websites hosted elsewhere. Rich descriptions are plain text.
- Date ranges and result counts use the existing calendar limits. Check
  `meta.truncated`; a truncated response is not a complete calendar export.
- Duplicate identity: same calendar (channel in the app), whitespace-normalised,
  case-sensitive title, exact UTC start AND end, and same all-day flag. All-day
  periods use civil dates; a post without an end occupies one full day.
  Priority: **editorial appointment > event post > Google**. Keep the winning
  entry whole. Different titles or durations are separate appointments.
- Upload downloads use `/v1/media/files/:filename` with attachment disposition,
  no redirects, strict upload-path validation and the existing 12 MiB limit.
  Supported attachments: raster images, PDF, plain text, CSV, ICS, ZIP,
  Word/Excel/PowerPoint (legacy and OOXML), and OpenDocument text/sheets/slides.
  Active HTML/SVG documents are not served.

Deployment: update CMS, API and worker together. Strapi creates the new collection
and component on startup. Existing calendar/channel relations are retained; no
operational Prisma migration is needed. A custom CMS token must gain read-only
`find` access to `calendar-entry`; the standard read-only token already covers it.
Google sync settings control Google import; editorial appointments remain available
independently. Older apps can read added appointments in existing Google calendars; editorial-only
calendars require the new app parser. Only the new app applies editorial precedence
against locally loaded event posts.

For browser-based website embedding, add the website origin to the backend
`CORS_ALLOWED_ORIGINS` environment allowlist. No CMS token belongs in the website.

The catalogue advertises `meta.maxCalendars` and `meta.maxRangeDays`. The app splits
larger selections and date windows accordingly, preserves cache/staleness metadata,
and warns if results remain incomplete. Missing entries in a truncated response
never mark saved appointments as deleted. Editorial pagination and cache memory
are bounded; the API reports `meta.truncated` if a limit prevents a complete result.
