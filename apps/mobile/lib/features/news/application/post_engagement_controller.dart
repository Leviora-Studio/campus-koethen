// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/security/app_secure_storage.dart';
import '../data/post_engagement.dart';

final postInstallationProvider = FutureProvider<String>((ref) async {
  const key = 'news.engagement.installation.v1';
  final storage = appSecureStorage();
  final existing = await storage.read(key: key);
  if (existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) {
    return existing;
  }
  final random = Random.secure();
  final token = List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await storage.write(key: key, value: token);
  return token;
}, retry: (_, _) => null);

final postEngagementProvider =
    NotifierProvider<PostEngagementController, Map<String, PostEngagement>>(
      PostEngagementController.new,
    );

/// One refresh loop batches the posts currently mounted in a feed.
class PostEngagementController extends Notifier<Map<String, PostEngagement>> {
  static const _path = '/app/post-engagement';
  final _posts = <String, int>{};
  final _writing = <String>{};
  Timer? _poll;
  Timer? _scheduled;
  CancelToken? _activeRead;
  bool _reading = false;
  bool _pendingRefresh = false;

  @override
  Map<String, PostEngagement> build() {
    ref.onDispose(() {
      _poll?.cancel();
      _scheduled?.cancel();
      _activeRead?.cancel();
    });
    return const {};
  }

  void attach(String slug) {
    _posts.update(slug, (count) => count + 1, ifAbsent: () => 1);
    _poll ??= Timer.periodic(const Duration(seconds: 5), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _schedule();
      }
    });
    _schedule();
  }

  void detach(String slug) {
    final count = _posts[slug];
    if (count == null) return;
    if (count == 1) {
      _posts.remove(slug);
    } else {
      _posts[slug] = count - 1;
    }
    if (_posts.isEmpty) {
      _poll?.cancel();
      _scheduled?.cancel();
      _activeRead?.cancel();
      _poll = null;
      _scheduled = null;
      _pendingRefresh = false;
    }
  }

  void _schedule() {
    _scheduled ??= Timer(Duration.zero, () {
      _scheduled = null;
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_reading) {
      _pendingRefresh = true;
      return;
    }
    _reading = true;
    final cancel = _activeRead = CancelToken();
    try {
      final current = _posts.keys.toList(growable: false);
      final next = <String, PostEngagement>{};
      for (final slug in current) {
        final snapshot = state[slug];
        if (snapshot != null) next[slug] = snapshot;
      }
      if (current.isNotEmpty) {
        final installation = await ref.read(postInstallationProvider.future);
        if (cancel.isCancelled || !ref.mounted) return;
        final dio = ref.read(apiClientProvider).dio;
        for (int offset = 0; offset < current.length; offset += 50) {
          final batch = current.skip(offset).take(50);
          try {
            final response = await dio.get<Object?>(
              _path,
              queryParameters: {'posts': batch.join(',')},
              cancelToken: cancel,
              options: _options(installation),
            );
            final data = asJsonMap(asJsonMap(response.data)?['data']);
            for (final slug in batch) {
              if (data?[slug] case final Map value) {
                next[slug] = PostEngagement.fromJson(value);
              }
            }
          } on DioException {
            if (cancel.isCancelled) return;
            // A transient network error keeps the last known results.
          }
        }
      }
      if (ref.mounted) {
        next.removeWhere((slug, _) => !_posts.containsKey(slug));
        if (!mapEquals(next, state)) state = Map.unmodifiable(next);
      }
    } catch (_) {
      // Secure storage may be unavailable while the device is locked.
    } finally {
      _reading = false;
      _activeRead = null;
      if (_pendingRefresh && ref.mounted && _posts.isNotEmpty) {
        _pendingRefresh = false;
        _schedule();
      }
    }
  }

  Future<void> react(String slug, String? emoji) =>
      _write(slug, 'reaction', {'emoji': emoji});

  Future<void> vote(String slug, String pollKey, String optionKey) =>
      _write(slug, 'vote', {'pollKey': pollKey, 'optionKey': optionKey});

  Future<void> _write(
    String slug,
    String action,
    Map<String, Object?> data,
  ) async {
    if (!_writing.add(slug)) return;
    try {
      final installation = await ref.read(postInstallationProvider.future);
      await ref
          .read(apiClientProvider)
          .dio
          .put<void>(
            '$_path/${Uri.encodeComponent(slug)}/$action',
            data: data,
            options: _options(installation),
          );
      if (ref.mounted) await _refresh();
    } finally {
      _writing.remove(slug);
    }
  }

  Options _options(String installation) => Options(
    followRedirects: false,
    headers: {'x-campus-installation': installation},
  );
}
