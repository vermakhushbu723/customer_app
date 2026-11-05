import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'common_widgets.dart';

/// A labelled text field whose placeholder is "Enter ..." from its label.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
    this.digitsOnly = false,
    this.prefix,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? hint;
  final bool digitsOnly;
  final String? prefix;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LabeledField(
        label: label,
        child: TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType ?? (digitsOnly ? TextInputType.number : null),
          textCapitalization: capitalization,
          onChanged: onChanged,
          inputFormatters: [
            if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            hintText: hint ?? enterHint(label),
            prefixIcon: prefix == null ? null : fieldPrefix(prefix!),
            prefixIconConstraints: const BoxConstraints(),
          ),
        ),
      ),
    );
  }
}

/// A labelled dropdown whose placeholder is "Select ..." from its label.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LabeledField(
        label: label,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          validator: validator,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutral900),
          hint: Text(selectHint(label), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutral500)),
          items: [
            for (final entry in items.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// A button small enough to sit in a row. The theme's buttons fill the width.
class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, required this.onPressed, this.outlined = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, 34);
    const padding = EdgeInsets.symmetric(horizontal: 12);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 5)],
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppTextStyles.label)),
        ),
      ],
    );
    return outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(minimumSize: size, padding: padding),
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(minimumSize: size, padding: padding),
            child: child,
          );
  }
}

/// A row in a menu list: an icon, a title, an optional subtitle and a chevron.
class MenuTile extends StatelessWidget {
  const MenuTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.color});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: (color ?? AppColors.sky700).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color ?? AppColors.sky700),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
                  if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, size: 20, color: AppColors.neutral500),
          ],
        ),
      ),
    );
  }
}
