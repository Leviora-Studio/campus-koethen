// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../network/campus_location.dart';
import '../theme/app_dimensions.dart';

class CampusLocationFilter extends StatelessWidget {
  const CampusLocationFilter({
    required this.locations,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Iterable<CampusLocation?> locations;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bySlug = {
      for (final location in locations) ?location?.slug: ?location,
    };
    if (bySlug.isEmpty) return const SizedBox.shrink();
    final sorted = bySlug.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.l10n.campusLocationFilter,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: bySlug.containsKey(selected) ? selected : '',
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(context.l10n.campusAllLocations),
              ),
              for (final location in sorted)
                DropdownMenuItem(
                  value: location.slug,
                  child: Text(location.name),
                ),
            ],
            onChanged: (value) => onChanged(value == '' ? null : value),
          ),
        ),
      ),
    );
  }
}
