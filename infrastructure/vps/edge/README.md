## Was hier steht und warum

Die Campus API ist **öffentlich und unauthentifiziert**. Ihre Eingabegrenzen
sind eng gezogen — `pageSize` maximal 50, höchstens 25 Filterwerte, begrenzte
Datumsbereiche, gedeckelte Ergebnismengen —, aber die _Kosten pro Anfrage_
bleiben unbegrenzt oft abrufbar. Zwei Pfade sind dabei die teuersten:

- `GET /v1/media/uploads/:filename` — bis 12 MB pro Anfrage, die der
  API-Prozess aus Strapi holt und weiterreicht.
- `GET /v1/calendars/events` — bis 2000 Termine über bis zu 50 Kalender.

Ein Rate Limit im Node-Prozess würde erst greifen, nachdem die Anfrage ihn
bereits beschäftigt. An der Kante ist es billiger. Die Kante — Nginx auf dem
Host, TLS-Terminierung außerhalb von Docker — lag bisher **nicht** im
Repository: es gab keinen versionierten Vertrag darüber, welche Pfade nach außen
dürfen, wie groß ein Request-Body sein darf, welche Timeouts gelten und ob
überhaupt gedrosselt wird.

Diese Datei ist dieser Vertrag. `campus-api.conf` ist eine **Referenz**, kein
ausgerolltes Artefakt: das Deployment ist ausdrücklich manuell
(`../README.md`), und aus diesem Repository heraus wird nichts deployed. Wer die
Kante ändert, ändert sie hier mit — sonst driftet der Betrieb wieder
unbeobachtet vom dokumentierten Stand weg.

## Verbindliche Zusagen

| Zusage                 | Wert                                             | Warum                                                                                               |
| ---------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Erreichbare Pfade      | `/v1/`, `/health/live`, `/health/ready`, `/docs` | Default-Deny. Alles andere ist von außen nicht erreichbar. `/docs` ist bewusst offen (siehe unten). |
| Rate Limit (allgemein) | 10 req/s pro IP, Burst 20                        | Deutlich über realer App-Nutzung, weit unter dem, was eine Schleife erzeugt.                        |
| Rate Limit (Medien)    | 2 req/s pro IP, Burst 10                         | Der teuerste Pfad: bis 12 MB je Anfrage durch den API-Prozess.                                      |
| Rate Limit (`/docs`)   | 5 req/s pro IP, Burst 15                         | HTML plus Assets, von einem Menschen gelesen — kein Pfad, den eine App pollt.                       |
| Gleichzeitige Verb.    | 20 pro IP                                        | Begrenzt Slow-Read-Verhalten, das ein reines Ratenlimit nicht sieht.                                |
| `client_max_body_size` | 1 KB                                             | Die API ist **read-only**; es gibt keinen Endpunkt, der einen Body entgegennimmt.                   |
| Upstream-Timeouts      | 10 s connect, 30 s read/send                     | Über dem Strapi-Timeout der API (10 s) plus Retries, unter einer hängenden Verbindung.              |
| Erlaubte Methoden      | `GET`, `HEAD`, `OPTIONS`                         | Die API kennt keine anderen. Ein 405 an der Kante ist billiger als einer im Node-Prozess.           |

`/docs` (Swagger UI) und `/docs-json` sind **bewusst öffentlich** — Entscheidung
Erik, LEVIORA-180: die API ist ein öffentlicher, read-only Vertrag, die Seite,
die ihn dokumentiert, gehört damit ebenfalls in die Öffentlichkeit. Zwei Dinge
müssen dafür zusammenpassen: `DOCS_ENABLED=true` im Backend (sonst existiert der
Pfad gar nicht) **und** die Freigabe an der Kante. Der Präfix-Match ist nötig,
weil Swagger UI Bundle und Stylesheet unterhalb von `/docs/` nachlädt.

Das CMS (`:3020`) gehört **nicht** hinter dieselbe öffentliche Route. Es ist
ein Admin-Panel; es gehört hinter eine getrennte, zugriffsbeschränkte Adresse
oder gar nicht ins öffentliche Netz.

## Was hier bewusst NICHT steht

- **Keine TLS-/Zertifikatskonfiguration.** Die gehört zur Hostinstallation, ist
  je Umgebung anders und enthält Pfade zu Schlüsseln.
- **Keine Servernamen und keine Domains.** Die sind ein offenes Release-Gate
  (AGENTS.md §10) und werden hier nicht erfunden.
- **Kein Deployment.** Kein SSH, kein Automatismus, kein Server-Secret im
  Repository (AGENTS.md §3).

## Prüfen

```bash
# Syntax gegen die eingesetzte Nginx-Version, ohne etwas zu laden:
nginx -t -c /etc/nginx/nginx.conf

# Greift das Limit wirklich? 30 schnelle Anfragen; erwartet werden 429er:
for i in $(seq 1 30); do curl -s -o /dev/null -w '%{http_code} ' "https://<host>/v1/canteens"; done; echo
```

Bleibt der zweite Befehl durchgehend bei `200`, ist die Konfiguration **nicht**
aktiv — dann ist die Zusage oben nicht eingelöst, egal was in dieser Datei
steht.
