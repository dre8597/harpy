import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rby/rby.dart';
import 'package:rby/theme/spacing_scheme.dart';

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Use a regular AlertDialog as a fallback if RbyDialog fails
    try {
      return RbyDialog(
        title: const Text('really logout?'),
        contentPadding: EdgeInsets.zero,
        actions: [
          RbyButton.text(
            label: const Text('cancel'),
            onTap: Navigator.of(context).pop,
          ),
          RbyButton.elevated(
            label: const Text('logout'),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
        titlePadding: EdgeInsets.only(
          top: theme.spacingScheme.xl,
          left: theme.spacingScheme.xl,
          right: theme.spacingScheme.xl,
        ),
      );
    } catch (e) {
      // Fallback to Material AlertDialog if RbyDialog fails
      return AlertDialog(
        title: const Text('really logout?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('logout'),
          ),
        ],
      );
    }
  }
}
