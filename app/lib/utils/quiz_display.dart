/// Quiz study-list display helpers (mirrors offlineGame2/frontend quizSlotClock + pages).

/// 2D study list: first row at slot start, each following row after this delay.
const int kQuiz2dRevealStaggerMs = 8700;

/// 3D study list stagger (0.81 s between rows).
const int kQuiz3dRevealStaggerMs = 810;

/// Rows visible for the current wall time vs server slot start (ISO UTC).
int visibleQuestionCountFromSlotStart(
  String? slotStartIso,
  int totalQuestions, {
  int staggerMs = kQuiz2dRevealStaggerMs,
}) {
  if (totalQuestions <= 0 || slotStartIso == null || slotStartIso.isEmpty) {
    return 0;
  }
  final slotStart = DateTime.tryParse(slotStartIso);
  if (slotStart == null) return 0;
  final elapsed = DateTime.now().difference(slotStart).inMilliseconds;
  final safeElapsed = elapsed < 0 ? 0 : elapsed;
  final count = (safeElapsed ~/ staggerMs) + 1;
  return count.clamp(1, totalQuestions);
}

/// Study table: highest shuffle slot first; stagger reveals from the high end.
/// Same as `questions.slice(n - k, n).reverse()` in the web app.
List<Map<String, dynamic>> studyVisibleQuestions(
  List<Map<String, dynamic>> questions,
  int visibleCount,
) {
  final n = questions.length;
  if (n == 0 || visibleCount <= 0) return const [];
  final k = visibleCount < n ? visibleCount : n;
  final slice = questions.sublist(n - k, n);
  return slice.reversed.toList();
}

/// Slot index label for row at [displayRowIndex] in the visible list (0 = top).
int slotIndexForStudyRow(int totalQuestionCount, int displayRowIndex) {
  return (totalQuestionCount - 1 - displayRowIndex).clamp(0, totalQuestionCount - 1);
}

String padQuizSlotIndex(int slotIndex, {bool is3d = false}) {
  final width = is3d ? 3 : 2;
  return slotIndex.toString().padLeft(width, '0');
}

int revealStaggerMsFromSettings(
  Map<String, dynamic>? settings, {
  required int defaultMs,
}) {
  if (settings == null) return defaultMs;
  final raw = settings['questionRevealStaggerMs'];
  if (raw is num && raw > 0) return raw.toInt();
  final parsed = int.tryParse('${raw ?? ''}');
  if (parsed != null && parsed > 0) return parsed;
  return defaultMs;
}
