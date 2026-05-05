import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SacaThemePreference { light, dark, system }

class SacaSettingsState {
  const SacaSettingsState({
    this.themePreference = SacaThemePreference.light,
    this.textScale = SacaSettingsController.defaultTextScale,
  });

  final SacaThemePreference themePreference;
  final double textScale;

  SacaSettingsState copyWith({
    SacaThemePreference? themePreference,
    double? textScale,
  }) {
    return SacaSettingsState(
      themePreference: themePreference ?? this.themePreference,
      textScale: textScale ?? this.textScale,
    );
  }
}

class SacaSettingsController extends ChangeNotifier {
  SacaSettingsController({SacaSettingsStore? store})
      : _store = store ?? SharedPreferencesSacaSettingsStore();

  static const defaultTextScale = 1.15;
  static const minTextScale = 0.90;
  static const maxTextScale = 1.40;
  static const _themeKey = 'saca.themePreference';
  static const _textScaleKey = 'saca.textScale';

  final SacaSettingsStore _store;
  SacaSettingsState _state = const SacaSettingsState();

  SacaSettingsState get state => _state;

  Future<void> load() async {
    final themeName = await _store.getString(_themeKey);
    final savedScale = await _store.getDouble(_textScaleKey);
    _state = SacaSettingsState(
      themePreference: SacaThemePreference.values.firstWhere(
        (preference) => preference.name == themeName,
        orElse: () => SacaThemePreference.light,
      ),
      textScale: clampTextScale(savedScale ?? defaultTextScale),
    );
    notifyListeners();
  }

  Future<void> setThemePreference(SacaThemePreference preference) async {
    if (_state.themePreference == preference) return;
    _state = _state.copyWith(themePreference: preference);
    notifyListeners();
    await _store.setString(_themeKey, preference.name);
  }

  Future<void> setTextScale(double value) async {
    final scale = clampTextScale(value);
    if (_state.textScale == scale) return;
    _state = _state.copyWith(textScale: scale);
    notifyListeners();
    await _store.setDouble(_textScaleKey, scale);
  }

  Brightness resolveBrightness(Brightness platformBrightness) {
    return switch (_state.themePreference) {
      SacaThemePreference.light => Brightness.light,
      SacaThemePreference.dark => Brightness.dark,
      SacaThemePreference.system => platformBrightness,
    };
  }

  static double clampTextScale(double value) {
    return value.clamp(minTextScale, maxTextScale).toDouble();
  }
}

abstract interface class SacaSettingsStore {
  Future<String?> getString(String key);

  Future<double?> getDouble(String key);

  Future<void> setString(String key, String value);

  Future<void> setDouble(String key, double value);
}

class SharedPreferencesSacaSettingsStore implements SacaSettingsStore {
  SharedPreferencesSacaSettingsStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<double?> getDouble(String key) => _preferences.getDouble(key);

  @override
  Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> setDouble(String key, double value) {
    return _preferences.setDouble(key, value);
  }
}
