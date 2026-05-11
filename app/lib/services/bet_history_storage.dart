import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bid_row_vm.dart';

/// Same JSON shape as React `localStorage.betHistory` ([BidReviewModal.jsx]).
class BetHistoryStorage {
  BetHistoryStorage._();
  static final BetHistoryStorage instance = BetHistoryStorage._();

  static const _key = 'betHistory';
  static const _maxEntries = 200;

  Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }

  Future<void> appendEntry({
    required String? userId,
    required String marketTitle,
    required String dateText,
    required String labelKey,
    required List<BidRowVm> rows,
    required int totalBets,
    required double totalAmount,
    List<String>? serverBetIds,
  }) async {
    final rowMaps = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final fromServer = serverBetIds != null && i < serverBetIds.length
          ? serverBetIds[i].trim()
          : '';
      final idStr =
          fromServer.isNotEmpty ? fromServer : r.id.toString();
      rowMaps.add({
        'id': idStr,
        'number': r.number,
        'points': num.tryParse(r.points) ?? int.tryParse(r.points) ?? 0,
        'type': r.sessionLabel.toUpperCase(),
      });
    }
    final entry = <String, dynamic>{
      'id': '${DateTime.now().millisecondsSinceEpoch}-${rows.length}',
      'userId': userId,
      'marketTitle': marketTitle,
      'dateText': dateText,
      'labelKey': labelKey,
      'rows': rowMaps,
      'totalBets': totalBets,
      'totalAmount': totalAmount,
      'session': rows.isNotEmpty ? rows.first.sessionLabel : '',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final prev = await loadAll();
    await _save([entry, ...prev].take(_maxEntries).toList());
  }

  /// Persist computed won/lost on rows (matches React [BetHistory.jsx] effect).
  Future<void> applySettlements(List<BetSettlement> updates) async {
    if (updates.isEmpty) return;
    final prev = await loadAll();
    var changed = false;
    final next = prev.map((entry) {
      final entryId = entry['id']?.toString();
      if (entryId == null) return entry;
      final matches = updates.where((u) => u.entryId == entryId).toList();
      if (matches.isEmpty) return entry;
      final rows = entry['rows'];
      if (rows is! List) return entry;
      final newRows = rows.map((raw) {
        final r = Map<String, dynamic>.from(raw as Map);
        final rid = r['id']?.toString();
        BetSettlement? hit;
        for (final u in matches) {
          if (u.rowId == rid) {
            hit = u;
            break;
          }
        }
        if (hit == null) return r;
        if (r['settledState'] != null) return r;
        changed = true;
        r['settledState'] = hit.state;
        r['settledPayout'] = hit.payout;
        r['settledAt'] = DateTime.now().toIso8601String();
        return r;
      }).toList();
      return {...entry, 'rows': newRows};
    }).toList();
    if (changed) await _save(next);
  }
}

class BetSettlement {
  const BetSettlement({
    required this.entryId,
    required this.rowId,
    required this.state,
    required this.payout,
  });

  final String entryId;
  final String rowId;
  final String state;
  final num payout;
}
