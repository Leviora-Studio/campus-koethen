// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Typed spacing scale. Screens never use raw magic numbers for layout.
///
/// A 4 dp grid throughout, matching the supplied mobile layouts.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal margin from the screen edge to the content column.
  static const double gutter = 24;
}

/// Typed corner radii.
///
/// The system has **one** radius. Cards, buttons, inputs, chips and banners all
/// use [card], because a design where every component has its own softness is a
/// design without a shape language. Only two things are allowed to differ, and
/// both earn it:
///
/// * [sheet] — a bottom sheet is a physical object sliding over the screen, and
///   the larger radius is what makes it read as one.
/// * [pill] — the marker stroke and round avatars. A highlighter mark has no
///   corners at all.
///
/// [none] is not an absence of a decision: rules, rails and the "now" bar are
/// drawn lines, and a drawn line does not have rounded ends.
abstract final class AppRadius {
  /// Rules, rails, bar lines and other drawn ink.
  static const double none = 0;

  /// Cards and panels in the supplied design use a soft 12–14 dp rounding.
  static const double card = 14;

  /// Compact badges keep visible corners instead of becoming pills.
  static const double badge = 8;

  /// Bottom sheets and dialogs.
  static const double sheet = 24;

  /// The marker stroke and round avatars.
  static const double pill = 999;
}

/// Accessibility related dimensions and the weights of the app's ink.
abstract final class AppSizes {
  /// Minimum interactive target edge length. Required by the project rules.
  static const double minTouchTarget = 48;

  /// Hairline: separators and the outline of a card.
  static const double hairline = 1;

  /// The Taktstrich — the bar line that opens a section and runs down a time
  /// list. Two device pixels of ink, never a colour wash.
  static const double rule = 2;

  /// The heaviest stroke in the system: the marker under the selected tab and
  /// the "now" bar in the agenda. Also the accent bar of a status banner, so a
  /// state is carried by weight as well as by hue.
  static const double beam = 4;

  /// Icon size used in list rows.
  static const double icon = 24;

  /// Compact icon size used inside chips and dense controls.
  static const double iconSmall = 18;

  /// Icon size used in empty/error states.
  static const double illustrationIcon = 40;
}
