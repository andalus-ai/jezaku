import 'package:flutter/material.dart';

class AdminFormSection extends StatelessWidget {
  const AdminFormSection({required this.title, required this.child, this.description, this.trailing, super.key});
  final String title;
  final String? description;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ])),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class AdminValidatedTextField extends StatelessWidget {
  const AdminValidatedTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.required = false,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final bool required;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    maxLength: maxLength,
    maxLines: obscureText ? 1 : maxLines,
    keyboardType: keyboardType,
    obscureText: obscureText,
    onChanged: onChanged,
    validator: validator ?? (value) {
      if (required && (value == null || value.trim().isEmpty)) return '$label is required';
      return null;
    },
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      helperText: helperText,
      alignLabelWithHint: maxLines > 1,
    ),
  );
}
