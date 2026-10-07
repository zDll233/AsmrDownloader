import 'package:asmr_downloader/services/asmr_repo/asmr_api.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void printFormattedMap(Map<String, dynamic> map) {
  const JsonEncoder encoder = JsonEncoder.withIndent('  '); // 设置缩进为两个空格
  String prettyPrint = encoder.convert(map);
  if (kDebugMode) {
    print(prettyPrint);
  }
}

/// A testing utility which creates a [ProviderContainer] and automatically
/// disposes it at the end of the test.
ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  // Create a ProviderContainer, and optionally allow specifying parameters.
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  // When the test ends, dispose the container.
  addTearDown(container.dispose);

  return container;
}

void main() {
  late final AsmrApi api;

  setUpAll(() async {
    Log.debug('set up');
    api = AsmrApi()
      ..proxy = 'DIRECT'
      // ..proxy = 'PROXY 127.0.0.1:7890'
      ..setApiChannel('asmr-200');
  });

  group('AsmrAPI', () {
    test('get playlist', () async {
      await api.login('user123456t', '123456');
      final playlist = await api.getPlaylists(page: 1);
      printFormattedMap(playlist!);
    });

    test('get search results', () async {
      final searchResults = await api.search(
        content: '柚木',
        params: {
          'page': 1,
          'pageSize': 12,
          'filterBy': 'all',
        },
      );
      printFormattedMap(searchResults);
    });

    test('get work info', () async {
      final workInfo = await api.getWorkInfo('422979');
      printFormattedMap(workInfo);
    });

    test('get voice tracks', () async {
      final voiceTracks = await api.getTracks('422979');
      for (var voiceTrack in voiceTracks) {
        printFormattedMap(voiceTrack);
      }
    });
  });
}
