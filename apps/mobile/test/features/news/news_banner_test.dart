// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// How tall a news banner may get.
///
/// Editors upload whatever they have, and the CMS reports the real size. A feed
/// that honours every shape turns one square press photo into a full screen
/// before the headline starts, which is what these tests pin down.
library;

import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:campus_koethen/features/news/presentation/article_block.dart';
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
  testWidgets('a square photo is cropped instead of filling the screen', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 800, height: 800));

    expect(bannerRatio(tester), closeTo(16 / 9, 0.001));
  });

  testWidgets('a portrait photo is cropped just the same', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 900, height: 1600));

    expect(bannerRatio(tester), closeTo(16 / 9, 0.001));
  });

  testWidgets('a wide photo keeps its own proportions', (
    WidgetTester tester,
  ) async {
    // Nothing to protect against here: a panorama is short by itself, and
    // letterboxing it into 16:9 would crop the picture for no reason.
    await pumpCard(tester, article(width: 2100, height: 900));

    expect(bannerRatio(tester), closeTo(21 / 9, 0.001));
  });

  testWidgets('an image without a reported size falls back to the cap', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article());

    expect(bannerRatio(tester), closeTo(16 / 9, 0.001));
  });

  testWidgets('the banner keeps its alternative text', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, article(width: 800, height: 800));

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label == 'Ein Bild' &&
            widget.properties.image == true,
      ),
      findsOneWidget,
    );
  });
}
