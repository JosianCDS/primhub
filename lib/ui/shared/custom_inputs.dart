import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final int maxLines;
  final double? width;
  final double? height;
  final bool obscureText;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool filled;
  final Color? fillColor;

  const CustomTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.maxLines = 1,
    this.width,
    this.height,
    this.obscureText = false,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.filled = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: prefixIcon,
          filled: filled,
          fillColor: fillColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hintText;
  final double? width;
  final double? height;
  final Widget? prefixIcon;
  final bool filled;
  final Color? fillColor;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hintText,
    this.width,
    this.height,
    this.prefixIcon,
    this.filled = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: prefixIcon,
          filled: filled,
          fillColor: fillColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}
