import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/common/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 窗口背景效果解析 (config.json `windowEffect`, 缺省 acrylic)。
String resolveWindowEffect(Map<String, dynamic> config) {
  final v = config['windowEffect'];
  return v is String && v.isNotEmpty ? v : WINDOW_EFFECT_ACRYLIC;
}

/// 窗口背景效果模式 ('transparent' | 'acrylic' | 'opaque')。
final windowEffectProvider = FutureProvider.autoDispose<String>((ref) async {
  final config = await ref.read(configFileProvider).read();
  return resolveWindowEffect(config);
});

/// 应用主题: 由种子色生成 (参考 Again 项目的主题定制)。
final appThemeProvider = Provider<ThemeData>((ref) {
  return _buildTheme();
});

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.purple,
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
