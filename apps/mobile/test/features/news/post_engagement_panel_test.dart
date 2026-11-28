import 'dart:async';

import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/features/news/application/post_engagement_controller.dart';
import 'package:campus_koethen/features/news/data/post_engagement.dart';
import 'package:campus_koethen/features/news/presentation/post_engagement_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets(
    'shows counts and refreshes them after selecting an emoji or changing a vote',
    (tester) async {
      String? reaction;
      String? vote;
      final install = 'a' * 64;
      final installation = Completer<String>();
      final adapter = FakeHttpAdapter((request) {
        expect(request.headers['x-campus-installation'], install);
        if (request.method == 'PUT') {
          final data = request.data as Map<String, Object?>;
          if (request.path.endsWith('/reaction')) {
            reaction = data['emoji'] as String?;
          } else {
            expect(data['pollKey'], 'demo');
            vote = data['optionKey'] as String?;
          }
          return const FakeHttpResponse(null, statusCode: 204);
        }
        expect(request.path, '/app/post-engagement');
        expect(request.queryParameters['posts'], 'demo-post');
        return FakeHttpResponse({
          'data': {
            'demo-post': {
              'myReaction': reaction,
              'reactions': [
                if (reaction != null) {'emoji': reaction, 'count': 2},
              ],
              'myVotes': [
                if (vote != null) {'pollKey': 'demo', 'optionKey': vote},
              ],
              'votes': [
                if (vote != null)
                  {'pollKey': 'demo', 'optionKey': vote, 'count': 1},
              ],
            },
          },
        });
      });
      await pumpScreen(
        tester,
        Scaffold(
          body: PostEngagementPanel(
            slug: 'demo-post',
            poll: PostPoll.fromJson({
              'key': 'demo',
              'question': 'Demo question?',
              'options': [
                {'key': 'first', 'label': 'Demo A'},
                {'key': 'second', 'label': 'Demo B'},
              ],
            }),
          ),
        ),
        overrides: [
          postInstallationProvider.overrideWith((ref) => installation.future),
          apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
        ],
      );
      expect(find.text('Demo A'), findsOneWidget);
      expect(find.text('Demo B'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      installation.complete(install);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reagieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('👍'));
      await tester.pumpAndSettle();
      expect(find.text('👍 2'), findsOneWidget);

      await tester.tap(find.text('Demo A'));
      await tester.pumpAndSettle();
      expect(vote, 'first');
      await tester.tap(find.text('Demo B'));
      await tester.pumpAndSettle();
      expect(vote, 'second');
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    },
  );
}
