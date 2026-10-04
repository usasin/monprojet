import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Read the real translations synchronously inside the widget test fake clock.
/// The production RootBundle loader performs IO outside that clock.
class TestTranslations extends AssetLoader {
  const TestTranslations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      SynchronousFuture(
        jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
            as Map<String, dynamic>,
      );
}
