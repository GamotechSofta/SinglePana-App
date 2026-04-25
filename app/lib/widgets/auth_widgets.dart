import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const kAuthBannerUrl =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1770101961/Black_and_Gold_Classy_Casino_Night_Party_Instagram_Post_1080_x_1080_px_d1n00g.png';

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message, required this.mobileStyle});

  final String message;
  final bool mobileStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: mobileStyle ? Colors.red.withValues(alpha: 0.12) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: mobileStyle ? Colors.red.shade300 : Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: mobileStyle ? Colors.red.shade200 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthAgeCheckbox extends StatelessWidget {
  const AuthAgeCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.mobileStyle,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool mobileStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.green.shade600,
                side: BorderSide(color: mobileStyle ? Colors.grey.shade600 : Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: mobileStyle ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  children: [
                    const TextSpan(text: 'I confirm that I am above 18 years of age and agree to the '),
                    TextSpan(
                      text: 'Terms of Use',
                      style: TextStyle(
                        color: mobileStyle ? AppColors.gold : AppColors.navy,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: mobileStyle ? AppColors.gold : AppColors.navy,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
