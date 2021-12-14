import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

typedef NullOrStringFunction = Future<String?> Function();

class SettingState<T> {
  SettingState(this.value, this.isDisabled, this.disabledReason);
  final T value;
  final bool isDisabled;
  final String? disabledReason;
  bool operator ==(o) =>
      o is SettingState &&
      o.value == value &&
      o.isDisabled == isDisabled &&
      o.disabledReason == disabledReason;
}

/// Is a definition of a proprty that can be mutated in storage.
/// Allows for storage of raw string data.
/// This only contains information required for data manipulation
/// Any UI specific data is not defined here
class Setting {
  Setting(
      {required this.id,
      required this.defaultValue,
      String? disabledValue,
      this.checkDisabledFunction})
      : _disabledValue = disabledValue;

  StreamController<SettingState> _controller =
      StreamController<SettingState>.broadcast();

  ///Identifier for this setting (must be unique)
  String id;

  ///Default value for this setting.
  String defaultValue;

  ///Value that is returned if this setting is marked as disabled.
  String? _disabledValue;

  /// This function if not null is called to check if the setting is disabled.
  /// This function should return null if this setting should stay enabled, or
  /// return a string if the setting needs to be disabled.
  NullOrStringFunction? checkDisabledFunction;

  /// Value cached from the last time this setting was retrieved.
  SettingState<String>? _cachedState;

  String get _storeID {
    return "s_$id";
  }

  /// Updates this setting
  Future update() async {
    var newState =
        SettingState(await getString(), await isDisabled, await disabledReason);
    if (newState != _cachedState) {
      bool dirty = _cachedState?.value != null;
      _cachedState = newState;
      if (dirty) {
        //Emit an event if this setting changes.
        //uses getCache function which can be overridden to mutate to a
        //different data type.
        _controller.add(getCache);
      }
    }
  }

  Stream<SettingState> get onValueChange {
    return _controller.stream;
  }

  //Returns the default value if none is set
  SettingState<String> get getCacheString {
    return _cachedState ?? SettingState<String>(defaultValue, false, null);
  }

  SettingState get getCache {
    return getCacheString;
  }

  dynamic get disabledValue {
    return _disabledValue;
  }

  /// Sets a raw string value to the data layer
  Future setString(String value) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_storeID, value);
    if (_cachedState?.value != value && _cachedState != null) {
      //This value has changed
      await update();
    }
  }

  /// Resets this setting to the default value
  Future resetToDefault() async {
    await setString(defaultValue);
  }

  /// This is overridden by multisetting
  Future<dynamic> toJsonAsync() async {
    return await getString();
  }

  // Checks if the setting is disabled; if not it will return from data layer.
  Future<String> getString() async {
    if (await isDisabled) {
      //Dependency is disabled, return disabled value
      if (_disabledValue == null) {
        throw Exception("Disablable value cannot have a null disabled value");
      }
      return _disabledValue!;
    } else {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      String? val = sharedPreferences.getString(_storeID);
      if (val != null) {
        return val;
      }
      await resetToDefault();
      return defaultValue;
    }
  }

  // Checks if this setting is disabled or not.
  Future<bool> get isDisabled async {
    if (checkDisabledFunction == null) {
      return false;
    } else {
      return (await checkDisabledFunction!()) == null ? false : true;
    }
  }

  /// Gets the string reason why this setting is disabled.
  Future<String?> get disabledReason async {
    if (await isDisabled) {
      return await checkDisabledFunction!();
    }
    return null;
  }
}

/// Wrapper for Setting that allows for a <Type> to be stored.
/// It also handles data integrity.
class MultiSetting<T> extends Setting {
  MultiSetting(
      {required String id,
      required T defaultValue,
      T? disabledValue,
      NullOrStringFunction? checkDisabledFunction,
      required this.valueToString})
      :
        //Generate a reverse map for valueToStringMap if valueToString is not null
        stringToValue = valueToString.map((k, v) => MapEntry(v, k)),
        super(
            id: id,
            checkDisabledFunction: checkDisabledFunction,
            defaultValue: valueToString[defaultValue]!,
            disabledValue: valueToString[disabledValue]) {}

  ///Used to convert a value to a string and back. Required if is not a string.
  Map<T, String> valueToString;

  /// Generated reverse map to convert a string to a value.
  Map<String, T> stringToValue;

  /// returns the disabled value of this setting
  T get disabledValue {
    return stringToValue[_disabledValue]!;
  }

  // Override our update function to also call our get function that has checks
  // for bad values
  Future update() async {
    await get();
    await super.update();
  }

  /// Takes the state and returns a typed and converted one; returns the default value if null.
  SettingState<T> get getCache {
    return SettingState<T>(
        stringToValue[_cachedState?.value] ?? stringToValue[defaultValue]!,
        _cachedState?.isDisabled ?? false,
        _cachedState?.disabledReason);
  }

  /// This is overridden by multisetting
  Future<dynamic> toJsonAsync() async {
    var x = await get();
    if (x is bool || x is num || x is double || x is int) {
      return x;
    } else {
      return await getString();
    }
  }

  /// Gets the value of this setting (Including handling if it is disabled)
  Future<T> get() async {
    String valueString = await super.getString();
    T? val = stringToValue[valueString];
    if (val != null) {
      return val;
    }
    //This is not a valid value; return the default value and set the default.
    await resetToDefault();
    return stringToValue[defaultValue]!; //Default value has to be valid.
  }

  /// Sets the value of this setting; if it is not a valid type or value then
  /// it will throw an exception.
  Future set(T value) async {
    //Conversion is required.
    String? v = valueToString[value];
    if (v == null) {
      throw Exception(
          "Value ${value} ${value.runtimeType} is not a valid for setting id ${id}");
    }
    await super.setString(v);
  }
}

/// Setting wrapper for bool value settings.
class MultiSettingBool extends MultiSetting<bool> {
  MultiSettingBool(
      {required String id,
      required bool defaultValue,
      bool? disabledValue,
      NullOrStringFunction? checkDisabledFunction})
      : super(
            id: id,
            defaultValue: defaultValue,
            disabledValue: disabledValue,
            checkDisabledFunction: checkDisabledFunction,
            valueToString: {true: "true", false: "false"});
}

/// Setting wrapper for String value settings.
/// Automatically generates a 1 to 1 string map with the values options
class MultiSettingString extends MultiSetting<String> {
  MultiSettingString(
      {required String id,
      required String defaultValue,
      required List<String> options,
      String? disabledValue,
      NullOrStringFunction? checkDisabledFunction})
      : super(
            id: id,
            defaultValue: defaultValue,
            disabledValue: disabledValue,
            checkDisabledFunction: checkDisabledFunction,
            valueToString:
                Map.fromIterable(options, key: (e) => e, value: (e) => e));
}

/// Setting wrapper for int value settings.
/// Automatically generates a 1 to 1 int map with the values options
class MultiSettingInt extends MultiSetting<int> {
  MultiSettingInt(
      {required String id,
      required int defaultValue,
      required List<int> options,
      int? disabledValue,
      NullOrStringFunction? checkDisabledFunction})
      : super(
            id: id,
            defaultValue: defaultValue,
            disabledValue: disabledValue,
            checkDisabledFunction: checkDisabledFunction,
            valueToString: Map.fromIterable(options,
                key: (e) => e, value: (e) => e.toString()));
}
