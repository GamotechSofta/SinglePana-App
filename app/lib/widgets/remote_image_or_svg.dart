import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Remote assets that are `.svg` must use [SvgPicture] — [Image.network] does not
/// decode SVG (unlike browsers with `<img src="...svg">`).
class RemoteImageOrSvg extends StatelessWidget {
  const RemoteImageOrSvg({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? errorWidget;

  static bool _looksLikeSvg(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.svg') || u.contains('.svg?');
  }

  @override
  Widget build(BuildContext context) {
    if (_looksLikeSvg(url)) {
      return SvgPicture.network(
        url,
        fit: fit,
        alignment: alignment,
        placeholderBuilder: (_) => Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) =>
          errorWidget ??
          Icon(Icons.casino, size: 48, color: Colors.grey.shade500),
    );
  }
}
