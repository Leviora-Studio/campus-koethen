// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Post images use a square preview and open the original media file in-app.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_koethen/core/network/api_config.dart';
import 'package:campus_koethen/core/theme/app_icons.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:campus_koethen/features/news/presentation/article_block.dart';
import 'package:campus_koethen/features/news/presentation/post_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/news_harness.dart';
import '../../support/pump_app.dart';

NewsArticle article({int? width, int? height}) =>
    NewsArticle.fromJson(<String, dynamic>{
      'slug': 'a',
      'title': 'Meldung',
      'publishedAt': '2026-08-04T09:00:00.000Z',
      'heroImage': <String, dynamic>{
        'url': '/v1/media/uploads/banner.jpg',
        'alternativeText': 'Ein Bild',
        'width': width,
        'height': height,
      },
      'channels': <Object>[],
      'tag': <String, dynamic>{'slug': 'news', 'name': 'News'},
      'primaryChannel': <String, dynamic>{
        'slug': 'campus-news',
        'name': 'Campus News',
      },
      'content': <Object>[],
    })!;

/// The ratio the banner is actually drawn at.
double bannerRatio(WidgetTester tester) =>
    tester.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio;

Future<void> pumpCard(WidgetTester tester, NewsArticle value) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(child: ArticleBlock(article: value)),
    ),
    // The feed's clock ticks every minute; without freezing it the card leaves
    // a timer behind and every test here fails for a reason that is not the
    // banner.
    overrides: <Override>[frozenNewsClock()],
  );
  await tester.pump();
}

void main() {
  testWidgets('a square photo stays square in the preview', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 800, height: 800));

    expect(bannerRatio(tester), 1);
  });

  testWidgets('a portrait photo has a square preview', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 900, height: 1600));

    expect(bannerRatio(tester), 1);
  });

  testWidgets('a wide photo also has a square preview', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 2100, height: 900));

    expect(bannerRatio(tester), 1);
    final Rect preview = tester.getRect(find.byType(PostImagePreview));
    final Rect icon = tester.getRect(find.byIcon(AppIcons.fullscreen));
    expect(preview.width, closeTo(preview.height, 0.01));
    expect(icon.center.dx, greaterThan(preview.center.dx));
    expect(icon.center.dy, greaterThan(preview.center.dy));
  });

  testWidgets('an image without a reported size is square too', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article());

    expect(bannerRatio(tester), 1);
  });

  testWidgets('the preview announces its action and alternative text', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 800, height: 800));

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label?.contains('Ein Bild') == true &&
            widget.properties.button == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the preview opens original resolution and closes both ways', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 1600, height: 900));

    await tester.tap(find.byTooltip('Bild im Vollbild öffnen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Bildansicht schließen'), findsOneWidget);
    final List<CachedNetworkImage> images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .toList();
    expect(images, hasLength(2));
    expect(
      images.last.imageUrl,
      ApiConfig.resolveMediaUrl('/v1/media/uploads/banner.jpg'),
    );
    expect(images.last.memCacheWidth, isNull);
    expect(images.last.memCacheHeight, isNull);

    await tester.tap(find.byTooltip('Bildansicht schließen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Bildansicht schließen'), findsNothing);

    await tester.tap(find.byTooltip('Bild im Vollbild öffnen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Bildansicht schließen'), findsOneWidget);

    await tester.tapAt(const Offset(10, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Bildansicht schließen'), findsNothing);
  });

  group('full view zoom', () {
    Future<void> openFullView(WidgetTester tester) async {
      await pumpCard(tester, article(width: 1600, height: 900));
      await tester.tap(find.byTooltip('Bild im Vollbild öffnen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The full view's loading spinner never stops in tests, so pumpAndSettle
    // would time out; this lets the gesture's own animations finish instead.
    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Matrix4 transform(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;

    Offset imageCenter(WidgetTester tester) =>
        tester.getCenter(find.byType(CachedNetworkImage).last);

    testWidgets('pinching zooms in and dragging then pans the image', (
      WidgetTester tester,
    ) async {
      await openFullView(tester);
      expect(transform(tester).getMaxScaleOnAxis(), 1);

      final Offset center = imageCenter(tester);
      final TestGesture first = await tester.startGesture(
        center - const Offset(20, 0),
      );
      final TestGesture second = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await tester.pump();
      for (int step = 1; step <= 8; step++) {
        await first.moveTo(center - Offset(20.0 + step * 10, 0));
        await second.moveTo(center + Offset(20.0 + step * 10, 0));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await settle(tester);

      final Matrix4 zoomed = transform(tester);
      expect(zoomed.getMaxScaleOnAxis(), greaterThan(1.5));

      await tester.timedDragFrom(
        center,
        const Offset(60, 40),
        const Duration(milliseconds: 300),
      );
      await settle(tester);

      expect(
        transform(tester).getTranslation(),
        isNot(equals(zoomed.getTranslation())),
      );
      expect(
        find.byTooltip('Bildansicht schließen'),
        findsOneWidget,
        reason: 'zooming and panning keep the full view open',
      );
    });

    testWidgets('double-tapping zooms in and double-tapping again resets', (
      WidgetTester tester,
    ) async {
      await openFullView(tester);

      final Offset center = imageCenter(tester);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await settle(tester);

      expect(transform(tester).getMaxScaleOnAxis(), greaterThan(1.5));
      expect(find.byTooltip('Bildansicht schließen'), findsOneWidget);

      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await settle(tester);

      expect(transform(tester).getMaxScaleOnAxis(), 1);
    });
  });
}
