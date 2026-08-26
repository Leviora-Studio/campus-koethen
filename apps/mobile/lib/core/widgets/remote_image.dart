// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../network/api_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Displays an editorial image the Campus API published.
///
/// [url] is whatever the API delivered — normally an API-relative media path
/// (`/v1/media/…`). Resolving it happens **here** rather than at every call
/// site, so no screen can forget it and none of them has to know where the
/// images live.
///
/// A failing image is *not* an error state: it collapses to nothing so a
/// broken asset can never block an article. There are deliberately no canteen
/// images anywhere in this app.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    required this.url,
    this.alternativeText,
    this.aspectRatio,
    super.key,
  });

  final String url;
  final String? alternativeText;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String? resolved = ApiConfig.resolveMediaUrl(url);
    // An unusable reference is nothing to apologise for — the layout simply
    // does without the picture.
    if (resolved == null) return const SizedBox.shrink();

    // Only the pixel ratio, not the whole `MediaQueryData`: with
    // `MediaQuery.of` every image on screen rebuilt whenever anything else
    // about the media query changed — the text scale, the safe areas, the
    // orientation — although the ratio it actually reads practically never
    // changes.
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    Widget buildImage(BoxConstraints constraints) {
      // Decode at the size the image is actually painted at, not at its
      // native resolution — a card-sized image doesn't need a full-res
      // decode held in the image cache.
      final int? cacheWidth = constraints.maxWidth.isFinite
          ? (constraints.maxWidth * devicePixelRatio).round()
          : null;
      final int? cacheHeight =
          aspectRatio != null && constraints.maxWidth.isFinite
          ? (constraints.maxWidth / aspectRatio! * devicePixelRatio).round()
          : null;

      final Widget picture = CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.cover,
        width: double.infinity,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        errorWidget: (BuildContext _, String _, Object _) =>
            const SizedBox.shrink(),
        placeholder: (BuildContext _, String _) => ColoredBox(
          color: colors.surfaceVariant,
          child: const SizedBox(height: AppSpacing.xxxl),
        ),
      );

      // Without an alternative text there is nothing to announce, and an
      // unlabelled image node only makes a screen reader read out "image"
      // once per picture. Treat it as decoration instead — which is what a
      // CMS image that never got an alt text effectively is.
      final String? alt = alternativeText;
      if (alt == null || alt.isEmpty) {
        return ExcludeSemantics(child: picture);
      }
      return Semantics(image: true, label: alt, child: picture);
    }

    final Widget image = LayoutBuilder(
      builder: (BuildContext _, BoxConstraints constraints) =>
          buildImage(constraints),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: aspectRatio == null
          ? image
          : AspectRatio(aspectRatio: aspectRatio!, child: image),
    );
  }
}
