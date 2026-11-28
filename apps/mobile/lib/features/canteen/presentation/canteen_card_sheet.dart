// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/l10n.dart';
import '../data/canteen_card_reader.dart';

Future<void> showCanteenCardSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _CanteenCardSheet(),
    );

class _CanteenCardSheet extends StatefulWidget {
  const _CanteenCardSheet();

  @override
  State<_CanteenCardSheet> createState() => _CanteenCardSheetState();
}

class _CanteenCardSheetState extends State<_CanteenCardSheet> {
  final _reader = const CanteenCardReader();
  CanteenCardBalance? _balance;
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    if (_scanning) unawaited(_reader.cancel().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final balance = await _reader.lastRead();
      if (mounted && _balance == null) setState(() => _balance = balance);
    } catch (_) {
      // An inaccessible or obsolete record does not prevent a fresh read.
    }
  }

  Future<void> _scan() async {
    final instructions = context.l10n.canteenCardInstructions;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final balance = await _reader.scan(instructions);
      if (mounted) setState(() => _balance = balance);
    } on PlatformException catch (error) {
      if (mounted && error.code != 'cancelled') {
        setState(() => _error = error.code);
      }
    } on MissingPluginException {
      if (mounted) setState(() => _error = 'unavailable');
    } catch (_) {
      if (mounted) setState(() => _error = 'readFailed');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _formatBalance(int cents, String locale) {
    final absolute = cents.abs();
    final amount =
        '${cents.isNegative ? '-' : ''}${absolute ~/ 100}.'
        '${(absolute % 100).toString().padLeft(2, '0')}';
    return MoneyFormatter.format(
      amount: amount,
      currencyCode: 'EUR',
      locale: locale,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final balance = _balance;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.canteenCardTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.canteenCardInstructions),
            if (balance != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _formatBalance(balance.cents, locale),
                style: theme.textTheme.headlineMedium,
              ),
              Text(
                l10n.canteenCardLastRead(
                  AppDateFormats.dateTime(balance.readAt, locale),
                ),
              ),
            ],
            if (_error case final String error) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(switch (error) {
                'unavailable' => l10n.canteenCardUnavailable,
                'disabled' => l10n.canteenCardDisabled,
                'timeout' => l10n.canteenCardTimeout,
                _ => l10n.canteenCardFailed,
              }, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (_scanning)
              OutlinedButton(
                onPressed: () => _reader.cancel(),
                child: Text(l10n.canteenCardCancel),
              )
            else
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(AppIcons.contactless_outlined),
                label: Text(l10n.canteenCardScan),
              ),
          ],
        ),
      ),
    );
  }
}
