const double TITLEBAR_HEIGHT = 40.0;

// 窗口背景效果模式
const String WINDOW_EFFECT_TRANSPARENT = 'transparent';
const String WINDOW_EFFECT_ACRYLIC = 'acrylic';
const String WINDOW_EFFECT_OPAQUE = 'opaque';

/// 默认主题色 (config `themeSeedColor` 缺省值, #RRGGBB)。
///
/// 保持项目原本的紫色作为默认值。
const String kDefaultThemeSeedHex = '#9C27B0';

// 布尔开关缺省值 (读取处与重置块统一引用, 避免语义默认与重置默认不一致)。
// 默认值照搬 Again 项目。
const bool kDefaultRememberWindowPos = false;
const bool kDefaultRememberWindowSize = true;
