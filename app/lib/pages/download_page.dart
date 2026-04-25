import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/backend_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/nav_pop_or_home.dart';

/// APK download — [frontend/src/pages/Download.jsx].
class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  static Uri apkUri() => Uri.parse('$kBackendBaseUrl/downloads/myapp.apk');

  Future<void> _openApk(BuildContext context) async {
    try {
      final ok = await launchUrl(apkUri(), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade50,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => popOrGoHome(context), icon: const Icon(Icons.arrow_back)),
                  const Expanded(
                    child: Text(
                      'Download App',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.android, size: 72, color: Colors.green.shade700),
                    const SizedBox(height: 10),
                    Text(
                      'SinglePana mobile app',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Download the Android APK to install on your device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _openApk(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.buttonPaddingH,
                          vertical: AppSpacing.buttonPaddingV,
                        ),
                        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download APK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
