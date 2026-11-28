// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../core/network/json.dart';

class PostPoll {
  const PostPoll({
    required this.key,
    required this.question,
    required this.options,
  });

  final String key;
  final String question;
  final Map<String, String> options;

  static PostPoll? fromJson(Object? data) {
    final json = asJsonMap(data);
    final key = asString(json?['key']);
    final question = asString(json?['question']);
    if (key == null || question == null) return null;
    final options = <String, String>{};
    for (final value in asList(json?['options'])) {
      final option = asJsonMap(value);
      final optionKey = asString(option?['key']);
      final label = asString(option?['label']);
      if (optionKey == null ||
          label == null ||
          options.containsKey(optionKey)) {
        return null;
      }
      options[optionKey] = label;
    }
    if (options.length < 2 || options.length > 8) return null;
    return PostPoll(
      key: key,
      question: question,
      options: Map.unmodifiable(options),
    );
  }
}

class PostEngagement {
  const PostEngagement({
    this.reactions = const <String, int>{},
    this.votes = const <(String, String), int>{},
    this.myReaction,
    this.myVotes = const <String, String>{},
  });

  final Map<String, int> reactions;
  final Map<(String, String), int> votes;
  final String? myReaction;
  final Map<String, String> myVotes;

  static PostEngagement fromJson(Object? value) {
    final json = asJsonMap(value);
    final reactions = <String, int>{};
    final votes = <(String, String), int>{};
    final myVotes = <String, String>{};
    for (final value in asList(json?['reactions'])) {
      final row = asJsonMap(value);
      final emoji = asString(row?['emoji']);
      final count = asInt(row?['count']);
      if (emoji != null && emoji.length <= 64 && count != null && count > 0) {
        reactions[emoji] = count;
      }
    }
    for (final value in asList(json?['votes'])) {
      final row = asJsonMap(value);
      final poll = asString(row?['pollKey']);
      final option = asString(row?['optionKey']);
      final count = asInt(row?['count']);
      if (poll != null && option != null && count != null && count > 0) {
        votes[(poll, option)] = count;
      }
    }
    for (final value in asList(json?['myVotes'])) {
      final row = asJsonMap(value);
      final poll = asString(row?['pollKey']);
      final option = asString(row?['optionKey']);
      if (poll != null && option != null) myVotes[poll] = option;
    }
    return PostEngagement(
      reactions: Map.unmodifiable(reactions),
      votes: Map.unmodifiable(votes),
      myReaction: asString(json?['myReaction']),
      myVotes: Map.unmodifiable(myVotes),
    );
  }
}
