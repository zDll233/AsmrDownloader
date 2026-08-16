import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsmrApiChannel extends ConsumerWidget {
  const AsmrApiChannel({super.key});

  static const List<String> _dropdownItems = [
    'asmr-100',
    'asmr-200',
    'asmr-300'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiChannel = ref.watch(apiChannelProvider);
    return DropdownButton<String>(
      value: apiChannel,
      focusColor: Colors.transparent,
      items: _dropdownItems.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: ref.read(uiServiceProvider).onApiChannelChoosed,
    );
  }
}
