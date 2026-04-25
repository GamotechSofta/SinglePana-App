import 'package:flutter/material.dart';

import '../game_bid_layout.dart';
import '../game_bid_ui.dart';
import '../../services/auth_service.dart';

class StubBidScreen extends StatefulWidget {
  const StubBidScreen({
    super.key,
    required this.market,
    required this.title,
    required this.message,
  });

  final Map<String, dynamic> market;
  final String title;
  final String message;

  @override
  State<StubBidScreen> createState() => _StubBidScreenState();
}

class _StubBidScreenState extends State<StubBidScreen> {
  double _wallet = 0;
  String _session = 'OPEN';
  String _date = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.instance.getStoredUser();
    final b = u?['balance'] ?? u?['walletBalance'] ?? 0;
    setState(() {
      _wallet = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
      _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
      _date = DateTime.now().toIso8601String().split('T').first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameBidLayout(
      market: widget.market,
      title: widget.title,
      session: _session,
      onSessionChanged: (v) => setState(() => _session = v),
      selectedDateYmd: _date,
      onDateChanged: (v) => setState(() => _date = v),
      walletBalance: _wallet,
      bidsCount: 0,
      totalPoints: 0,
      onSubmit: null,
      onBack: () => Navigator.of(context).pop(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            style: GameBidUi.emptyHint.copyWith(height: 1.4),
          ),
        ),
      ),
    );
  }
}
