import 'package:flutter/material.dart';

import 'main.dart' show ThemeSource;

class AppearanceControl extends StatelessWidget {
  const AppearanceControl({
    required this.themeSource,
    required this.onThemeChanged,
    super.key,
  });

  final ThemeSource themeSource;
  final ValueChanged<ThemeSource> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final followSystem = themeSource == ThemeSource.system;
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Follow system colors'),
      subtitle: Text(
        followSystem
            ? 'Using your system dynamic color'
            : 'Custom accent color',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (context) => ColorPickerDialog(
            themeSource: themeSource,
            onThemeChanged: onThemeChanged,
          ),
        );
      },
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    required this.themeSource,
    required this.onThemeChanged,
    super.key,
  });

  final ThemeSource themeSource;
  final ValueChanged<ThemeSource> onThemeChanged;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late bool _followSystem;
  late double _r;
  late double _g;
  late double _b;
  final _hexController = TextEditingController();

  bool get _isCustomColor => !_followSystem;

  @override
  void initState() {
    super.initState();
    _followSystem = widget.themeSource == ThemeSource.system;
    final seed = widget.themeSource.seed;
    _r = seed.r * 255;
    _g = seed.g * 255;
    _b = seed.b * 255;
    _updateHexFromRgb();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor =>
      Color.fromRGBO(_r.round(), _g.round(), _b.round(), 1);

  void _updateHexFromRgb() {
    final color = _currentColor;
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toLowerCase()}';
    _hexController.text = hex;
  }

  void _updateRgbFromHex() {
    final text = _hexController.text.trim();
    final hex = text.startsWith('#') ? text.substring(1) : text;
    if (hex.length != 6) return;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return;
    final color = Color(0xFF000000 | value);
    setState(() {
      _r = color.r * 255;
      _g = color.g * 255;
      _b = color.b * 255;
    });
  }

  ThemeSource? _findClosestSource(Color color) {
    ThemeSource? best;
    var bestDist = double.infinity;
    for (final source in ThemeSource.values) {
      if (source == ThemeSource.system || source == ThemeSource.custom) continue;
      final s = source.seed;
      final dr = s.r * 255 - color.r * 255;
      final dg = s.g * 255 - color.g * 255;
      final db = s.b * 255 - color.b * 255;
      final dist = dr * dr + dg * dg + db * db;
      if (dist < bestDist) {
        bestDist = dist;
        best = source;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Primary color seed'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Follow system'),
              value: _followSystem,
              onChanged: (on) {
                setState(() => _followSystem = on);
                if (on) {
                  widget.onThemeChanged(ThemeSource.system);
                } else {
                  final closest = _findClosestSource(_currentColor);
                  widget.onThemeChanged(closest ?? ThemeSource.ocean);
                }
              },
            ),
            if (_isCustomColor) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ColoredBox(
                  color: _currentColor,
                  child: const SizedBox(width: double.infinity, height: 56),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hexController,
                onChanged: (_) => _updateRgbFromHex(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.colorize_outlined),
                  labelText: 'Hex',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    child: Text('R', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Slider(
                      value: _r,
                      min: 0,
                      max: 255,
                      onChanged: (v) => setState(() {
                        _r = v;
                        _updateHexFromRgb();
                      }),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    child: Text('G', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Slider(
                      value: _g,
                      min: 0,
                      max: 255,
                      onChanged: (v) => setState(() {
                        _g = v;
                        _updateHexFromRgb();
                      }),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    child: Text('B', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Slider(
                      value: _b,
                      min: 0,
                      max: 255,
                      onChanged: (v) => setState(() {
                        _b = v;
                        _updateHexFromRgb();
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_isCustomColor) {
              final closest = _findClosestSource(_currentColor);
              widget.onThemeChanged(closest ?? ThemeSource.ocean);
            }
            Navigator.pop(context);
          },
          child: const Text('Okay'),
        ),
      ],
    );
  }
}
