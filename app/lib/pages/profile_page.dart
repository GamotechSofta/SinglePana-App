import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'login_page.dart';
import '../services/auth_service.dart';
import '../services/session_coordinator.dart';
import '../services/bets_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/casino_ui.dart';
import '../utils/nav_main_route.dart';
import '../utils/nav_pop_or_home.dart';

/// Icons in Account Information tiles (readable on dark chrome).
const Color _kAccountInfoIconColor = Color(0xFFF7F5F0);

/// Account hub — [frontend/src/pages/Profile.jsx].
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  Map<String, dynamic>? _user;
  String? _copiedLabel;
  bool _statementBusy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUser();
  }

  Future<void> _bootstrap() async {
    final u = await AuthService.instance.getStoredUser();
    if (!mounted) return;
    final token = u?['token']?.toString();
    if (u == null || token == null || token.isEmpty) {
      Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
      return;
    }
    await WalletService.instance.refreshBalanceInStorage();
    if (!mounted) return;
    final fresh = await AuthService.instance.getStoredUser();
    if (!mounted) return;
    setState(() => _user = fresh);
  }

  Future<void> _refreshUser() async {
    await WalletService.instance.refreshBalanceInStorage();
    final u = await AuthService.instance.getStoredUser();
    if (!mounted) return;
    final token = u?['token']?.toString();
    if (u == null || token == null || token.isEmpty) {
      Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
      return;
    }
    setState(() => _user = u);
  }

  String _pick(Map<String, dynamic>? u, List<String> keys) {
    if (u == null) return '';
    for (final k in keys) {
      final v = u[k];
      if (v != null && v.toString().trim().isNotEmpty)
        return v.toString().trim();
    }
    return '';
  }

  num? _wallet(Map<String, dynamic>? u) {
    if (u == null) return null;
    for (final k in [
      'wallet',
      'balance',
      'points',
      'walletAmount',
      'wallet_amount',
      'amount',
    ]) {
      final v = u[k];
      if (v is num) return v;
      final n = num.tryParse(v?.toString() ?? '');
      if (n != null) return n;
    }
    return null;
  }

  Future<void> _copy(String text, String label) async {
    if (text.isEmpty || text == 'Not set' || text == 'N/A') return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copiedLabel = label);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copiedLabel = null);
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _downloadStatement() async {
    final u = _user;
    if (u == null || (u['id'] == null && u['_id'] == null)) {
      _showToast('Please log in to download statement');
      return;
    }
    setState(() => _statementBusy = true);
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 30));
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final r = await BetsService.instance.fetchMyStatement(
      startDateYmd: ymd(start),
      endDateYmd: ymd(end),
    );
    if (!mounted) return;
    setState(() => _statementBusy = false);
    if (!r.success || r.bytes == null) {
      _showToast(r.message ?? 'Failed to download statement');
      return;
    }
    final isPdf = r.contentType?.toLowerCase().contains('pdf') ?? false;
    final ext = isPdf ? 'pdf' : 'dat';
    final name = 'statement_${ymd(start)}_${ymd(end)}.$ext';
    final mime =
        r.contentType ??
        (isPdf ? 'application/pdf' : 'application/octet-stream');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(r.bytes!, name: name, mimeType: mime)],
        text: 'Betting statement',
      ),
    );
    _showToast('Share or save your statement');
  }

  Future<void> _logout() async {
    SessionCoordinator.instance.stopHeartbeat();
    await AuthService.instance.logoutThisDevice();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
  }

  Widget _copyIcon(String label, String text) {
    final done = _copiedLabel == label;
    return IconButton(
      onPressed: () => _copy(text, label),
      icon: Icon(
        done ? Icons.check : Icons.copy,
        size: 18,
        color: done ? AppColors.accentEmerald : _kAccountInfoIconColor,
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.last.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CasinoUi.lightGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    bool copyable = false,
    String? copyLabel,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CasinoUi.mutedGold(0.72),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CasinoUi.lightGold,
                    ),
                  ),
                ],
              ),
            ),
            if (copyable && value != 'Not set' && copyLabel != null)
              _copyIcon(copyLabel, value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    if (u == null) {
      return const Center(
        child: CircularProgressIndicator(color: CasinoUi.lightGold),
      );
    }

    final username = _pick(u, ['username', 'name', 'fullName']);
    final phone = _pick(u, [
      'phone',
      'mobile',
      'mobileNumber',
      'phoneNumber',
      'phone_number',
      'mobilenumber',
    ]);
    final email = _pick(u, ['email']);
    final userId = u['id']?.toString() ?? u['_id']?.toString() ?? 'N/A';
    final wallet = _wallet(u);
    final walletFmt = NumberFormat('#,##0.00', 'en_IN');
    final avatar = (username.isNotEmpty ? username[0] : 'U').toUpperCase();
    final created = u['createdAt'] ?? u['created_at'] ?? u['createdOn'];
    DateTime? createdDt;
    if (created != null) createdDt = DateTime.tryParse(created.toString());
    final memberSince = createdDt != null
        ? DateFormat.yMMMMd().format(createdDt)
        : null;

    final wide = MediaQuery.sizeOf(context).width >= 768;

    final hero = _HeroCard(
      avatar: avatar,
      username: username.isEmpty ? 'User' : username,
      subtitle: email.isNotEmpty
          ? email
          : (phone.isNotEmpty ? phone : 'No contact info'),
      walletText: wallet != null ? '₹${walletFmt.format(wallet)}' : '₹0.00',
    );

    final quick = GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        _quickAction(
          icon: Icons.add,
          label: 'Add Fund',
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          onTap: () => navigateMainRoute(
            context,
            '/funds',
            arguments: {'tab': 'add-fund'},
          ),
        ),
        _quickAction(
          icon: Icons.arrow_downward_rounded,
          label: 'Withdraw',
          gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
          onTap: () => navigateMainRoute(
            context,
            '/funds',
            arguments: {'tab': 'withdraw-fund'},
          ),
        ),
        _quickAction(
          icon: Icons.menu_book_outlined,
          label: 'Passbook',
          gradient: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
          onTap: () => navigateMainRoute(context, '/passbook'),
        ),
        _quickAction(
          icon: Icons.history,
          label: 'History',
          gradient: const [AppColors.navy, Color(0xFF152842)],
          onTap: () => navigateMainRoute(context, '/bet-history'),
        ),
      ],
    );

    final accountHeader = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Account Information',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: CasinoUi.lightGold,
        ),
      ),
    );

    final accountBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        accountHeader,
        _infoTile(
          icon: Icons.badge_outlined,
          title: 'User ID',
          value: userId,
          iconColor: _kAccountInfoIconColor,
          copyable: true,
          copyLabel: 'User ID',
        ),
        const SizedBox(height: 8),
        _infoTile(
          icon: Icons.person_outline,
          title: 'Username',
          value: username.isEmpty ? 'Not set' : username,
          iconColor: _kAccountInfoIconColor,
          copyable: true,
          copyLabel: 'Username',
        ),
        const SizedBox(height: 8),
        _infoTile(
          icon: Icons.email_outlined,
          title: 'Email',
          value: email.isEmpty ? 'Not set' : email,
          iconColor: _kAccountInfoIconColor,
          copyable: true,
          copyLabel: 'Email',
        ),
        const SizedBox(height: 8),
        _infoTile(
          icon: Icons.phone_outlined,
          title: 'Phone',
          value: phone.isEmpty ? 'Not set' : phone,
          iconColor: _kAccountInfoIconColor,
          copyable: true,
          copyLabel: 'Phone',
        ),
        if (memberSince != null) ...[
          const SizedBox(height: 8),
          _infoTile(
            icon: Icons.calendar_today_outlined,
            title: 'Member Since',
            value: memberSince,
            iconColor: _kAccountInfoIconColor,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _statementBusy ? null : _downloadStatement,
          icon: _statementBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kAccountInfoIconColor,
                  ),
                )
              : const Icon(Icons.description_outlined),
          label: const Text('Download statement (last 30 days)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: CasinoUi.lightGold,
            side: BorderSide(color: CasinoUi.neutralShellBorderColor(alpha: 0.22)),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingH,
              vertical: AppSpacing.buttonPaddingV,
            ),
            minimumSize: const Size(0, AppSpacing.buttonMinHeight),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );

    final logoutBtn = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentRose,
          side: BorderSide(
            color: AppColors.accentRose.withValues(alpha: 0.65),
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: AppSpacing.buttonPaddingV,
          ),
          minimumSize: const Size(0, AppSpacing.buttonMinHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: AppColors.accentRose.withValues(alpha: 0.1),
        ),
        icon: const Icon(Icons.logout),
        label: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );

    final titleWide = MediaQuery.sizeOf(context).width >= 720;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => popOrGoHome(context),
                icon: const Icon(Icons.arrow_back),
                color: CasinoUi.mutedGold(0.95),
              ),
              Expanded(
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: titleWide ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: CasinoUi.lightGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: wide
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 320,
                        child: ListView(
                          children: [
                            hero,
                            const SizedBox(height: 10),
                            quick,
                            const SizedBox(height: 10),
                            logoutBtn,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            Card(
                              color: Colors.transparent,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              shape: CasinoUi.supportCardShape(),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: accountBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    hero,
                    const SizedBox(height: 10),
                    quick,
                    const SizedBox(height: 10),
                    accountBody,
                    const SizedBox(height: 10),
                    logoutBtn,
                  ],
                ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.avatar,
    required this.username,
    required this.subtitle,
    required this.walletText,
  });

  final String avatar;
  final String username;
  final String subtitle;
  final String walletText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
          width: 1,
        ),
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: AppColors.navy,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        avatar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CasinoUi.lightGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: CasinoUi.mutedGold(0.72),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: CasinoUi.neutralShellBorderColor(alpha: 0.16),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WALLET BALANCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CasinoUi.mutedGold(0.72),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          walletText,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: CasinoUi.lightGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 32,
                    color: CasinoUi.mutedGold(0.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
