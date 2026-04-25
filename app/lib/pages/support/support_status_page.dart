import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/help_desk_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../../utils/nav_main_route.dart';

/// Ticket list — [frontend/src/pages/Support/SupportStatus.jsx].
class SupportStatusPage extends StatefulWidget {
  const SupportStatusPage({super.key});

  @override
  State<SupportStatusPage> createState() => _SupportStatusPageState();
}

class _SupportStatusPageState extends State<SupportStatusPage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final u = await AuthService.instance.getStoredUser();
    if (!mounted) return;
    setState(() => _user = u);
    final token = u?['token']?.toString();
    if (u == null || token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _tickets = [];
      });
      return;
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final r = await HelpDeskService.instance.fetchMyTickets();
    if (!mounted) return;
    if (r.unauthorized) return;
    setState(() {
      _loading = false;
      _tickets = r.tickets;
    });
  }

  bool get _hasUser =>
      _user != null &&
      _user!['token'] != null &&
      _user!['token'].toString().isNotEmpty;

  static String _statusLabel(String? s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'in-progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return s ?? '-';
    }
  }

  static Color _statusColor(String? s) {
    switch (s) {
      case 'open':
        return AppColors.navy;
      case 'in-progress':
        return Colors.amber.shade800;
      case 'resolved':
        return Colors.green.shade700;
      case 'closed':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  static Color _statusBg(String? s) {
    switch (s) {
      case 'open':
        return AppColors.navy.withValues(alpha: 0.08);
      case 'in-progress':
        return Colors.amber.shade50;
      case 'resolved':
        return Colors.green.shade50;
      case 'closed':
        return Colors.grey.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '';
    return DateFormat.yMMMd().add_jm().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => navigateMainRoute(context, '/support'),
              icon: const Icon(Icons.arrow_back),
              color: CasinoUi.mutedGold(0.95),
            ),
            Expanded(
              child: Text(
                'Check problem status',
                style: TextStyle(
                  fontSize: wide ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ),
            if (_hasUser)
              IconButton(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                color: CasinoUi.mutedGold(0.9),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'See status and reply for your submitted tickets.',
            style: TextStyle(color: CasinoUi.mutedGold(0.78), fontSize: 13),
          ),
        ),
        Expanded(
          child: !_hasUser
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: CasinoUi.supportCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Please login to see your ticket status.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: CasinoUi.mutedGold(0.85), fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                )
              : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : _tickets.isEmpty
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: CasinoUi.supportCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No tickets yet. Raise a help ticket from Help Desk.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: CasinoUi.mutedGold(0.85), fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: _tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = _tickets[i];
                      final subject = t['subject']?.toString() ?? '-';
                      final status = t['status']?.toString();
                      final desc = t['description']?.toString() ?? '';
                      final admin = t['adminResponse']?.toString();
                      return Card(
                        color: Colors.transparent,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shape: CasinoUi.supportCardShape(),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: CasinoUi.lightGold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _fmtTime(t['createdAt']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: CasinoUi.mutedGold(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusBg(status),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _statusColor(
                                          status,
                                        ).withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  desc,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CasinoUi.mutedGold(0.85),
                                  ),
                                ),
                              ],
                              if (admin != null && admin.isNotEmpty) ...[
                                const Divider(height: 20),
                                Text(
                                  'Response from support',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CasinoUi.mutedGold(0.55),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  admin,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CasinoUi.lightGold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
