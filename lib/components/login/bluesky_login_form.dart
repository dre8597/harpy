import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rby/rby.dart';

class BlueskyLoginForm extends ConsumerStatefulWidget {
  const BlueskyLoginForm({
    super.key,
    required this.onLogin,
    this.initialIdentifier,
  });

  final Future<void> Function(String identifier, String password) onLogin;
  final String? initialIdentifier;

  @override
  ConsumerState<BlueskyLoginForm> createState() => _BlueskyLoginFormState();
}

class _BlueskyLoginFormState extends ConsumerState<BlueskyLoginForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _identifierController =
        TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        await widget.onLogin(
          _identifierController.text.trim(),
          _passwordController.text,
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
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
            enabled: widget.initialIdentifier == null && !_isLoading,
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
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'App Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
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
            label: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Login'),
            onTap: _isLoading ? null : _handleSubmit,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
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
