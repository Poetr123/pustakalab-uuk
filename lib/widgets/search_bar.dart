import 'package:flutter/material.dart';

class PustakaSearchBar extends StatelessWidget {
  const PustakaSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onChanged,
    this.hintText = 'Cari nama, kategori, atau kode alat...',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Bersihkan pencarian',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
      );
}
