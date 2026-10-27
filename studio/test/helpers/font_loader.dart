import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadSystemFontForTest() async {
  try {
    final fontFile = File('/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf');
    if (await fontFile.exists()) {
      final bytes = await fontFile.readAsBytes();
      final fontData = ByteData.view(bytes.buffer);
      final fontLoader = FontLoader('Roboto');
      fontLoader.addFont(Future.value(fontData));
      final fontLoaderLib = FontLoader('LiberationSans');
      fontLoaderLib.addFont(Future.value(fontData));
      await fontLoader.load();
      await fontLoaderLib.load();
    }
  } catch (e) {
    // Ignore
  }
}
