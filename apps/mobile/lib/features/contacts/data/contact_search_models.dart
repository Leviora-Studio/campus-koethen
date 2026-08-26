// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/network/json.dart';

/// The search index delivered by `GET /v1/contact-areas/search-index`.
///
/// A separate model from [ContactArea] on purpose: the index carries exactly
/// the visible fields a search can match and nothing else — no profile image,
/// no sort order, and the long description already flattened to plain text.
/// Reusing the detail model would invite searching over fields the endpoint
/// deliberately does not deliver.

/// A room as the index knows it. The same fields the map deep-link needs.
class SearchRoom {
  const SearchRoom({
    required this.roomKey,
    required this.roomNumber,
    this.buildingNumber = '',
    required this.buildingName,
    required this.floorName,
    this.displayName,
  });

  final String roomKey;
  final String roomNumber;
  final String buildingNumber;
  final String buildingName;
  final String floorName;
  final String? displayName;

  static SearchRoom? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? roomKey = asString(map['roomKey']);
    if (roomKey == null) return null;
    return SearchRoom(
      roomKey: roomKey,
      roomNumber: asString(map['roomNumber']) ?? roomKey,
      buildingNumber: asString(map['buildingNumber']) ?? '',
      buildingName: asString(map['buildingName']) ?? '',
      floorName: asString(map['floorName']) ?? '',
      displayName: asString(map['displayName']),
    );
  }

  static List<SearchRoom> listFromJson(Object? json) => asList(
    json,
  ).map(SearchRoom.fromJson).whereType<SearchRoom>().toList(growable: false);
}

class ContactSearchPerson {
  const ContactSearchPerson({
    required this.name,
    this.role,
    this.description,
    this.email,
    this.phone,
    this.website,
    this.rooms = const <SearchRoom>[],
  });

  final String name;
  final String? role;
  final String? description;
  final String? email;
  final String? phone;
  final String? website;
  final List<SearchRoom> rooms;

  static ContactSearchPerson? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? name = asString(map['name']);
    if (name == null) return null;
    final String? website = asString(map['website']);
    return ContactSearchPerson(
      name: name,
      role: asString(map['role']),
      description: asString(map['description']),
      email: asString(map['email']),
      phone: asString(map['phone']),
      website: SafeLinkLauncher.isAllowed(website) ? website : null,
      rooms: SearchRoom.listFromJson(map['rooms']),
    );
  }
}

class ContactSearchArea {
  const ContactSearchArea({
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.descriptionText,
    this.iconKey,
    this.generalEmail,
    this.phone,
    this.website,
    this.appointmentBookingUrl,
    this.address,
    this.openingHours,
    this.rooms = const <SearchRoom>[],
    this.persons = const <ContactSearchPerson>[],
  });

  final String slug;
  final String name;
  final String shortDescription;

  /// The long description as plain text — the API flattened it, because a
  /// search matches words rather than formatting.
  final String descriptionText;

  final String? iconKey;
  final String? generalEmail;
  final String? phone;
  final String? website;
  final String? appointmentBookingUrl;
  final String? address;
  final String? openingHours;
  final List<SearchRoom> rooms;
  final List<ContactSearchPerson> persons;

  static ContactSearchArea? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? slug = asString(map['slug']);
    if (slug == null) return null;
    final String? website = asString(map['website']);
    final String? appointmentBookingUrl = asString(
      map['appointmentBookingUrl'],
    );
    return ContactSearchArea(
      slug: slug,
      name: asString(map['name']) ?? slug,
      shortDescription: asString(map['shortDescription']) ?? '',
      descriptionText: asString(map['descriptionText']) ?? '',
      iconKey: asString(map['iconKey']),
      generalEmail: asString(map['generalEmail']),
      phone: asString(map['phone']),
      website: SafeLinkLauncher.isAllowed(website) ? website : null,
      appointmentBookingUrl: SafeLinkLauncher.isAllowed(appointmentBookingUrl)
          ? appointmentBookingUrl
          : null,
      address: asString(map['address']),
      openingHours: asString(map['openingHours']),
      rooms: SearchRoom.listFromJson(map['rooms']),
      persons: asList(map['persons'])
          .map(ContactSearchPerson.fromJson)
          .whereType<ContactSearchPerson>()
          .toList(growable: false),
    );
  }

  static List<ContactSearchArea> listFromJson(Object? json) => asList(json)
      .map(ContactSearchArea.fromJson)
      .whereType<ContactSearchArea>()
      .toList(growable: false);
}
