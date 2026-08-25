import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

@riverpod
class LocaleController extends _$LocaleController {
  static const String _localeKey = 'app_locale';
  static const Set<String> _supportedCodes = {'en', 'ru'};

  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null || !_supportedCodes.contains(code)) {
      return const Locale('en');
    }
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = AsyncData(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
