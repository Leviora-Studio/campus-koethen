// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer
//
// Anonymised HIS-QIS fixtures. NONE of these contain real names, matrikel
// numbers, examiners, exams or grades — every value is invented for testing.

/// A logged-out login page (fields `asdf` / `fdsa`). Also what QIS returns after
/// invalid credentials.
const String loginFormHtml = '''
<html><head><title>Portal</title></head><body>
  <form method="post"
        action="/qisserver/rds?state=user&type=1&category=auth.login&startpage=portal.vm">
    <input type="text" name="asdf" />
    <input type="password" name="fdsa" />
    <input type="submit" value="Anmelden" />
  </form>
</body></html>''';

/// An authenticated portal start page: a logout link and a "Prüfungsverwaltung"
/// menu link, both carrying the dynamic session `asi`.
const String portalStartHtml = '''
<html><head><title>Startseite</title></head><body>
  <ul id="menu">
    <li><a href="/qisserver/rds?state=change&type=1&moduleParameter=studyPOSMenu&asi=SID-ABC-123">Prüfungsverwaltung</a></li>
    <li><a href="/qisserver/rds?state=user&type=4&category=auth.logout&asi=SID-ABC-123">Abmelden</a></li>
  </ul>
</body></html>''';

/// The Prüfungsverwaltung page with a "Notenspiegel" link (session `asi`).
const String pruefungsverwaltungHtml = '''
<html><head><title>Prüfungsverwaltung</title></head><body>
  <ul>
    <li><a href="/qisserver/rds?state=notenspiegelStudent&next=list.vm&nextdir=qispos/notenspiegel&asi=SID-ABC-123">Notenspiegel</a></li>
    <li><a href="/qisserver/rds?state=user&type=4&category=auth.logout&asi=SID-ABC-123">Abmelden</a></li>
  </ul>
</body></html>''';

/// A valid Notenspiegel page. The table is identified by its column headers, not
/// by a class or id (there is a decoy table before it).
const String notenspiegelHtml = '''
<html><head><title>Notenspiegel</title></head><body>
  <a href="/qisserver/rds?state=user&type=4&category=auth.logout&asi=SID-ABC-123">Abmelden</a>
  <table id="decoy"><tr><th>Etwas</th><th>Anderes</th></tr><tr><td>x</td><td>y</td></tr></table>
  <table class="nb">
    <tr>
      <th>Prüfungsnummer</th><th>Prüfungstext</th><th>Note</th><th>Punkte</th>
      <th>Status</th><th>Bonus</th><th>Versuch</th><th>Prüfungsdatum</th><th>Prüfer</th>
    </tr>
    <tr>
      <td>12345</td><td>Grundlagen der Informatik</td><td>1,7</td><td>&nbsp;</td>
      <td>bestanden</td><td></td><td>1</td><td>12.02.2026</td><td>Prof. A</td>
    </tr>
    <tr>
      <td>23456</td><td>Mathematik I</td><td>2,3</td><td></td>
      <td>bestanden</td><td></td><td>2</td><td>10.02.2026</td><td>Prof. B</td>
    </tr>
    <tr>
      <td>23456</td><td>Mathematik I</td><td>4,0</td><td></td>
      <td>nicht bestanden</td><td></td><td>1</td><td>01.08.2025</td><td>Prof. B</td>
    </tr>
    <tr>
      <td>34567</td><td>Projektarbeit</td><td>0,0</td><td></td>
      <td>bestanden</td><td></td><td>1</td><td>01.03.2026</td><td>Prof. C</td>
    </tr>
    <tr>
      <td>45678</td><td>  Seminar
      </td><td></td><td></td>
      <td>bestanden</td><td>5</td><td>1</td><td>05.02.2026</td><td>Prof. D</td>
    </tr>
    <tr>
      <td>56789</td><td>Recht &amp; Wirtschaft</td><td>5,0</td><td></td>
      <td>nicht bestanden</td><td></td><td>1</td><td>20.01.2026</td><td>Prof. E</td>
    </tr>
    <tr>
      <td>67890</td><td>Datenbanken</td><td></td><td></td>
      <td>Prüfung vorhanden</td><td></td><td></td><td></td><td>Prof. F</td>
    </tr>
    <tr>
      <td>78901</td><td>Ethik</td><td></td><td></td>
      <td>angemeldet</td><td></td><td></td><td></td><td></td>
    </tr>
    <tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>
  </table>
</body></html>''';

/// An authenticated page whose table has the WRONG headers — the required
/// columns are missing, so the parser must report a structure change.
const String structureChangedHtml = '''
<html><head><title>Notenspiegel</title></head><body>
  <a href="/qisserver/rds?category=auth.logout&asi=SID-ABC-123">Abmelden</a>
  <table>
    <tr><th>Spalte A</th><th>Spalte B</th><th>Spalte C</th></tr>
    <tr><td>1</td><td>2</td><td>3</td></tr>
  </table>
</body></html>''';
