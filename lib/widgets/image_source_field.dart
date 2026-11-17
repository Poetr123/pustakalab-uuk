import 'package:flutter/material.dart';

import 'app_image.dart';

/// Lightweight image input: store an external image URL in Firestore.
/// No Firebase Storage or file-picker setup is required.
class ImageSourceField extends StatefulWidget {
  const ImageSourceField({super.key, required this.controller, this.label = 'URL gambar (opsional)'});

  final TextEditingController controller;
  final String label;

  @override
  State<ImageSourceField> createState() => _ImageSourceFieldState();
}

class _ImageSourceFieldState extends State<ImageSourceField> {
  @override
  Widget build(BuildContext context) {
    final url = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'https://... (boleh dikosongkan)',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: url.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus gambar',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        if (url.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppImage(url: url, width: 112, height: 76),
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Tempel URL gambar PNG, JPG, WEBP, GIF, atau SVG.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
