// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/mail_account_controller.dart';
import 'mail_error_messages.dart';

Future<void> showMailAccountSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _MailAccountSettingsDialog(),
);

class _MailAccountSettingsDialog extends ConsumerStatefulWidget {
  const _MailAccountSettingsDialog();

  @override
  ConsumerState<_MailAccountSettingsDialog> createState() =>
      _MailAccountSettingsState();
}

class _MailAccountSettingsState
    extends ConsumerState<_MailAccountSettingsDialog> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(mailAccountControllerProvider).value?.displayName,
  );
  final TextEditingController _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(mailAccountControllerProvider.notifier)
          .updateSettings(
            displayName: _name.text,
            password: _password.text.isEmpty ? null : _password.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = mailFailureMessage(context.l10n, error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.mailAccountSettings),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                enabled: !_saving,
                decoration: InputDecoration(labelText: l10n.mailSetupNameLabel),
              ),
              TextField(
                controller: _password,
                enabled: !_saving,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.mailSetupPasswordLabel,
                  helperText: l10n.mailAccountPasswordHint,
                  helperMaxLines: 3,
                ),
              ),
              if (_error case final String error)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.mailCancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.mailAccountSave),
          ),
        ],
      ),
    );
  }
}
