// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../l10n/l10n.dart';
import '../data/news_models.dart';

/// Square post preview. The full view fetches the same original media URL
/// without the preview's reduced in-memory decode size.
class PostImagePreview extends StatelessWidget {
  const PostImagePreview({required this.image, super.key});

  final NewsImage image;

  @override
  Widget build(BuildContext context) {
    final String? url = ApiConfig.resolveMediaUrl(image.url);
    if (url == null) return const SizedBox.shrink();

    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final String? description = image.alternativeText;
    final String semanticLabel = description == null || description.isEmpty
        ? l10n.newsOpenImage
        : l10n.newsOpenImageWithDescription(description);

    return Tooltip(
      message: l10n.newsOpenImage,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: Stack(
          children: <Widget>[
            RemoteImage(
              url: image.url,
              alternativeText: description,
              aspectRatio: 1,
            ),
            PositionedDirectional(
              end: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: SizedBox.square(
                  dimension: AppSizes.minTouchTarget,
                  child: Icon(
                    AppIcons.fullscreen,
                    color: colors.onPrimary,
                    size: AppSizes.icon,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => _showOriginalImage(
                    context,
                    url,
                    l10n,
                    alternativeText: description,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOriginalImage(
  BuildContext context,
  String url,
  AppLocalizations l10n, {
  String? alternativeText,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.newsCloseImage,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.92),
    pageBuilder: (BuildContext dialogContext, _, _) => Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: _ZoomableImage(
                url: url,
                l10n: l10n,
                alternativeText: alternativeText,
                onDismiss: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            PositionedDirectional(
              top: AppSpacing.md,
              end: AppSpacing.md,
              child: IconButton.filled(
                tooltip: l10n.newsCloseImage,
                constraints: const BoxConstraints(
                  minWidth: AppSizes.minTouchTarget,
                  minHeight: AppSizes.minTouchTarget,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(AppIcons.close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The original image, zoomable with a pinch or a double tap and movable once
/// zoomed. The backdrop zooms along with it, so a tap beside the image still
/// closes the view at any zoom level.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.url,
    required this.l10n,
    required this.alternativeText,
    required this.onDismiss,
  });

  final String url;
  final AppLocalizations l10n;
  final String? alternativeText;
  final VoidCallback onDismiss;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  static const double _maxScale = 5;
  static const double _doubleTapScale = 2.5;

  final TransformationController _controller = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _doubleTapPosition = _controller.toScene(
      box.globalToLocal(details.globalPosition),
    );
  }

  /// Zooms in around the tapped spot, or back out to the whole image.
  void _onDoubleTap() {
    if (_controller.value.getMaxScaleOnAxis() > 1) {
      _controller.value = Matrix4.identity();
      return;
    }
    const double scale = _doubleTapScale;
    final Offset focus = _doubleTapPosition;
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        -focus.dx * (scale - 1),
        -focus.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppLocalizations l10n = widget.l10n;
    final String? alternativeText = widget.alternativeText;

    return InteractiveViewer(
      transformationController: _controller,
      maxScale: _maxScale,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: _onDoubleTap,
                child: CachedNetworkImage(
                  imageUrl: widget.url,
                  imageBuilder: (BuildContext _, ImageProvider provider) =>
                      Image(
                        image: provider,
                        fit: BoxFit.contain,
                        semanticLabel: alternativeText,
                        excludeFromSemantics:
                            alternativeText == null || alternativeText.isEmpty,
                      ),
                  placeholder: (BuildContext _, String _) =>
                      CircularProgressIndicator(color: colors.surface),
                  errorWidget: (BuildContext _, String _, Object _) => Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            AppIcons.broken_image_outlined,
                            color: colors.onSurface,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.newsImageUnavailable,
                            style: TextStyle(color: colors.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
