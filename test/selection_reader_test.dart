import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 内存版配置存储, 避免测试写真实文件。
class _MemStorage extends JsonStorage {
  _MemStorage() : super(filePath: 'selection_reader_test_config.json');

  @override
  Future<Map<String, dynamic>> read() async => <String, dynamic>{};

  @override
  Future<void> write(Map<String, dynamic> data) async {}

  @override
  Future<void> addOrUpdate(Map<String, dynamic> data) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clipboardChannel = SystemChannels.platform;
  String? clipboardText;
  int selectedTextReads = 0;
  String? selectedText;

  setUp(() {
    clipboardText = null;
    selectedText = null;
    selectedTextReads = 0;
    // windows_taskbar 的通道在测试环境没有实现, 不 mock 会让 resetProgress()
    // 永远不返回。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.alexmercerind/windows_taskbar'),
      (call) async => null,
    );
    // 剪贴板走系统通道, 测试里用桩替换。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, (call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return clipboardText == null ? null : <String, dynamic>{'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.alexmercerind/windows_taskbar'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, null);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        configFileProvider.overrideWithValue(_MemStorage()),
        // 选区读取替换成假实现, 不碰真实 UIA。
        selectedTextReaderProvider.overrideWithValue((_) async {
          selectedTextReads++;
          return selectedText;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('pasteAndSearch 的选区优先策略', () {
    test('选中文本是 sourceId 时优先用它, 忽略剪贴板', () async {
      selectedText = 'RJ01234567';
      clipboardText = 'RJ99999999';
      final container = createContainer();

      final result = await container.read(uiServiceProvider).pasteAndSearch();

      expect(result, 'RJ01234567');
      expect(selectedTextReads, 1);
      expect(container.read(searchTextProvider), 'RJ01234567');
    });

    test('没有选中文本时回退到剪贴板', () async {
      selectedText = null;
      clipboardText = 'RJ01234567';
      final container = createContainer();

      final result = await container.read(uiServiceProvider).pasteAndSearch();

      expect(result, 'RJ01234567');
      expect(container.read(searchTextProvider), 'RJ01234567');
    });

    test('选区不是 sourceId 时仍然回退到剪贴板', () async {
      // 例如网页上随手选中了一句话。
      selectedText = '这是一段普通文字';
      clipboardText = 'RJ01234567';
      final container = createContainer();

      final result = await container.read(uiServiceProvider).pasteAndSearch();

      expect(result, 'RJ01234567');
    });

    test('纯空白选区当作没有选中文本', () async {
      selectedText = '   \n\t ';
      clipboardText = 'RJ01234567';
      final container = createContainer();

      final result = await container.read(uiServiceProvider).pasteAndSearch();

      expect(result, 'RJ01234567');
    });

    test('选区读取抛异常时不影响剪贴板这条路径', () async {
      selectedText = null;
      clipboardText = 'RJ01234567';
      final container = ProviderContainer(
        overrides: [
          configFileProvider.overrideWithValue(_MemStorage()),
          selectedTextReaderProvider.overrideWithValue(
            (_) async => throw StateError('UIA 炸了'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(uiServiceProvider).pasteAndSearch();

      expect(result, 'RJ01234567');
    });

    test('带首尾空白的选区也能识别', () async {
      // 从网页上连行一起选走时很常见。
      selectedText = '  RJ01234567\n';
      clipboardText = null;
      final container = createContainer();

      final result = await container.read(uiServiceProvider).pasteAndSearch();

      // search() 返回的是归一化后的 sourceId。
      expect(result, 'RJ01234567');
      expect(container.read(sourceIdProvider), 'RJ01234567');
    });

    test('两者都不是 sourceId 时: 静默忽略, 不改搜索框', () async {
      selectedText = '普通文字';
      clipboardText = '另一段普通文字';
      final container = createContainer();

      final result = await container
          .read(uiServiceProvider)
          .pasteAndSearch(reportInvalid: false);

      expect(result, isNull);
      expect(container.read(searchTextProvider), isNull);
    });
  });
}
