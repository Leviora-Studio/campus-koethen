// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/contact_models.dart';
import '../data/contact_search_models.dart';
import '../data/contacts_repository.dart';

/// All active contact areas, sorted by the API's ordering.
final FutureProvider<Loaded<List<ContactArea>>> contactAreasProvider =
    FutureProvider<Loaded<List<ContactArea>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      return ref.watch(contactsRepositoryProvider).fetchAreas(locale: locale);
    });

/// The search index, loaded once and searched locally.
///
/// A `FutureProvider` rather than something the search screen owns: it is the
/// same data for every search, and re-fetching it per opened search field would
/// defeat the point of having an index endpoint.
final FutureProvider<Loaded<List<ContactSearchArea>>>
contactSearchIndexProvider = FutureProvider<Loaded<List<ContactSearchArea>>>((
  Ref ref,
) async {
  final String locale = ref.watch(localeCodeProvider);
  return ref.watch(contactsRepositoryProvider).fetchSearchIndex(locale: locale);
});

/// One contact area including its description and persons.
final contactAreaProvider = FutureProvider.family<Loaded<ContactArea>, String>((
  Ref ref,
  String slug,
) async {
  final String locale = ref.watch(localeCodeProvider);
  return ref
      .watch(contactsRepositoryProvider)
      .fetchArea(locale: locale, slug: slug);
});
