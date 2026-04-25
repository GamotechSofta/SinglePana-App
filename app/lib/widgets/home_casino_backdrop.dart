import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared shell background image.
class HomeCasinoBackdrop extends StatelessWidget {
  const HomeCasinoBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.primaryBackgroundGradient),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.08,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
