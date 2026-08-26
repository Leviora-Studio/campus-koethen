// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';
import 'status_banner.dart';

/// Discloses that at least one API field fell back to its German original.
class TranslationFallbackNotice extends StatelessWidget {
  const TranslationFallbackNotice({super.key});

  @override
  Widget build(BuildContext context) => StatusBanner(
    icon: AppIcons.translate_outlined,
    title: context.l10n.translationFallbackHint,
  );
}
