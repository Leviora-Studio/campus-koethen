// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// The exam portal an account talks to. Hochschule Anhalt runs both in
/// parallel; a student's account lives on exactly one of them, decided once
/// during setup and persisted from then on.
enum GradePortal {
  /// The legacy HIS-QIS portal (`service.ssc.hs-anhalt.de`, flat HTML table).
  hisQisLegacy,

  /// The newer HISinOne/JSF-MyFaces portal (`sscportal.ssc.hs-anhalt.de`,
  /// hierarchical exam tree).
  hisInOne,
}
