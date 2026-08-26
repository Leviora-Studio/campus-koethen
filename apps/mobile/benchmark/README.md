# Mobile-Benchmarks

Reproduzierbare Messungen der Dart-seitigen Hot Paths der App. Sie gehören
**nicht** zum Qualitätsgate: `flutter test` ohne Argument führt nur `test/` aus,
dieses Verzeichnis wird bewusst nicht miterfasst.

```bash
cd apps/mobile
flutter test benchmark/ --reporter expanded
```

## Was hier gemessen wird — und was nicht

Gemessen wird reine Dart-Rechenzeit auf dem Main-Isolate: JSON-Parsing,
Zusammenführung des quellenübergreifenden Kalenders, Tagesindex und das
Overlap-Layout des Wochenrasters. Genau diese Arbeit läuft auf dem Gerät
zwischen zwei Frames und ist damit die Ursache von Jank, die eine Änderung im
Repository überhaupt beeinflussen kann.

**Nicht** gemessen wird alles, wofür ein echtes Gerät nötig ist: Startzeit,
Frame-Zeiten, Speicher, Energie, Bild-Dekodierung, Plattformkanäle. Für diese
Größen hält `docs/performance-baseline.md` eine dokumentierte manuelle
Messroutine bereit.

## Geltungsbereich der Zahlen

Die Werte entstehen in der Dart-VM (JIT) auf x86-64, nicht in AOT-kompiliertem
ARM-Code auf einem Telefon. Die **absoluten** Zahlen sind daher keine
Gerätewerte und dürfen nicht als solche zitiert werden. Belastbar ist der
**relative** Vergleich zweier Läufe auf derselben Maschine — und das ist es, was
eine Optimierung nachweisen muss.
