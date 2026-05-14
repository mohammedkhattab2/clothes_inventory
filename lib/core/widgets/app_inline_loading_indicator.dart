import 'package:flutter/material.dart';

class AppInlineLoadingIndicator extends StatelessWidget {
  const AppInlineLoadingIndicator({
    this.size = 14,
    this.strokeWidth = 2,
    this.color,
    super.key,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}
