// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// What the operating system currently says about showing notifications.
///
/// Four states, because the settings screen has to tell them apart (UX spec
/// § 3.2 and § 7). Conflating "never asked" with "said no" is what produces
/// the two classic failures: an app that prompts without first explaining the
/// benefit, and an app whose only remaining route — the system settings — is
/// never offered.
enum NotificationPermissionStatus {
  /// Nobody has been asked yet. The system dialog has never been shown, and
  /// showing it is still possible exactly once.
  notDetermined,

  /// Notifications may be delivered.
  granted,

  /// Refused, or switched off in the system settings afterwards. On iOS the
  /// system dialog is shown only once ever, so from here the only way on is
  /// the system settings — the app must never ask again (ADR-0001 § 9.8).
  denied,

  /// A platform without a runtime permission for this — Android below 13,
  /// where the permission counts as granted — or one whose answer could not
  /// be read. Treated as granted for delivery, and shown without a banner.
  notApplicable;

  /// Whether the operating system would currently deliver what is scheduled.
  bool get allowsDelivery =>
      this == NotificationPermissionStatus.granted ||
      this == NotificationPermissionStatus.notApplicable;

  /// Whether asking the operating system is still possible and sensible.
  bool get canPrompt => this == NotificationPermissionStatus.notDetermined;

  /// Whether the settings screen has to offer the way to the system settings.
  bool get needsSystemSettings => this == NotificationPermissionStatus.denied;
}
