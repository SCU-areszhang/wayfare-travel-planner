// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class LoginIdentifierField extends StatefulWidget {
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
  State<LoginIdentifierField> createState() => _LoginIdentifierFieldState();
}

class _LoginIdentifierFieldState extends State<LoginIdentifierField> {
  late final String _viewType;
  html.InputElement? _input;

  bool get _isPhone => widget.loginType == 'phone';

  @override
  void initState() {
    super.initState();
    _viewType = 'wayfare-login-input-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final input = html.InputElement();
      _input = input;
      input.onInput.listen((_) {
        final value = input.value ?? '';
        if (widget.controller.text != value) {
          widget.controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
        }
        widget.onChanged(value);
      });
      input.onKeyDown.listen((event) {
        if (event.key == 'Enter') {
          input.blur();
        }
      });
      _syncInput();
      return input;
    });
    widget.controller.addListener(_syncInput);
  }

  @override
  void didUpdateWidget(LoginIdentifierField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncInput);
      widget.controller.addListener(_syncInput);
    }
    _syncInput();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncInput);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = widget.errorText;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInput());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: widget.enabled
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: error == null ? scheme.outlineVariant : scheme.error,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _isPhone ? Icons.phone_outlined : Icons.mail_outline,
                  color: error == null ? scheme.onSurfaceVariant : scheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPhone ? 'Phone number' : 'Email',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: error == null
                                      ? scheme.onSurfaceVariant
                                      : scheme.error,
                                ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 28,
                        child: HtmlElementView(viewType: _viewType),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Text(
            error ?? 'Unknown users are registered automatically.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: error == null ? scheme.onSurfaceVariant : scheme.error,
                ),
          ),
        ),
      ],
    );
  }

  void _syncInput() {
    final input = _input;
    if (input == null) {
      return;
    }
    input
      ..type = _isPhone ? 'tel' : 'email'
      ..autocomplete = _isPhone ? 'tel' : 'email'
      ..placeholder = _isPhone ? 'Enter phone number' : 'Enter email'
      ..disabled = !widget.enabled;
    if (input.value != widget.controller.text) {
      input.value = widget.controller.text;
    }

    final style = input.style;
    style
      ..width = '100%'
      ..height = '28px'
      ..boxSizing = 'border-box'
      ..border = '0'
      ..outline = '0'
      ..padding = '0'
      ..margin = '0'
      ..background = 'transparent'
      ..font =
          '16px system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
      ..lineHeight = '28px'
      ..color = '#1b1b1f'
      ..pointerEvents = widget.enabled ? 'auto' : 'none';
  }
}
