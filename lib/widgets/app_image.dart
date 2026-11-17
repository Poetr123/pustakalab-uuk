import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppImage extends StatelessWidget {
  const AppImage({super.key, required this.url, this.width, this.height, this.fit = BoxFit.cover, this.placeholder});

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  bool get _isSvg {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _fallback();
    if (_isSvg) {
      return SvgPicture.network(
        url,
        width: width,
        height: height,
        fit: fit,
        placeholderBuilder: (_) => _fallback(),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => SizedBox(
        width: width,
        height: height,
        child: placeholder ?? Container(
          color: const Color(0xFFE8F0F8),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF1769AA), size: 34),
        ),
      );
}
