import 'package:flutter/material.dart';

class ClearableDropdownMenu<T> extends StatefulWidget {
  final T? initialSelection;
  final String hintText;
  final Widget? leadingIcon;
  final double? width;
  final double? menuHeight;
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final ValueChanged<T?>? onSelected;
  final String fallbackText;
  final InputDecorationTheme? inputDecorationTheme;

  const ClearableDropdownMenu({
    super.key,
    this.initialSelection,
    required this.hintText,
    this.leadingIcon,
    this.width,
    this.menuHeight,
    required this.dropdownMenuEntries,
    this.onSelected,
    this.fallbackText = 'Todos',
    this.inputDecorationTheme,
  });

  @override
  State<ClearableDropdownMenu<T>> createState() => _ClearableDropdownMenuState<T>();
}

class _ClearableDropdownMenuState<T> extends State<ClearableDropdownMenu<T>> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _updateTextFromSelection();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _controller.clear();
      } else {
        if (_controller.text.isEmpty) {
          _controller.text = _lastText;
        }
      }
    });
  }

  void _updateTextFromSelection() {
    if (widget.initialSelection != null) {
      final initialEntry = widget.dropdownMenuEntries.where((e) => e.value == widget.initialSelection).toList();
      if (initialEntry.isNotEmpty) {
        _controller.text = initialEntry.first.label;
      } else {
        _controller.text = widget.hintText;
      }
    } else {
      _controller.text = widget.hintText;
    }
    _lastText = _controller.text;
  }

  @override
  void didUpdateWidget(covariant ClearableDropdownMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelection != oldWidget.initialSelection || widget.dropdownMenuEntries != oldWidget.dropdownMenuEntries) {
      _updateTextFromSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
        ),
      ),
      child: DropdownMenu<T>(
        controller: _controller,
        focusNode: _focusNode,
        initialSelection: widget.initialSelection,
        hintText: widget.hintText,
        leadingIcon: widget.leadingIcon,
        width: widget.width,
        menuHeight: widget.menuHeight,
        inputDecorationTheme: widget.inputDecorationTheme ?? const InputDecorationTheme(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
        dropdownMenuEntries: widget.dropdownMenuEntries,
        onSelected: (val) {
          if (val != null) {
             final entry = widget.dropdownMenuEntries.firstWhere(
               (e) => e.value == val, 
               orElse: () => DropdownMenuEntry<T>(value: val, label: widget.fallbackText)
             );
             _lastText = entry.label;
             _controller.text = entry.label;
          } else {
             _lastText = widget.hintText;
             _controller.text = widget.hintText;
          }
          _focusNode.unfocus();
          if (widget.onSelected != null) widget.onSelected!(val);
        },
      ),
    );
  }
}
