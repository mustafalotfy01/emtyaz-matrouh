import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppLocaleKey = 'app_user_selected_locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ar', 'EG')) {
    _loadPersistedLocale();
  }

  Future<void> _loadPersistedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(kAppLocaleKey);
      if (languageCode != null && languageCode.isNotEmpty) {
        if (languageCode == 'en') {
          state = const Locale('en', 'US');
        } else {
          state = const Locale('ar', 'EG');
        }
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale newLocale) async {
    if (state.languageCode == newLocale.languageCode) return;
    state = newLocale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAppLocaleKey, newLocale.languageCode);
    } catch (_) {}
  }

  Future<void> toggleLocale() async {
    if (state.languageCode == 'ar') {
      await setLocale(const Locale('en', 'US'));
    } else {
      await setLocale(const Locale('ar', 'EG'));
    }
  }

  bool get isArabic => state.languageCode == 'ar';
}
