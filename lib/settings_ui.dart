import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app_settings/settings.dart';
import 'package:flutter_app_settings/chip_select.dart';

class SettingToggle extends StatefulWidget {
  const SettingToggle(
      {required this.title, this.subtitle, required this.boolSetting, Key? key})
      : super(key: key);

  final String title;
  final String? subtitle;
  final Setting boolSetting;

  @override
  _SettingToggleState createState() => _SettingToggleState();
}

class _SettingToggleState extends State<SettingToggle> {
  bool? _localToggle;
  bool _isDisabled = false;
  String? _disabledReason;

  late StreamSubscription<dynamic> stream;

  @override
  void initState() {
    super.initState();
    var state = widget.boolSetting.getCache;
    update(state);
    stream = widget.boolSetting.onValueChange.listen((event) {
      update(event);
    });
  }

  void update(SettingState newState) {
    setState(() {
      _localToggle = newState.value;
      _isDisabled = newState.isDisabled;
      _disabledReason = newState.disabledReason;
    });
  }

  @override
  void dispose() {
    stream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Text("value $_localToggle"),
        // Text("disabled $_isDisabled"),
        ListTile(
          title: Text(widget.title),
          subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
          trailing: _localToggle == null
              ? null
              : Switch.adaptive(
                  value: _isDisabled
                      ? widget.boolSetting.disabledValue
                      : (_localToggle ?? false),
                  onChanged: _isDisabled
                      ? null
                      : (value) async {
                          await widget.boolSetting.set(value);
                        }),
        ),
        if (_isDisabled) Text('${_disabledReason}'),
      ],
    );
  }
}

class SettingDropdown<T> extends StatefulWidget {
  SettingDropdown(
      {required this.title,
      this.subtitle,
      required this.mySetting,
      required this.displayMap,
      Key? key})
      : super(key: key);

  final String title;
  final String? subtitle;

  // Data connector
  final Setting mySetting;

  // Converts T to a widget that is displayed in the UI; usually Text.
  final Map<T, Widget> displayMap;

  @override
  _SettingDropdownState createState() => _SettingDropdownState<T>();
}

class _SettingDropdownState<T> extends State<SettingDropdown> {
  T? _value;

  late StreamSubscription<dynamic> stream;

  @override
  void initState() {
    super.initState();
    var state = widget.mySetting.getCache;
    update(state);

    stream = widget.mySetting.onValueChange.listen((event) {
      update(event);
    });
  }

  void update(SettingState newState) {
    setState(() {
      _value = newState.value;
    });
  }

  @override
  void dispose() {
    stream.cancel();
    super.dispose();
  }

  List<DropdownMenuItem<T>> get items {
    return [
      for (var key in widget.displayMap.keys)
        DropdownMenuItem<T>(
            value: key, child: widget.displayMap[key] ?? Text('error')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      trailing: DropdownButton<T>(
          value: _value,
          onChanged: (T? newValue) {
            widget.mySetting.set(newValue);
          },
          items: items),
    );
  }
}

class SettingChipSelect<T> extends StatefulWidget {
  SettingChipSelect(
      {this.title, required this.mySetting, required this.displayMap, Key? key})
      : super(key: key);

  final String? title;

  // Data connector
  final Setting mySetting;

  // Converts T to a widget that is displayed in the UI; usually Text.
  final Map<T, Widget> displayMap;

  @override
  _SettingChipSelectState createState() => _SettingChipSelectState<T>();
}

class _SettingChipSelectState<T> extends State<SettingChipSelect> {
  T? _value;
  late StreamSubscription<dynamic> stream;

  @override
  void initState() {
    super.initState();
    var state = widget.mySetting.getCache;
    update(state);

    stream = widget.mySetting.onValueChange.listen((event) {
      update(event);
    });
  }

  void update(SettingState newState) {
    setState(() {
      _value = newState.value;
    });
  }

  @override
  void dispose() {
    stream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChipSelect<T>(
        callback: (value) {
          setState(() {
            _value = value;
          });
          widget.mySetting.set(value);
        },
        selected: _value,
        chips: widget.displayMap.keys
            .map((key) => SelectableChip<T>(
                contents: widget.displayMap[key]!, value: key))
            .toList());
  }
}

class SettingIndent extends StatelessWidget {
  final List<Widget> children;

  SettingIndent({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        children: children,
      ),
    );
  }
}
