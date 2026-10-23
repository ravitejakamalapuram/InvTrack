import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:inv_tracker/features/settings/data/services/backup_crypto.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Fewest characters accepted for a new backup password.
const int kBackupPasswordMinLength = 8;

/// What the user picked in the export dialog. A null [password] means the
/// backup is exported without protection.
class BackupExportChoice {
  const BackupExportChoice({this.password});
  final String? password;
}

/// Asks whether to protect the backup with a password. Returns null when the
/// user cancels. The password only lives in this dialog's fields and in the
/// returned value; it is never logged or stored.
Future<BackupExportChoice?> showBackupExportDialog(BuildContext context) =>
    showDialog<BackupExportChoice>(
      context: context,
      builder: (_) => const _BackupExportDialog(),
    );

/// Asks for the password of an encrypted backup. [unlock] gets the typed
/// password and returns the decrypted bytes; a [BackupDecryptionException] or
/// [BackupFormatException] it throws is shown inside the dialog, which stays
/// open so the user can try again. Returns null when the user cancels.
Future<Uint8List?> showBackupUnlockDialog(
  BuildContext context, {
  required Future<Uint8List> Function(String password) unlock,
}) => showDialog<Uint8List>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _BackupUnlockDialog(unlock: unlock),
);

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 4,
        suffixIcon: IconButton(
          tooltip: obscure ? l10n.backupShowPassword : l10n.backupHidePassword,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _BackupExportDialog extends StatefulWidget {
  const _BackupExportDialog();

  @override
  State<_BackupExportDialog> createState() => _BackupExportDialogState();
}

class _BackupExportDialogState extends State<_BackupExportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _protect = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_protect) {
      Navigator.pop(context, const BackupExportChoice());
      return;
    }
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, BackupExportChoice(password: _password.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warningStyle = theme.textTheme.bodyMedium;
    return AlertDialog(
      title: Text(l10n.backupExportTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.backupProtectToggle),
                subtitle: Text(l10n.backupProtectToggleHint),
                value: _protect,
                onChanged: (v) => setState(() => _protect = v),
              ),
              const SizedBox(height: 8),
              if (_protect) ...[
                _PasswordField(
                  controller: _password,
                  label: l10n.backupPasswordLabel,
                  obscure: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').length < kBackupPasswordMinLength
                      ? l10n.backupPasswordTooShort
                      : null,
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _confirm,
                  label: l10n.backupConfirmPasswordLabel,
                  obscure: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _password.text ? l10n.backupPasswordMismatch : null,
                ),
                const SizedBox(height: 16),
                Text(l10n.backupPasswordLossWarning, style: warningStyle),
              ] else
                Text(l10n.backupUnprotectedWarning, style: warningStyle),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _submit,
          child: Text(l10n.backupExportAction),
        ),
      ],
    );
  }
}

class _BackupUnlockDialog extends StatefulWidget {
  const _BackupUnlockDialog({required this.unlock});

  final Future<Uint8List> Function(String password) unlock;

  @override
  State<_BackupUnlockDialog> createState() => _BackupUnlockDialogState();
}

class _BackupUnlockDialogState extends State<_BackupUnlockDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await widget.unlock(_password.text);
      if (mounted) Navigator.pop(context, bytes);
    } on BackupDecryptionException {
      _fail(l10n.backupWrongPassword);
    } on BackupFormatException {
      _fail(l10n.backupUnsupportedFile);
    } catch (_) {
      // Anything else (a failed isolate, out of memory) must not leave the
      // dialog stuck; the error text is not shown or logged (it can be sensitive).
      _fail(l10n.backupUnsupportedFile);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.backupUnlockTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.backupUnlockMessage),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _password,
                label: l10n.backupPasswordLabel,
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
                autofocus: true,
                enabled: !_busy,
                errorText: _error,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? Semantics(
                    label: l10n.backupUnlocking,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(l10n.backupUnlockAction),
          ),
        ],
      ),
    );
  }
}
