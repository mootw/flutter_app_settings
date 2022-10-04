import 'dart:async';
import 'dart:convert';

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

/// Stores the raw json data persitantly.
/// Individual settings can interact with this.
/// Uses shared preferences to store the data.
/// Throughput doesn't matter much here, so
/// The implementation is fairly simple.
/// Whenver a setting is retrieved, use the cache
/// Whenever a key is set, set the cache value
/// and flush it to disk.
/// Each setting is encoded separately
class SettingDataStore {
  String id;
  SettingDataStore(this.id);

  Map<String, dynamic>? settings;
  Timer? _flushTimer;

  Future loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(id);
    if (data != null) {
      settings = jsonDecode(data);
      return;
    }
    //TODO
    //Load default values.
    settings = {};
  }

  Future<Map<String, dynamic>> getSettings() async {
    if (settings == null) {
      await loadFromDisk();
    }
    return settings!;
  }

  Future<dynamic> getValue(String key) async {
    return (await getSettings())[key];
  }

  Future<void> setValue(String key, dynamic value) async {
    (await getSettings())[key] = value;
    //Schedule disk flush for 100ms from now.
    _flushTimer?.cancel();
    _flushTimer = Timer(Duration(milliseconds: 100), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString(id, jsonEncode(settings));
      print(jsonEncode(settings));
    });
  }
}

/// Is a definition of a proprty that can be mutated in storage.
/// This helps define the shape of the setting to the app.
/// Any UI specific data is not defined here
class Setting<T> {
  Setting(
      {required this.dataStore,
      required this.id,
      required this.defaultValue,
      T? this.disabledValue,
      this.fromJson,
      this.options,
      this.checkDisabledFunction});

  StreamController<SettingState> _controller =
      StreamController<SettingState>.broadcast();

  SettingDataStore dataStore;

  ///Identifier for this setting (must be unique)
  String id;

  ///Default value for this setting.
  T defaultValue;

  ///Value that is returned if this setting is marked as disabled.
  T? disabledValue;

  /// defines possible values for this setting.
  List<T>? options;

  //Required if the Setting type isn't a JSON type.
  Function? fromJson;

  /// This function if not null is called to check if the setting is disabled.
  /// This function should return null if this setting should stay enabled, or
  /// return a string if the setting needs to be disabled.
  NullOrStringFunction? checkDisabledFunction;

  /// Value cached from the last time this setting was retrieved.
  SettingState<T>? _cachedState;

  /// Updates this setting
  Future update() async {
    var newState =
        SettingState(await get(), await isDisabled, await disabledReason);
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
  SettingState<T> get getCacheString {
    return _cachedState ?? SettingState<T>(defaultValue, false, null);
  }

  SettingState get getCache {
    return getCacheString;
  }

  /// Sets a value of this setting
  Future set(T value) async {
    print("Setting value ${id} to ${value}");
    dataStore.setValue(id, value);
    if (_cachedState?.value != value && _cachedState != null) {
      //This value has changed
      await update();
    }
  }

  /// Resets this setting to the default value
  Future resetToDefault() async {
    await set(defaultValue);
  }

  // Checks if the setting is disabled; if not it will return from data layer.
  Future<T> get() async {
    if (await isDisabled) {
      //Dependency is disabled, return disabled value
      if (disabledValue == null) {
        throw Exception("Disablable value cannot have a null disabled value");
      }
      return disabledValue!;
    } else {
      dynamic rawValue = await dataStore.getValue(id);
      if (rawValue == null) {
        resetToDefault();
        return defaultValue;
      }
      if (rawValue is T) {
        //Value doesn't exist in options, reset it
        if (options?.contains(rawValue) == false) {
          resetToDefault();
          return defaultValue;
        }
        return rawValue;
      }
      try {
        return fromJson!.call(rawValue);
      } catch (e, s) {
        print('$e $s');
        resetToDefault();
        return defaultValue;
      }
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
