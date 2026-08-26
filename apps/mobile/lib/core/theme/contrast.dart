// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.1 contrast helpers.
///
/// Kept in `lib/` (not in `test/`) on purpose: the values that the automated
/// contrast test asserts must be computed by exactly the same code that the
/// app itself could use for a runtime assertion.
abstract final class Contrast {
  /// WCAG AA threshold for body text.
  static const double aaBody = 4.5;

  /// WCAG AA threshold for large text (>= 18pt regular / >= 14pt bold) and for
  /// graphical objects and UI component boundaries.
  static const double aaLarge = 3.0;

  /// Relative luminance per WCAG 2.1, ignoring alpha.
  static double relativeLuminance(Color color) {
    double channel(double value) {
      return value <= 0.03928
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    final double r = channel(color.r);
    final double g = channel(color.g);
    final double b = channel(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Contrast ratio between two opaque colours, in the range 1.0 … 21.0.
  static double ratio(Color foreground, Color background) {
    final double a = relativeLuminance(foreground);
    final double b = relativeLuminance(background);
    final double lighter = math.max(a, b);
    final double darker = math.min(a, b);
    return (lighter + 0.05) / (darker + 0.05);
  }
}
