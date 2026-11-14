import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 颜色选择对话框: 预设色板 + 最近使用 + HSV 滑块 + hex 输入。
/// 返回选中的颜色; 返回 null 表示取消。
class ColorPickerDialog extends ConsumerStatefulWidget {
  const ColorPickerDialog({super.key, required this.initial});

  /// 初始颜色 (当前主题色)。
  final Color initial;

  /// 预设色板 (Material 主色系)。
  static const List<Color> presets = [
    Color(0xFFF44336), // red
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF673AB7), // deep purple
    Color(0xFF3F51B5), // indigo
    Color(0xFF2196F3), // blue
    Color(0xFF00BCD4), // cyan
    Color(0xFF009688), // teal
    Color(0xFF4CAF50), // green
    Color(0xFFCDDC39), // lime
    Color(0xFFFFC107), // amber
    Color(0xFFFF5722), // deep orange
  ];

  @override
  ConsumerState<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends ConsumerState<ColorPickerDialog> {
  late HSVColor _hsv;
  List<Color> _recent = [];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _loadRecent();
  }

  Color get _current => _hsv.toColor();

  Future<void> _loadRecent() async {
    final config = await ref.read(configFileProvider).read();
    final list = config['recentColors'];
    if (list is! List) return;
    final colors = <Color>[];
    for (final e in list) {
      final c = parseHexColor(e.toString());
      if (c != null && !colors.contains(c)) {
        colors.add(c);
      }
      if (colors.length >= 10) break;
    }
    if (mounted) setState(() => _recent = colors);
  }

  /// 确定时把颜色记入最近使用 (去重, 最新在前, 最多 10 个)。
  Future<void> _saveRecent(Color color) async {
    final config = await ref.read(configFileProvider).read();
    final hex = colorToHex(color);
    final list = <String>[hex];
    for (final e in (config['recentColors'] as List?) ?? const <dynamic>[]) {
      final s = e.toString().toUpperCase();
      if (s != hex && list.length < 10) {
        list.add(s);
      }
    }
    await ref.read(configFileProvider).write({...config, 'recentColors': list});
  }

  void _apply(Color c) {
    setState(() => _hsv = HSVColor.fromColor(c));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = _current;
    return AlertDialog(
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recent.isNotEmpty) ...[
              const Text('最近使用'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _recent)
                    _Swatch(
                      color: c,
                      selected: current == c,
                      onTap: () => _apply(c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const Text('预设'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in ColorPickerDialog.presets)
                  _Swatch(
                    color: preset,
                    selected: current == preset,
                    onTap: () => _apply(preset),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _SliderBar(
              label: '色相',
              value: _hsv.hue / 360,
              colors: [
                for (var h = 0.0; h <= 360; h += 60)
                  HSVColor.fromAHSV(1, h, 1, 1).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v * 360)),
            ),
            _SliderBar(
              label: '饱和度',
              value: _hsv.saturation,
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _SliderBar(
              label: '明度',
              value: _hsv.value,
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: current,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      final cleaned = v.replaceAll('#', '').trim();
                      if (cleaned.length == 6) {
                        final value = int.tryParse(cleaned, radix: 16);
                        if (value != null) _apply(Color(0xFF000000 | value));
                      }
                    },
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: '# ',
                      labelText: '颜色值',
                      hintText: 'RRGGBB',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            await _saveRecent(current);
            if (context.mounted) {
              Navigator.pop(context, current);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _SliderBar extends StatelessWidget {
  const _SliderBar({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 10,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackShape: _GradientTrackShape(colors),
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 渐变轨道: 轨道绘制为横向渐变色条。
class _GradientTrackShape extends SliderTrackShape {
  const _GradientTrackShape(this.colors);

  final List<Color> colors;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
        trackLeft, trackTop, parentBox.size.width, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        trackRect,
        Radius.circular(trackRect.height / 2),
      ),
      Paint()
        ..shader = LinearGradient(colors: colors).createShader(trackRect),
    );
  }
}
