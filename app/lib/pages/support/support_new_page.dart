import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/help_desk_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/casino_ui.dart';
import '../../utils/nav_main_route.dart';

/// Raise ticket — [frontend/src/pages/Support/SupportNew.jsx].
class SupportNewPage extends StatefulWidget {
  const SupportNewPage({super.key});

  @override
  State<SupportNewPage> createState() => _SupportNewPageState();
}

class _SupportNewPageState extends State<SupportNewPage> {
  final _subjectCtrl = TextEditingController(text: 'Support Request');
  final _descCtrl = TextEditingController();
  List<XFile> _images = [];
  bool _loading = false;
  String? _feedback;
  bool _feedbackOk = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await AuthService.instance.getStoredUser();
    if (mounted) setState(() => _user = u);
  }

  bool get _hasUser =>
      _user != null &&
      _user!['token'] != null &&
      _user!['token'].toString().isNotEmpty;

  Future<void> _pickImages() async {
    final remain = 5 - _images.length;
    if (remain <= 0) return;
    final list = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      limit: remain,
    );
    if (list.isEmpty || !mounted) return;
    setState(() {
      _images = [..._images, ...list].take(5).toList();
      _feedback = null;
    });
  }

  void _removeAt(int i) {
    setState(() {
      _images = List.from(_images)..removeAt(i);
    });
  }

  Future<void> _submit() async {
    if (!_hasUser) {
      setState(() {
        _feedback = 'Please login to submit a support request.';
        _feedbackOk = false;
      });
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      setState(() {
        _feedback = 'Please describe your problem.';
        _feedbackOk = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _feedback = null;
    });
    final paths = _images.map((x) => x.path).toList();
    final r = await HelpDeskService.instance.submitTicket(
      subject: _subjectCtrl.text,
      description: _descCtrl.text,
      imagePaths: paths,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.unauthorized) return;
    if (r.success) {
      setState(() {
        _feedback =
            'Your request has been submitted. We will get back to you soon.';
        _feedbackOk = true;
        _descCtrl.clear();
        _images = [];
      });
    } else {
      setState(() {
        _feedback = r.message ?? 'Failed to submit. Please try again.';
        _feedbackOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
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
                'Raise help ticket',
                style: TextStyle(
                  fontSize: wide ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Describe your problem and attach screenshots if needed.',
            style: TextStyle(color: CasinoUi.mutedGold(0.78), fontSize: 13),
          ),
        ),
        if (!_hasUser)
          Card(
            margin: EdgeInsets.zero,
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: CasinoUi.supportCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Please login to submit a support request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CasinoUi.mutedGold(0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: CasinoUi.supportCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: CasinoUi.inputDecorationSupport(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _subjectCtrl,
                      enabled: _hasUser,
                      style: const TextStyle(color: CasinoUi.lightGold, fontSize: 14, height: 1.2),
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Payment issue, Game error',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descCtrl,
                      enabled: _hasUser,
                      maxLines: 5,
                      style: const TextStyle(color: CasinoUi.lightGold, fontSize: 14, height: 1.2),
                      decoration: const InputDecoration(
                        labelText: 'Describe your problem *',
                        hintText: 'Explain your issue in detail...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Screenshots (optional, max 5 images)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CasinoUi.mutedGold(0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: (!_hasUser || _images.length >= 5)
                          ? null
                          : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _images.isEmpty
                            ? 'Choose images'
                            : 'Add more (${_images.length}/5)',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CasinoUi.lightGold,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.buttonPaddingH,
                          vertical: AppSpacing.buttonPaddingV,
                        ),
                        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_images.length, (i) {
                          return Chip(
                            label: Text(
                              'Image ${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onDeleted: () => _removeAt(i),
                          );
                        }),
                      ),
                    ],
                    if (_feedback != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: _feedbackOk
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _feedback!,
                            style: TextStyle(
                              color: _feedbackOk
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: (!_hasUser || _loading) ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF1A1408),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.buttonPaddingV,
                          horizontal: AppSpacing.buttonPaddingH,
                        ),
                        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1408),
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
