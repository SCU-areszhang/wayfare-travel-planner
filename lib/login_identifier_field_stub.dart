import 'package:flutter/material.dart';

class LoginIdentifierField extends StatelessWidget {
  const LoginIdentifierField({
    required this.controller,
    required this.loginType,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String loginType;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPhone = loginType == 'phone';
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: isPhone
          ? const [AutofillHints.telephoneNumber]
          : const [AutofillHints.email],
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(isPhone ? Icons.phone_outlined : Icons.mail_outline),
        labelText: isPhone ? 'Phone number' : 'Email',
        helperText: 'Unknown users are registered automatically.',
        errorText: errorText,
      ),
    );
  }
}

class PasswordField extends StatelessWidget {
  const PasswordField({
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    required this.obscurePassword,
    required this.onToggleObscure,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline),
        labelText: 'Password',
        helperText: 'New accounts set this password on first sign in',
        errorText: errorText,
        suffixIcon: IconButton(
          tooltip: obscurePassword ? 'Show' : 'Hide',
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: enabled ? onToggleObscure : null,
        ),
      ),
    );
  }
}
