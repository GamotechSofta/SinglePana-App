import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';

class MyBets2DLotteryPage extends StatefulWidget {
  const MyBets2DLotteryPage({super.key});

  @override
  State<MyBets2DLotteryPage> createState() => _MyBets2DLotteryPageState();
}

class _MyBets2DLotteryPageState extends State<MyBets2DLotteryPage> {
  bool _loading = true;
  String _error = '';
  List<_QuizGroup> _groups = const [];
  _DrawFilter _drawFilter = _DrawFilter.all;
  DateTime _selectedDate = DateTime.now();
  /// Full ticket ids currently being cancelled (prevents double submit).
  final Set<String> _cancellingTicketIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  String _statusLabel(String status) {
    if (status == 'win') return 'Won';
    if (status == 'lose') return 'Lost';
    if (status == 'pending') return 'Pending';
    if (status == 'cancelled') return 'Cancelled';
    return status.isEmpty ? '-' : status;
  }

  bool _rowIsCancelled(Map<String, dynamic> row) {
    final st =
        '${row['status'] ?? row['ticketStatus'] ?? ''}'.trim().toLowerCase();
    if (st == 'cancelled' || st == 'canceled' || st == 'void') return true;
    if (row['cancelled'] == true ||
        row['isCancelled'] == true ||
        row['isCanceled'] == true) {
      return true;
    }
    return false;
  }

  /// Decodes Mongo-style fields that may be a string or `{ "$oid": "..." }`.
  String _mongoString(dynamic v) {
    if (v == null) return '';
    if (v is Map && v[r'$oid'] != null) return '${v[r'$oid']}'.trim();
    return '$v'.trim();
  }

  /// Last 8 characters of API `ticketId` (mongoose ObjectId string) — alphanumeric, unchanged.
  /// Falls back to `_id` the same way if `ticketId` is absent.
  String _ticketIdLastEight(Map<String, dynamic> row) {
    final fromApi = _mongoString(row['ticketId']);
    if (fromApi.isNotEmpty) {
      final s = fromApi.length <= 8 ? fromApi : fromApi.substring(fromApi.length - 8);
      return s.toUpperCase();
    }
    final fromDoc = _mongoString(row['_id']);
    if (fromDoc.isNotEmpty) {
      final s = fromDoc.length <= 8 ? fromDoc : fromDoc.substring(fromDoc.length - 8);
      return s.toUpperCase();
    }
    return '--------';
  }

  /// Full ticket / document id for grouping (prefers API `ticketId`).
  String _ticketBatchIdRaw(Map<String, dynamic> row) {
    final fromApi = _mongoString(row['ticketId']);
    if (fromApi.isNotEmpty) return fromApi;
    final fromDoc = _mongoString(row['_id']);
    if (fromDoc.isNotEmpty) return fromDoc;
    return '';
  }

  String _groupHeaderTicketIdsLine(_QuizGroup group) {
    final seen = <String>{};
    final parts = <String>[];
    for (final row in group.lines) {
      final id = _ticketIdLastEight(row);
      if (seen.add(id)) parts.add(id);
    }
    return 'Ticket ID: ${parts.join(', ')}';
  }

  /// Groups all lines that belong to the same ticket (same slot + batch id), across quiz numbers.
  String _ticketBatchKey(Map<String, dynamic> row) {
    const batchKeys = ['ticketId', 'ticketDisplayId', 'displayTicketId', 'displayId'];
    for (final key in batchKeys) {
      final raw = _mongoString(row[key]);
      if (raw.isNotEmpty) return '$key|$raw';
    }
    final full = _ticketBatchIdRaw(row);
    if (full.isNotEmpty) return 'id|$full';
    return _ticketIdLastEight(row);
  }

  int _rowQuizId(Map<String, dynamic> row) => int.tryParse('${row['quizId'] ?? ''}') ?? 0;

  String _quizLabelForRow(Map<String, dynamic> row) =>
      'Q${_rowQuizId(row).toString().padLeft(2, '0')}';

  String _sortedUniqueQuizHeader(_QuizGroup group) {
    final ids = <int>{};
    for (final row in group.lines) {
      ids.add(_rowQuizId(row));
    }
    final list = ids.toList()..sort();
    return list.map((q) => 'Q${q.toString().padLeft(2, '0')}').join(', ');
  }

  String? _headerWinningText(_QuizGroup group) {
    if (!group.slotEnded) return null;
    final wins = <String>{};
    for (final row in group.lines) {
      if (row['winningNumber'] != null) {
        wins.add('${row['winningNumber']}'.padLeft(2, '0'));
      }
    }
    if (wins.isNotEmpty) {
      final list = wins.toList()..sort();
      return list.join(', ');
    }
    return group.winningNumber;
  }

  String _displayStatus(Map<String, dynamic> row, _QuizGroup group) {
    if (_rowIsCancelled(row)) return 'cancelled';
    final slotEnded = row['slotEnded'] == true || group.slotEnded;
    final winning = row['winningNumber'] != null
        ? '${row['winningNumber']}'.padLeft(2, '0')
        : group.winningNumber;
    if (slotEnded && winning != null) {
      final betNo = '${row['number'] ?? ''}'.padLeft(2, '0');
      return betNo == winning ? 'win' : 'lose';
    }
    final status = '${row['status'] ?? 'pending'}'.trim().toLowerCase();
    return status.isEmpty ? 'pending' : status;
  }

  /// True when the slot has not closed yet — user may cancel the whole ticket via API.
  bool _canCancelFullTicket(_QuizGroup group) {
    if (group.lines.isEmpty) return false;
    if (group.slotEnded) return false;
    for (final row in group.lines) {
      final st = _displayStatus(row, group);
      if (st == 'win' || st == 'lose' || st == 'cancelled') return false;
    }
    return _ticketIdForCancelApi(group).isNotEmpty;
  }

  /// Full ticket id for `DELETE .../my-quiz-tickets/:id?mode=2d` (same as batch id).
  String _ticketIdForCancelApi(_QuizGroup group) {
    if (group.lines.isEmpty) return '';
    return _ticketBatchIdRaw(group.lines.first);
  }

  Future<void> _cancelFullTicket(_QuizGroup group) async {
    final ticketId = _ticketIdForCancelApi(group);
    if (ticketId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing ticket id — cannot cancel.')),
      );
      return;
    }
    if (_cancellingTicketIds.contains(ticketId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel full ticket?'),
        content: const Text(
          'This cancels all bets on this ticket for the current draw. You can only cancel before results are out.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final headers = await _authHeaders();
    if (headers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return;
    }

    setState(() => _cancellingTicketIds.add(ticketId));
    try {
      final uri = Uri.parse(
        '$kApiBaseUrl/quiz/my-quiz-tickets/${Uri.encodeComponent(ticketId)}?mode=2d',
      );
      final res = await http.delete(uri, headers: headers);
      Map<String, dynamic>? body;
      try {
        if (res.body.isNotEmpty) {
          body = jsonDecode(res.body) as Map<String, dynamic>?;
        }
      } catch (_) {}

      if (!mounted) return;

      if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        return;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _load(showFullScreenLoading: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body?['message']?.toString() ?? 'Ticket cancelled.')),
        );
        return;
      }
      final msg = body?['message']?.toString() ?? 'Could not cancel ticket.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cancellingTicketIds.remove(ticketId));
      }
    }
  }

  List<_QuizGroup> _groupRows(List<Map<String, dynamic>> rows) {
    final map = <String, _QuizGroup>{};
    for (final row in rows) {
      final slotStartIso = '${row['slotStartIso'] ?? ''}';
      final k = '$slotStartIso|${_ticketBatchKey(row)}';
      final existing = map[k];
      if (existing == null) {
        final createdAt = DateTime.tryParse('${row['createdAt'] ?? ''}');
        final slotStart = DateTime.tryParse(slotStartIso);
        final isAdvanceDraw = createdAt != null && slotStart != null
            ? slotStart.difference(createdAt).inMinutes > 1
            : false;
        map[k] = _QuizGroup(
          slotStartIso: slotStartIso,
          drawLabelEnd: row['drawLabelEnd']?.toString(),
          slotEnded: row['slotEnded'] == true,
          winningNumber: row['winningNumber'] == null ? null : '${row['winningNumber']}'.padLeft(2, '0'),
          isAdvanceDraw: isAdvanceDraw,
          lines: [row],
        );
      } else {
        existing.lines.add(row);
        existing.slotEnded = existing.slotEnded || row['slotEnded'] == true;
        if ((existing.drawLabelEnd == null || existing.drawLabelEnd!.isEmpty) &&
            row['drawLabelEnd'] != null &&
            '${row['drawLabelEnd']}'.trim().isNotEmpty) {
          existing.drawLabelEnd = row['drawLabelEnd']?.toString();
        }
      }
    }
    final groups = map.values.toList()
      ..sort((a, b) {
        // Show Normal Draw groups before Advance Draw groups.
        final drawTypeOrder = (a.isAdvanceDraw ? 1 : 0).compareTo(
          b.isAdvanceDraw ? 1 : 0,
        );
        if (drawTypeOrder != 0) return drawTypeOrder;
        return b.slotStartIso.compareTo(a.slotStartIso);
      });
    for (final g in groups) {
      g.lines.sort((a, b) {
        final cq = _rowQuizId(a).compareTo(_rowQuizId(b));
        if (cq != 0) return cq;
        final an = int.tryParse('${a['number'] ?? ''}') ?? 0;
        final bn = int.tryParse('${b['number'] ?? ''}') ?? 0;
        return an.compareTo(bn);
      });
    }
    return groups;
  }

  /// Reload tickets for the selected date. Use [showFullScreenLoading]: false after actions like cancel
  /// so the list refreshes without replacing the whole body with a spinner.
  Future<void> _load({bool showFullScreenLoading = true}) async {
    if (showFullScreenLoading) {
      setState(() {
        _loading = true;
        _error = '';
      });
    } else if (mounted) {
      setState(() => _error = '');
    }
    try {
      final headers = await _authHeaders();
      if (headers.isEmpty) {
        if (!mounted) return;
        setState(() {
          _groups = const [];
          _loading = false;
          _error = 'Please login first.';
        });
        return;
      }
      final dateKey =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse(
        '$kApiBaseUrl/quiz/my-quiz-bets?limit=120&mode=2d&date=${Uri.encodeQueryComponent(dateKey)}',
      );
      final res = await http.get(uri, headers: headers);
      final body = jsonDecode(res.body) as Map<String, dynamic>?;

      if (!mounted) return;
      if (res.statusCode == 401) {
        setState(() {
          _groups = const [];
          _loading = false;
          _error = 'Session expired. Please login again.';
        });
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _groups = const [];
          _loading = false;
          _error = body?['message']?.toString() ?? 'Failed to load tickets.';
        });
        return;
      }

      final raw = (body?['data'] is List) ? (body!['data'] as List) : const [];
      final rows = <Map<String, dynamic>>[
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
      setState(() {
        _groups = _groupRows(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _groups = const [];
        _loading = false;
        _error = 'Failed to load tickets.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups = _groups.where((g) {
      if (_drawFilter == _DrawFilter.all) return true;
      if (_drawFilter == _DrawFilter.normal) return !g.isAdvanceDraw;
      return g.isAdvanceDraw;
    }).toList();
    return Container(
      color: const Color(0xFFF1F1F1),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFE3E3E3),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  tooltip: 'Back',
                ),
                const Expanded(
                  child: Text(
                    'My_Bets_2DLottery',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF666666)),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_formatDateChip(_selectedDate)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _load,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF666666)),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF3F34),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFC5362D)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                        ),
                      )
                    : _groups.isEmpty
                        ? const Center(
                            child: Text(
                              'No 2D quiz tickets found.',
                              style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                            ),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                                child: Row(
                                  children: [
                                    _FilterButton(
                                      label: 'All',
                                      selected: _drawFilter == _DrawFilter.all,
                                      onTap: () => setState(() => _drawFilter = _DrawFilter.all),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterButton(
                                      label: 'Normal Draw',
                                      selected: _drawFilter == _DrawFilter.normal,
                                      onTap: () => setState(() => _drawFilter = _DrawFilter.normal),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterButton(
                                      label: 'Advance Draw',
                                      selected: _drawFilter == _DrawFilter.advance,
                                      onTap: () => setState(() => _drawFilter = _DrawFilter.advance),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: visibleGroups.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No tickets found for selected filter.',
                                          style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                                        itemCount: visibleGroups.length,
                                        itemBuilder: (context, index) {
                                          final group = visibleGroups[index];
                                          final winningHdr = _headerWinningText(group);
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: const Color(0xFFBBBBBB)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    children: [
                                                      Text(
                                                        'Quiz: ${_sortedUniqueQuizHeader(group)}',
                                                        style: const TextStyle(
                                                          color: Color(0xFF1A4D6E),
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Draw: ${group.drawLabelEnd ?? '-'}',
                                                        style: const TextStyle(
                                                          color: Color(0xFF1A4D6E),
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      Text(
                                                        _groupHeaderTicketIdsLine(group),
                                                        style: const TextStyle(
                                                          color: Color(0xFF1A4D6E),
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          letterSpacing: 0.4,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: group.isAdvanceDraw ? const Color(0xFFE0E7FF) : const Color(0xFFDCFCE7),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          group.isAdvanceDraw ? 'Advance Draw' : 'Normal Draw',
                                                          style: TextStyle(
                                                            color: group.isAdvanceDraw ? const Color(0xFF3730A3) : const Color(0xFF166534),
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      if (winningHdr != null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF2F6FF),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'Winning: $winningHdr',
                                                            style: const TextStyle(
                                                              color: Color(0xFF333333),
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      if (_canCancelFullTicket(group)) ...[
                                                        Builder(
                                                          builder: (context) {
                                                            final cancelId = _ticketIdForCancelApi(group);
                                                            final busy = _cancellingTicketIds.contains(cancelId);
                                                            return TextButton(
                                                              style: TextButton.styleFrom(
                                                                foregroundColor: const Color(0xFFB91C1C),
                                                                side: const BorderSide(color: Color(0xFFB91C1C), width: 1),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                minimumSize: Size.zero,
                                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                              ),
                                                              onPressed: busy ? null : () => _cancelFullTicket(group),
                                                              child: Text(
                                                                busy ? 'Cancelling…' : 'Cancel full ticket',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w700,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    final minTableWidth = constraints.maxWidth;
                                                    return SingleChildScrollView(
                                                      scrollDirection: Axis.horizontal,
                                                      child: ConstrainedBox(
                                                        constraints: BoxConstraints(minWidth: minTableWidth),
                                                        child: DataTableTheme(
                                                          data: const DataTableThemeData(
                                                            headingTextStyle: TextStyle(
                                                              color: Colors.black,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                            dataTextStyle: TextStyle(
                                                              color: Colors.black,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          child: DataTable(
                                                            headingRowColor: WidgetStateProperty.all(const Color(0xFFD9E4F5)),
                                                            dataRowColor: WidgetStateProperty.all(const Color(0xFFF8F8F8)),
                                                            columns: const [
                                                              DataColumn(
                                                                label: Text(
                                                                  'Quiz',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              DataColumn(
                                                                label: Text(
                                                                  'Number',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              DataColumn(
                                                                label: Text(
                                                                  'Amount',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              DataColumn(
                                                                label: Text(
                                                                  'Status',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              DataColumn(
                                                                label: Text(
                                                                  'Win Amount',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              DataColumn(
                                                                label: Text(
                                                                  'Draw Type',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                              DataColumn(
                                                                label: Text(
                                                                  'Action',
                                                                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                                                                ),
                                                              ),
                                                            ],
                                                            rows: [
                                                              for (final row in group.lines)
                                                                () {
                                                                  final status = _displayStatus(row, group);
                                                                  final statusColor = status == 'win'
                                                                      ? const Color(0xFF15803D)
                                                                      : status == 'lose'
                                                                          ? const Color(0xFFB91C1C)
                                                                          : status == 'cancelled'
                                                                              ? const Color(0xFF6B7280)
                                                                              : const Color(0xFFB45309);
                                                                  final winPayout = num.tryParse('${row['winPayout'] ?? ''}') ?? 0;
                                                                  return DataRow(
                                                                    cells: [
                                                                      DataCell(
                                                                        Text(
                                                                          _quizLabelForRow(row),
                                                                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          '${row['number'] ?? ''}'.padLeft(2, '0'),
                                                                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          '₹${row['amount'] ?? 0}',
                                                                          style: const TextStyle(color: Colors.black, fontSize: 10),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          _statusLabel(status),
                                                                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          status == 'win'
                                                                              ? (winPayout > 0 ? '₹$winPayout' : 'Processing...')
                                                                              : '-',
                                                                          style: const TextStyle(color: Colors.black, fontSize: 10),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          group.isAdvanceDraw ? 'Advance' : 'Normal',
                                                                          style: const TextStyle(color: Colors.black, fontSize: 10),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        TextButton(
                                                                          onPressed: () => _showLineDetails(group, row),
                                                                          child: const Text('View'),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                }(),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLineDetails(_QuizGroup group, Map<String, dynamic> row) async {
    final number = '${row['number'] ?? ''}'.padLeft(2, '0');
    final amount = '${row['amount'] ?? 0}';
    final status = _statusLabel(_displayStatus(row, group));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bet Detail'),
        content: Text(
          'Quiz: ${_quizLabelForRow(row)}\n'
          'Number: $number\n'
          'Amount: ₹$amount\n'
          'Draw: ${group.drawLabelEnd ?? '-'}\n'
          'Type: ${group.isAdvanceDraw ? 'Advance Draw' : 'Normal Draw'}\n'
          'Status: $status',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDateChip(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Select ticket date',
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
    await _load();
  }
}

class _QuizGroup {
  _QuizGroup({
    required this.slotStartIso,
    required this.drawLabelEnd,
    required this.slotEnded,
    required this.winningNumber,
    required this.isAdvanceDraw,
    required this.lines,
  });

  final String slotStartIso;
  String? drawLabelEnd;
  bool slotEnded;
  final String? winningNumber;
  final bool isAdvanceDraw;
  final List<Map<String, dynamic>> lines;
}

enum _DrawFilter { all, normal, advance }

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF2D9DE8) : Colors.white,
        foregroundColor: selected ? Colors.white : Colors.black87,
        side: BorderSide(
          color: selected ? const Color(0xFF1C87CD) : const Color(0xFF9CA3AF),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
