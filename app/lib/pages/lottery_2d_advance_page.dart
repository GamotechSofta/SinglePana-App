import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Lottery2DAdvancePage extends StatefulWidget {
  const Lottery2DAdvancePage({
    super.key,
    required this.currentLabel,
    required this.nextLabel,
    required this.slotOptions,
    required this.selectedSlots,
  });

  final String currentLabel;
  final String nextLabel;
  final List<Map<String, String>> slotOptions; // [{slotStartIso,label}]
  final List<String> selectedSlots;

  @override
  State<Lottery2DAdvancePage> createState() => _Lottery2DAdvancePageState();
}

class _Lottery2DAdvancePageState extends State<Lottery2DAdvancePage> {
  late Set<String> _selected;
  final TextEditingController _countCtrl = TextEditingController();
  String _countError = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedSlots.toSet();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  void _applyCountSelection(List<String> all) {
    final max = all.length;
    final raw = _countCtrl.text.trim();
    final x = int.tryParse(raw) ?? 0;
    if (x < 1 || x > max) {
      setState(() {
        _countError = 'Enter 1 to $max';
      });
      return;
    }
    setState(() {
      _countError = '';
      _selected = all.take(x).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.slotOptions
        .map((e) => e['slotStartIso'] ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final allSelected = all.isNotEmpty && _selected.length == all.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1223),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFF93C5FD)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D4ED8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'ADVANCE DRAW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Current: ${widget.currentLabel}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Next: ${widget.nextLabel}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    if (allSelected) {
                                      _selected.clear();
                                    } else {
                                      _selected = all.toSet();
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF334155),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: Text(allSelected ? 'Clear All' : 'Select All'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Selected: ${_selected.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 74,
                              height: 28,
                              child: TextField(
                                controller: _countCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                onSubmitted: (_) => _applyCountSelection(all),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Count',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF38BDF8),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: () => _applyCountSelection(all),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF334155),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                child: const Text(
                                  'Select',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_countError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _countError,
                            style: const TextStyle(
                              color: Color(0xFFFECACA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.slotOptions.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                      childAspectRatio: 2.2,
                    ),
                    itemBuilder: (context, i) {
                      final slot = widget.slotOptions[i];
                      final iso = slot['slotStartIso'] ?? '';
                      final label = slot['label'] ?? iso;
                      final checked = _selected.contains(iso);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (checked) {
                              _selected.remove(iso);
                            } else {
                              _selected.add(iso);
                            }
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: checked ? const Color(0xFF1D4ED8) : Colors.white,
                            border: Border.all(
                              color: checked
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: checked ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_selected.toList()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

