import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

class BlueskyLoginForm extends ConsumerStatefulWidget {
  const BlueskyLoginForm({
    super.key,
    required this.onLogin,
  });

  final void Function(String identifier, String password) onLogin;

  @override
  ConsumerState<BlueskyLoginForm> createState() => _BlueskyLoginFormState();
}

class _BlueskyLoginFormState extends ConsumerState<BlueskyLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onLogin(
        _identifierController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _identifierController,
            decoration: const InputDecoration(
              labelText: 'Handle or Email',
              hintText: 'e.g. username.bsky.social',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your handle or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'App Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSubmit(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your app password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          RbyButton.elevated(
            label: const Text('Login'),
            onTap: _handleSubmit,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // TODO: Add link to Bluesky app password creation guide
              // launcher.call('https://bsky.app/settings/app-passwords');
            },
            child: Text(
              'Need an app password?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
