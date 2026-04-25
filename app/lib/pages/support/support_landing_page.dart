import 'package:flutter/material.dart';

import '../../theme/casino_ui.dart';
import '../../utils/nav_main_route.dart';
import '../../utils/nav_pop_or_home.dart';

/// Help Desk menu — [frontend/src/pages/Support/SupportLanding.jsx].
class SupportLandingPage extends StatelessWidget {
  const SupportLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => popOrGoHome(context),
              icon: const Icon(Icons.arrow_back),
              color: CasinoUi.mutedGold(0.95),
            ),
            Expanded(
              child: Text(
                'Help Desk',
                style: TextStyle(
                  fontSize: wide ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: CasinoUi.lightGold,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 20),
          child: Text(
            'Choose an option below.',
            style: TextStyle(
              color: CasinoUi.mutedGold(0.78),
              fontSize: 13,
            ),
          ),
        ),
        _SupportTile(
          icon: Icons.add_box_outlined,
          title: 'Raise help ticket',
          subtitle: 'Submit a new problem with description and screenshots.',
          onTap: () => navigateMainRoute(context, '/support/new'),
        ),
        const SizedBox(height: 14),
        _SupportTile(
          icon: Icons.fact_check_outlined,
          title: 'Check previous problem status',
          subtitle: 'See status and reply for your submitted tickets.',
          onTap: () => navigateMainRoute(context, '/support/status'),
        ),
      ],
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, color: CasinoUi.lightGold, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: CasinoUi.lightGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: CasinoUi.mutedGold(0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: CasinoUi.mutedGold(0.65)),
            ],
          ),
        ),
      ),
    );
  }
}
