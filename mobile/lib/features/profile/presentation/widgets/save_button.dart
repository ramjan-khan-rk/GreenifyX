import 'package:flutter/material.dart';

/// Full-width primary button that shows a spinner while [loading].
class SaveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const SaveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
