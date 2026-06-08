// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class SearchQueryField extends StatefulWidget {
  const SearchQueryField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
    required this.onSearch,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;

  @override
  State<SearchQueryField> createState() => _SearchQueryFieldState();
}

class _SearchQueryFieldState extends State<SearchQueryField> {
  late final String _viewType;
  html.InputElement? _input;

  @override
  void initState() {
    super.initState();
    _viewType = 'wayfare-search-input-${identityHashCode(this)}';
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
      });
      input.onKeyDown.listen((event) {
        if (event.key == 'Enter') {
          widget.onSubmitted(input.value ?? '');
        }
      });
      _syncInput();
      return input;
    });
    widget.controller.addListener(_syncInput);
  }

  @override
  void didUpdateWidget(SearchQueryField oldWidget) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInput());
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 32,
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
            IconButton(
              tooltip: 'Search',
              onPressed: widget.enabled ? widget.onSearch : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }

  void _syncInput() {
    final input = _input;
    if (input == null) {
      return;
    }
    input
      ..type = 'search'
      ..placeholder = 'Search scenic spots, cities, or attractions'
      ..autocomplete = 'off'
      ..disabled = !widget.enabled;
    if (input.value != widget.controller.text) {
      input.value = widget.controller.text;
    }

    input.style
      ..width = '100%'
      ..height = '32px'
      ..boxSizing = 'border-box'
      ..border = '0'
      ..outline = '0'
      ..padding = '0'
      ..margin = '0'
      ..background = 'transparent'
      ..font =
          '16px system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
      ..lineHeight = '32px'
      ..color = '#1b1b1f'
      ..pointerEvents = widget.enabled ? 'auto' : 'none';
  }
}
