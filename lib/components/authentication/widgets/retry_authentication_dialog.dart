import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/login/bluesky_login_form.dart';
import 'package:rby/rby.dart';

class RetryAuthenticationDialog extends ConsumerWidget {
  const RetryAuthenticationDialog({
    super.key,
    this.initialIdentifier,
  });

  final String? initialIdentifier;

  Future<void> _handleLogin(
    BuildContext context,
    WidgetRef ref,
    String identifier,
    String password,
  ) async {
    try {
      await ref.read(loginProvider).loginWithBluesky(
            identifier: identifier,
            password: password,
          );
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Error handling is already done in loginProvider
      if (context.mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RbyDialog(
      title: const Text('Session Expired'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your session has expired. Please sign in again to continue.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          BlueskyLoginForm(
            onLogin: (identifier, password) => _handleLogin(
              context,
              ref,
              identifier,
              password,
            ),
            initialIdentifier: initialIdentifier,
            showTitle: false,
            showAppPasswordHelp: false,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.all(24),
      actions: [
        RbyButton.text(
          label: const Text('Cancel'),
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
