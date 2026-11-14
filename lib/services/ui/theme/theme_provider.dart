import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/common/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 默认主题种子色 (由 [kDefaultThemeSeedHex] 派生, 单一来源)。
final Color kDefaultThemeSeed = parseHexColor(kDefaultThemeSeedHex)!;

/// 解析自定义主题色, 缺省返回默认紫色 (#RRGGBB)。
String resolveThemeSeedHex(Map<String, dynamic> config) {
  final v = config['themeSeedColor'];
  return v is String && v.isNotEmpty ? v : kDefaultThemeSeedHex;
}

/// 解析 #RRGGBB / RRGGBB 十六进制颜色, 非法返回 null。
Color? parseHexColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return null;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Color → #RRGGBB。
String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// 窗口背景效果解析 (config.json `windowEffect`, 缺省 acrylic)。
String resolveWindowEffect(Map<String, dynamic> config) {
  final v = config['windowEffect'];
  return v is String && v.isNotEmpty ? v : WINDOW_EFFECT_ACRYLIC;
}

/// 主题种子色: 用户在设置里选择的主题色 (缺省紫色)。
final themeSeedColorProvider = FutureProvider.autoDispose<Color>((ref) async {
  final config = await ref.read(configFileProvider).read();
  return parseHexColor(resolveThemeSeedHex(config)) ?? kDefaultThemeSeed;
});

/// 窗口背景效果模式 ('transparent' | 'acrylic' | 'opaque')。
final windowEffectProvider = FutureProvider.autoDispose<String>((ref) async {
  final config = await ref.read(configFileProvider).read();
  return resolveWindowEffect(config);
});

/// 应用主题: 由主题色生成 (参考 Again 项目的主题定制)。
final appThemeProvider = Provider<ThemeData>((ref) {
  final seed = ref.watch(themeSeedColorProvider).valueOrNull ?? kDefaultThemeSeed;
  return _buildTheme(seed);
});

ThemeData _buildTheme(Color seed) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final base = ThemeData(
    colorScheme: scheme,
    // 统一字体族: 避免 Segoe UI + 微软雅黑混排, 中文粗细不一致
    fontFamily: 'Microsoft YaHei',
    fontFamilyFallback: const ['Microsoft YaHei UI', 'Segoe UI', 'SimHei'],
  );

  // 字重扁平化: 微软雅黑只有 400/700 真实字重,
  // w500/w600 会被系统合成加粗导致粗细不均, 统一映射到真实字重
  final textTheme = base.textTheme.copyWith(
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium:
        base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge:
        base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
    labelMedium:
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w400),
    labelSmall:
        base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.onSurface.withValues(alpha: 0.05),
      hintStyle: TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.5),
        fontSize: 13,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface.withValues(alpha: 0.75),
        hoverColor: scheme.onSurface.withValues(alpha: 0.08),
        focusColor: Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface.withValues(alpha: 0.85),
        overlayColor: scheme.onSurface.withValues(alpha: 0.08),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(
        width: 1.5,
        color: scheme.onSurface.withValues(alpha: 0.4),
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: scheme.onSurface.withValues(alpha: 0.6),
      collapsedIconColor: scheme.onSurface.withValues(alpha: 0.6),
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.primary.withValues(alpha: 0.25),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      dense: true,
    ),
  );
}
