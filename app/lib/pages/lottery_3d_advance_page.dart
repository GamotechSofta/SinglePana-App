import 'package:flutter/material.dart';

class Lottery3DAdvancePage extends StatefulWidget {
  const Lottery3DAdvancePage({
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
  State<Lottery3DAdvancePage> createState() => _Lottery3DAdvancePageState();
}

class _Lottery3DAdvancePageState extends State<Lottery3DAdvancePage> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedSlots.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.slotOptions.map((e) => e['slotStartIso'] ?? '').where((e) => e.isNotEmpty).toList();
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.slotOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: checked
                                ? const Color(0xFF1D4ED8)
                                : Colors.white,
                            border: Border.all(
                              color: checked
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                checked
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: checked
                                    ? Colors.white
                                    : const Color(0xFF334155),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: checked ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ],
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

