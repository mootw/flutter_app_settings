import 'package:flutter/material.dart';

//This is used to get the absolute position on screen
//https://stackoverflow.com/questions/50316219/how-to-get-widgets-absolute-coordinates-on-a-screen-in-flutter
extension GlobalKeyEx on GlobalKey {
  Rect? get globalPaintBounds {
    var renderObject = currentContext?.findRenderObject();
    var translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      return renderObject?.paintBounds
          .shift(Offset(translation.x, translation.y));
    } else {
      return null;
    }
  }
}

class ChipSelect<T> extends StatefulWidget {
  ChipSelect({this.selected, required this.chips, required this.callback});

  final T? selected;
  final List<SelectableChip<T>> chips;
  final Function(dynamic newSelected) callback;

  @override
  _ChipSelectState createState() => _ChipSelectState<T>();
}

class _ChipSelectState<T> extends State<ChipSelect> {
  late ScrollController _scrollController;
  late T selected;
  bool hasMovedInitial = false;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
    _scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      child: Row(children: [
        const SizedBox(width: 4),
        for (var chip in widget.chips) getChip(chip),
        const SizedBox(width: 4),
      ]),
    );
  }

  //Animates the listView to a key.
  void moveToKey(GlobalKey key) {
    var bounds = key.globalPaintBounds;
    if (bounds != null) {
      var screenWidth = _scrollController.position.viewportDimension;
      //We only want to scroll to the middle of the screen.
      //We do not want to scroll past the extent of the scrollview.
      double halfWidth = screenWidth / 2;
      double min = _scrollController.position.minScrollExtent;
      double max = _scrollController.position.maxScrollExtent;
      double target =
          _scrollController.position.pixels - (halfWidth - bounds.center.dx);
      if (target < min) {
        target = min;
      }
      if (target > max) {
        target = max;
      }
      _scrollController.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.ease);
    }
  }

  Widget getChip(SelectableChip chip) {
    bool isSelected = chip.value == selected;
    var key = GlobalKey();
    return Padding(
        padding: const EdgeInsets.only(left: 3, right: 3),
        child: ActionChip(
          //TODO maybe switch to InputChip?
          key: key,
          backgroundColor: isSelected ? Theme.of(context).highlightColor : null,
          onPressed: () {
            widget.callback(chip.value);
            setState(() {
              selected = chip.value;
            });
            moveToKey(key);
          },
          label: isSelected && chip.contentsSelected != null
              ? chip.contentsSelected!
              : chip.contents,
        ));
  }
}

class SelectableChip<T> {
  const SelectableChip(
      {required this.value, required this.contents, this.contentsSelected});

  final T value;
  final Widget contents;
  final Widget? contentsSelected;
}
