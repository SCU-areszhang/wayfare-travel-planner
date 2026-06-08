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
