import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/wallet_service.dart';

class Lottery3DAccountPage extends StatefulWidget {
  const Lottery3DAccountPage({super.key});

  @override
  State<Lottery3DAccountPage> createState() => _Lottery3DAccountStandalonePageState();
}

class _Lottery3DAccountStandalonePageState extends State<Lottery3DAccountPage> {
  bool _loading = true;
  Map<String, dynamic> _user = const {};
  num _wallet = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _pick(Map<String, dynamic> user, List<String> keys, {String fallback = '-'}) {
    for (final k in keys) {
      final v = user[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  Map<String, dynamic> _normalizeUser(dynamic raw) {
    Map<String, dynamic> top;
    if (raw is Map) {
      top = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        top = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      } catch (_) {
        top = <String, dynamic>{};
      }
    } else {
      top = <String, dynamic>{};
    }
    final nestedUser = top['user'] is Map ? Map<String, dynamic>.from(top['user'] as Map) : <String, dynamic>{};
    final nestedProfile = top['profile'] is Map ? Map<String, dynamic>.from(top['profile'] as Map) : <String, dynamic>{};
    final nestedData = top['data'] is Map ? Map<String, dynamic>.from(top['data'] as Map) : <String, dynamic>{};
    final nestedDataUser = nestedData['user'] is Map ? Map<String, dynamic>.from(nestedData['user'] as Map) : <String, dynamic>{};
    final nestedSession = top['session'] is Map ? Map<String, dynamic>.from(top['session'] as Map) : <String, dynamic>{};
    final nestedSessionUser = nestedSession['user'] is Map ? Map<String, dynamic>.from(nestedSession['user'] as Map) : <String, dynamic>{};
    final nestedUserData = top['userData'] is Map ? Map<String, dynamic>.from(top['userData'] as Map) : <String, dynamic>{};

    return <String, dynamic>{
      ...top,
      ...nestedData,
      ...nestedSession,
      ...nestedUser,
      ...nestedSessionUser,
      ...nestedUserData,
      ...nestedDataUser,
      ...nestedProfile,
    };
  }

  Future<void> _load() async {
    try {
      final raw = await AuthService.instance.getStoredUser() ?? <String, dynamic>{};
      final u = _normalizeUser(raw);
      final balanceRes = await WalletService.instance.fetchBalance();
      final fallback = u['balance'] ?? u['walletBalance'] ?? u['wallet'] ?? 0;
      final fallbackNum = fallback is num ? fallback : num.tryParse('$fallback') ?? 0;
      if (!mounted) return;
      setState(() {
        _user = u;
        _wallet = balanceRes.success && balanceRes.balance != null ? balanceRes.balance! : fallbackNum;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = const <String, dynamic>{};
        _wallet = 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _pick(_user, ['firstName', 'firstname', 'givenName'], fallback: '');
    final last = _pick(_user, ['lastName', 'lastname', 'surname'], fallback: '');
    final merged = '$first $last'.trim();
    final name = merged.isNotEmpty
        ? merged
        : _pick(_user, ['name', 'fullName', 'displayName', 'userName', 'username', 'phone'], fallback: '-');
    final userId = _pick(_user, ['id', '_id', 'userId', 'uid', 'userName', 'username'], fallback: '-');
    final phone = _pick(_user, ['phone', 'mobile'], fallback: '-');
    final email = _pick(_user, ['email'], fallback: '-');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('3D Account'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AccountRow(label: 'Name', value: name),
                      _AccountRow(label: 'User ID', value: userId),
                      _AccountRow(label: 'Phone', value: phone),
                      _AccountRow(label: 'Email', value: email),
                      _AccountRow(label: 'Wallet', value: '₹$_wallet'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.replaceAll('\n', ' ').trim();
    final clipped = normalized.length > 80 ? '${normalized.substring(0, 80)}...' : normalized;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            clipped.isEmpty ? '-' : clipped,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
