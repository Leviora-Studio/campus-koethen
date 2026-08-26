// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/widgets.dart';

/// Content of a modal bottom sheet, always as wide as the sheet allows.
///
/// A Material 3 bottom sheet is capped at a maximum width and centred, which
/// means its content is laid out with LOOSE width constraints. Content that
/// sizes itself to its children — a `Column` with `MainAxisSize.min`, the usual
/// shape for these sheets — therefore shrink-wraps, and a sheet whose fields
/// are largely unmaintained collapses into a narrow card floating in the
/// middle of the screen. A contact person with nothing but a short name looked
/// exactly like that.
///
/// Filling the offered width keeps every sheet the same shape, no matter how
/// much the editorial team has actually maintained.
class SheetBody extends StatelessWidget {
  const SheetBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: double.infinity, child: child);
}
