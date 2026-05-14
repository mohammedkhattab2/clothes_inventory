import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class ProductsLastExportLabel extends StatelessWidget {
  const ProductsLastExportLabel({super.key, required this.lastExportPath});

  final String? lastExportPath;

  @override
  Widget build(BuildContext context) {
    if (lastExportPath == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${'Last'.tr()}: ${p.basename(lastExportPath!)}',
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
