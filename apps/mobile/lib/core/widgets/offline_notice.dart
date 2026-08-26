// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../l10n/l10n.dart';
import '../locale/formatters.dart';
import 'status_banner.dart';

/// Marks content that was served from the offline cache.
///
/// Cached content is *always* labelled — the user must never be left guessing
/// whether they are looking at live or stored data.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({this.cachedAt, super.key});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    return StatusBanner(
      icon: AppIcons.cloud_off_outlined,
      title: l10n.offlineCachedTitle,
      message: cachedAt == null
          ? l10n.offlineCachedUnknownTime
          : l10n.offlineCachedAt(AppDateFormats.dateTime(cachedAt!, locale)),
    );
  }
}
