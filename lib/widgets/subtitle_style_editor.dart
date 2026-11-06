import 'package:flutter/material.dart';

import '../core/subtitle_style.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'focusable.dart';

/// Vorschau der Untertitel auf einem bildähnlichen Hintergrund.
class SubtitleStylePreview extends StatelessWidget {
  const SubtitleStylePreview({super.key, required this.style, this.height = 150});

  final SubtitleStyle style;
  final double height;

  /// Rand aus Schatten – nah genug an dem, was mpv zeichnet.
  static List<Shadow> _shadows(SubtitleEdge edge) {
    List<Shadow> ring(double size) => [
      for (final (x, y) in const [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0), (0.0, -1.0), (0.0, 1.0)])
        Shadow(color: const Color(0xE6000000), offset: Offset(x * size, y * size), blurRadius: 0.5),
    ];
    return switch (edge) {
      SubtitleEdge.outline => [...ring(1), const Shadow(color: Color(0x80000000), offset: Offset(1, 1), blurRadius: 2)],
      SubtitleEdge.thick => [...ring(2), const Shadow(color: Color(0x80000000), offset: Offset(1, 1), blurRadius: 2)],
      SubtitleEdge.shadow => const [Shadow(color: Color(0xCC000000), offset: Offset(2, 2), blurRadius: 3)],
      SubtitleEdge.box || SubtitleEdge.none => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    const baseSize = 20.0;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + height * style.raise / 100),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3A55), Color(0xFF6B4E71), Color(0xFFB0735C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: style.edge == SubtitleEdge.box ? Colors.black.withValues(alpha: style.boxOpacity) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          tr.subtitlePreview,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.fade,
          style: TextStyle(
            fontFamily: style.font.family,
            fontSize: baseSize * style.scale,
            height: 1.2,
            fontWeight: style.bold ? FontWeight.w600 : FontWeight.w400,
            color: Color(style.color),
            shadows: _shadows(style.edge),
          ),
        ),
      ),
    );
  }
}

/// Bedienfelder für den Untertitel-Stil – in den Einstellungen, im Dialog je Bibliothek und im Player.
class SubtitleStyleEditor extends StatelessWidget {
  const SubtitleStyleEditor({super.key, required this.style, required this.onChanged, this.padding = EdgeInsets.zero});

  final SubtitleStyle style;
  final ValueChanged<SubtitleStyle> onChanged;
  final EdgeInsetsGeometry padding;

  static String fontName(SubtitleFont font) => switch (font) {
    SubtitleFont.standard => tr.subtitleFontStandard,
    SubtitleFont.clear => tr.subtitleFontClear,
    SubtitleFont.serif => tr.subtitleFontSerif,
    SubtitleFont.mono => tr.subtitleFontMono,
    SubtitleFont.rounded => tr.subtitleFontRounded,
  };

  static String edgeName(SubtitleEdge edge) => switch (edge) {
    SubtitleEdge.outline => tr.subtitleEdgeOutline,
    SubtitleEdge.thick => tr.subtitleEdgeThick,
    SubtitleEdge.shadow => tr.subtitleEdgeShadow,
    SubtitleEdge.box => tr.subtitleEdgeBox,
    SubtitleEdge.none => tr.subtitleEdgeNone,
  };

  static String colorName(int color) => switch (subtitleColors.indexOf(color)) {
    1 => tr.subtitleColorYellow,
    2 => tr.subtitleColorCyan,
    3 => tr.subtitleColorGreen,
    4 => tr.subtitleColorPink,
    _ => tr.subtitleColorWhite,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            label: tr.size,
            value: '${(style.scale * 100).round()} %',
            child: Slider(
              value: style.scale.clamp(SubtitleStyle.minScale, SubtitleStyle.maxScale),
              min: SubtitleStyle.minScale,
              max: SubtitleStyle.maxScale,
              divisions: 16,
              semanticFormatterCallback: (v) => '${(v * 100).round()} %',
              onChanged: (v) => onChanged(style.copyWith(scale: v)),
            ),
          ),
          _Field(
            label: tr.subtitlePosition,
            value: style.raise == 0 ? tr.subtitlePositionBottom : '+${style.raise} %',
            child: Slider(
              value: style.raise.toDouble(),
              max: SubtitleStyle.maxRaise.toDouble(),
              divisions: SubtitleStyle.maxRaise ~/ 2,
              semanticFormatterCallback: (v) => '+${v.round()} %',
              onChanged: (v) => onChanged(style.copyWith(raise: v.round())),
            ),
          ),
          _Field(
            label: tr.subtitleFont,
            child: _Pills<SubtitleFont>(
              values: SubtitleFont.values,
              selected: style.font,
              label: fontName,
              textStyle: (font) => TextStyle(fontFamily: font.family),
              onSelect: (v) => onChanged(style.copyWith(font: v)),
            ),
          ),
          _Field(
            label: tr.subtitleColor,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in subtitleColors)
                  _Swatch(
                    color: color,
                    label: colorName(color),
                    selected: color == style.color,
                    onTap: () => onChanged(style.copyWith(color: color)),
                  ),
              ],
            ),
          ),
          _Field(
            label: tr.subtitleEdge,
            child: _Pills<SubtitleEdge>(
              values: SubtitleEdge.values,
              selected: style.edge,
              label: edgeName,
              onSelect: (v) => onChanged(style.copyWith(edge: v)),
            ),
          ),
          if (style.edge == SubtitleEdge.box)
            _Field(
              label: tr.subtitleBoxOpacity,
              value: '${(style.boxOpacity * 100).round()} %',
              child: Slider(
                value: style.boxOpacity,
                min: 0.1,
                divisions: 9,
                semanticFormatterCallback: (v) => '${(v * 100).round()} %',
                onChanged: (v) => onChanged(style.copyWith(boxOpacity: v)),
              ),
            ),
          _SwitchField(
            label: tr.subtitleBold,
            value: style.bold,
            onChanged: (v) => onChanged(style.copyWith(bold: v)),
          ),
          _SwitchField(
            label: tr.subtitleForceStyle,
            hint: tr.subtitleForceStyleHint,
            value: style.forceOnStyled,
            onChanged: (v) => onChanged(style.copyWith(forceOnStyled: v)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.value});

  final String label;
  final String? value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              if (value != null) Text(value!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SwitchField extends StatelessWidget {
  const _SwitchField({required this.label, required this.value, required this.onChanged, this.hint});

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Pills<T> extends StatelessWidget {
  const _Pills({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.textStyle,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final TextStyle Function(T)? textStyle;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Semantics(
            selected: value == selected,
            child: Focusable(
              onTap: () => onSelect(value),
              builder: (context, highlighted) {
                final active = value == selected;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : Colors.white.withValues(alpha: highlighted ? 0.14 : 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: highlighted ? Colors.white : Colors.transparent, width: 1.5),
                  ),
                  child: Text(
                    label(value),
                    style: (textStyle?.call(value) ?? const TextStyle()).copyWith(
                      fontSize: 13.5,
                      color: Colors.white,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label, required this.selected, required this.onTap});

  final int color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Focusable(
        onTap: onTap,
        semanticLabel: label,
        builder: (context, highlighted) => Tooltip(
          message: label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.accent : (highlighted ? Colors.white : Colors.white24),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.black87) : null,
          ),
        ),
      ),
    );
  }
}
