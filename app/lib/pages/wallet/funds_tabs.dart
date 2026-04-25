import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/bank_details_service.dart';
import '../../services/payments_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../../theme/app_spacing.dart';

/// Tighter fields for funds screens (casino backdrop).
InputDecoration fundInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
}) {
  const neutral = Color(0x33FFFFFF);
  const focused = Color(0x66FFFFFF);
  return InputDecoration(
    isDense: true,
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: CasinoUi.fieldFill,
    labelStyle: TextStyle(color: CasinoUi.mutedGold(0.82), fontSize: 12.5),
    hintStyle: TextStyle(color: CasinoUi.mutedGold(0.38), fontSize: 13),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 11,
      vertical: AppSpacing.inputPaddingV,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: neutral),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: neutral),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: focused, width: 2),
    ),
  );
}

const _fundFieldStyle = TextStyle(color: CasinoUi.lightGold, fontSize: 14, height: 1.2);

/// Add fund — [frontend/src/pages/funds/AddFund.jsx]
class AddFundTab extends StatefulWidget {
  const AddFundTab({super.key, this.onSubmittedGoHistory});

  final VoidCallback? onSubmittedGoHistory;

  @override
  State<AddFundTab> createState() => _AddFundTabState();
}

class _AddFundTabState extends State<AddFundTab> {
  Map<String, dynamic>? _config;
  final _amountCtrl = TextEditingController();
  final _utrCtrl = TextEditingController();
  int _step = 1;
  bool _addCashLoading = false;
  bool _submitting = false;
  String? _pickedPath;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _utrCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final r = await PaymentsService.instance.fetchConfig();
    if (mounted && r.success && r.data != null) setState(() => _config = r.data);
  }

  num get _min => num.tryParse(_config?['minDeposit']?.toString() ?? '') ?? 100;
  num get _max => num.tryParse(_config?['maxDeposit']?.toString() ?? '') ?? 50000;

  String _qrUrl() {
    final upiId = _config?['upiId']?.toString() ?? '';
    final upiName = _config?['upiName']?.toString() ?? 'Golden Games';
    final amt = num.tryParse(_amountCtrl.text);
    final hasAmt = amt != null && amt > 0;
    final pay = StringBuffer('upi://pay?pa=$upiId&pn=${Uri.encodeComponent(upiName)}');
    if (hasAmt) pay.write('&am=$amt');
    pay.write('&cu=INR');
    final data = Uri.encodeComponent(pay.toString());
    return 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$data';
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (x == null) return;
    final len = await x.length();
    if (len > 5 * 1024 * 1024) {
      setState(() => _err = 'File size must be less than 5MB');
      return;
    }
    setState(() {
      _pickedPath = x.path;
      _err = '';
    });
  }

  Future<void> _submit() async {
    setState(() => _err = '');
    final numAmount = num.tryParse(_amountCtrl.text);
    if (numAmount == null || numAmount < _min || numAmount > _max) {
      setState(() => _err = 'Amount must be between ₹$_min and ₹$_max');
      return;
    }
    final utr = _utrCtrl.text.trim();
    if (utr.isEmpty) {
      setState(() => _err = 'Please enter UTR / Transaction ID');
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9]{10,30}$').hasMatch(utr)) {
      setState(() => _err = 'UTR / Transaction ID must be 10-30 letters or digits');
      return;
    }
    if (_pickedPath == null) {
      setState(() => _err = 'Please upload payment screenshot');
      return;
    }
    setState(() => _submitting = true);
    final res = await PaymentsService.instance.submitDeposit(
      amount: numAmount.toDouble(),
      upiTransactionId: utr,
      screenshotPath: _pickedPath!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      await WalletService.instance.refreshBalanceInStorage();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Request Submitted!'),
          content: Text('Amount ₹${NumberFormat.decimalPattern('en_IN').format(numAmount)}\n\n'
              'Please wait for admin approval.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onSubmittedGoHistory?.call();
              },
              child: const Text('View History'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      setState(() {
        _amountCtrl.clear();
        _utrCtrl.clear();
        _pickedPath = null;
        _step = 1;
      });
    } else {
      setState(() => _err = res.message ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _err,
                style: TextStyle(color: Colors.red.shade300, fontSize: 13),
              ),
            ),
          if (_step == 1) _buildStep1() else _buildStep2(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.instance.getStoredUser(),
      builder: (context, snap) {
        final u = snap.data;
        final bal = num.tryParse(u?['balance']?.toString() ?? '') ??
            num.tryParse(u?['walletBalance']?.toString() ?? '') ??
            0;
        final name = u?['username']?.toString() ?? u?['name']?.toString() ?? 'User';
        return Column(
          children: [
            Card(
              color: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: CasinoUi.supportCardShape(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: Text(
                      'SinglePana',
                      style: TextStyle(color: CasinoUi.mutedGold(0.65), fontSize: 12),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: AppColors.navy,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          child: const Text('₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          NumberFormat.decimalPattern('en_IN').format(bal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: CasinoUi.lightGold, fontSize: 13),
                        ),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: Colors.green.shade400),
                            const SizedBox(width: 4),
                            Icon(Icons.circle, size: 8, color: AppColors.goldMuted),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: _fundFieldStyle,
              decoration: fundInputDecoration(
                context,
                label: 'Enter Amount',
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 16,
                ),
                constraints: const BoxConstraints(minHeight: 56),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [200, 500, 1000, 2000].map((a) {
                final sel = _amountCtrl.text == '$a';
                return ChoiceChip(
                  label: Text('$a', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: sel,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  selectedColor: Colors.white.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: CasinoUi.neutralShellBorderColor(alpha: sel ? 0.38 : 0.14),
                  ),
                  onSelected: (_) => setState(() => _amountCtrl.text = '$a'),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _addCashLoading
                  ? null
                  : () async {
                      final n = num.tryParse(_amountCtrl.text);
                      if (n == null || n < _min || n > _max) {
                        setState(() => _err = 'Amount must be between ₹$_min and ₹$_max');
                        return;
                      }
                      setState(() {
                        _err = '';
                        _addCashLoading = true;
                      });
                      await Future<void>.delayed(const Duration(milliseconds: 300));
                      if (mounted) {
                        setState(() {
                          _addCashLoading = false;
                          _step = 2;
                        });
                      }
                    },
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
              ),
              child: Text(_addCashLoading ? 'Loading...' : 'Add Cash'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStep2() {
    final upiId = _config?['upiId']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Amount',
                  style: TextStyle(color: CasinoUi.mutedGold(0.7), fontSize: 12),
                ),
                Text(
                  '₹${_amountCtrl.text}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CasinoUi.lightGold,
                  ),
                ),
              ],
            ),
            OutlinedButton(
              onPressed: () => setState(() => _step = 1),
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
              child: const Text('Back'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Payment Details',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: CasinoUi.lightGold,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: upiId.isEmpty
              ? const CircularProgressIndicator(color: AppColors.gold)
              : Image.network(_qrUrl(), width: 160, height: 160),
        ),
        const SizedBox(height: 8),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 0,
          title: Text('UPI ID', style: TextStyle(color: CasinoUi.mutedGold(0.75), fontSize: 12)),
          subtitle: Text(
            upiId.isEmpty ? '...' : upiId,
            style: const TextStyle(fontFamily: 'monospace', color: CasinoUi.lightGold, fontSize: 13),
          ),
          trailing: IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.copy, color: CasinoUi.lightGold, size: 20),
            onPressed: upiId.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: upiId));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
                  },
          ),
        ),
        TextField(
          controller: _utrCtrl,
          keyboardType: TextInputType.text,
          style: _fundFieldStyle,
          decoration: fundInputDecoration(context, label: 'UTR / Transaction ID'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.image, size: 18, color: CasinoUi.lightGold),
          label: Text(_pickedPath == null ? 'Upload screenshot' : 'Change screenshot'),
          style: OutlinedButton.styleFrom(
            foregroundColor: CasinoUi.lightGold,
            side: BorderSide(color: CasinoUi.neutralShellBorderColor(alpha: 0.22)),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonPaddingV,
              horizontal: AppSpacing.buttonPaddingH,
            ),
            minimumSize: const Size(0, AppSpacing.buttonMinHeight),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (_pickedPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Image selected',
              style: TextStyle(color: AppColors.accentEmerald, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _submitting ? null : _submit,
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
          ),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1408)),
                )
              : const Text('Submit Deposit Request'),
        ),
      ],
    );
  }
}

/// Withdraw — [WithdrawFund.jsx]
class WithdrawFundTab extends StatefulWidget {
  const WithdrawFundTab({super.key});

  @override
  State<WithdrawFundTab> createState() => _WithdrawFundTabState();
}

class _WithdrawFundTabState extends State<WithdrawFundTab> {
  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _accounts = [];
  num _wallet = 0;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _bankId;
  bool _loading = true;
  bool _submitting = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final c = await PaymentsService.instance.fetchConfig();
    final b = await BankDetailsService.instance.listAccounts();
    final w = await WalletService.instance.fetchBalance();
    if (!mounted) return;
    if (c.success && c.data != null) _config = c.data;
    if (b.success) {
      _accounts = b.data;
      Map<String, dynamic>? def;
      for (final a in _accounts) {
        if (a['isDefault'] == true) {
          def = a;
          break;
        }
      }
      if (def != null) {
        _bankId = def['_id']?.toString();
      } else if (_accounts.isNotEmpty) {
        _bankId = _accounts.first['_id']?.toString();
      }
    }
    if (w.success && w.balance != null) _wallet = w.balance!;
    setState(() => _loading = false);
  }

  num get _minW => num.tryParse(_config?['minWithdrawal']?.toString() ?? '') ?? 500;
  num get _maxW => num.tryParse(_config?['maxWithdrawal']?.toString() ?? '') ?? 25000;

  Future<void> _submit() async {
    setState(() => _err = '');
    final n = num.tryParse(_amountCtrl.text);
    if (n == null || n < _minW || n > _maxW) {
      setState(() => _err = 'Amount must be between ₹$_minW and ₹$_maxW');
      return;
    }
    if (n > _wallet) {
      setState(() => _err = 'Insufficient wallet balance');
      return;
    }
    if (_bankId == null || _bankId!.isEmpty) {
      setState(() => _err = 'Please select a bank account');
      return;
    }
    setState(() => _submitting = true);
    final res = await PaymentsService.instance.submitWithdraw(
      amount: n.toDouble(),
      bankDetailId: _bankId!,
      userNote: _noteCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submitted'),
          content: const Text('Your withdrawal request has been submitted.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      await WalletService.instance.refreshBalanceInStorage();
      _amountCtrl.clear();
      _noteCtrl.clear();
      await _refresh();
    } else {
      setState(() => _err = res.message ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: CasinoUi.supportCardShape(),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              title: Text(
                'Available balance',
                style: TextStyle(color: CasinoUi.mutedGold(0.75), fontSize: 12),
              ),
              trailing: Text(
                '₹${_wallet.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: CasinoUi.lightGold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Min: ₹$_minW | Max: ₹$_maxW',
            style: TextStyle(color: CasinoUi.mutedGold(0.55), fontSize: 12),
          ),
          if (_err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(_err, style: TextStyle(color: Colors.red.shade300, fontSize: 13)),
            ),
          if (_accounts.isEmpty)
            Card(
              color: Colors.transparent,
              elevation: 0,
              shape: CasinoUi.supportCardShape(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Add a bank account under Bank Detail before withdrawing.',
                  style: TextStyle(color: CasinoUi.mutedGold(0.85), fontSize: 13),
                ),
              ),
            ),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: _fundFieldStyle,
            decoration: fundInputDecoration(
              context,
              label: 'Amount (₹)',
            ).copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 15,
              ),
              constraints: const BoxConstraints(minHeight: 54),
            ),
          ),
          const SizedBox(height: 10),
          if (_accounts.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_accounts.map((a) => a['_id']).join()),
              initialValue: () {
                var id = _bankId;
                if (id != null && !_accounts.any((a) => a['_id']?.toString() == id)) {
                  id = _accounts.first['_id']?.toString();
                }
                return id;
              }(),
              isDense: true,
              isExpanded: true,
              dropdownColor: CasinoUi.fieldFill,
              style: _fundFieldStyle,
              decoration: fundInputDecoration(context, label: 'Bank account'),
              items: _accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a['_id']?.toString(),
                      child: Text(
                        '${a['accountHolderName']} — ${a['bankName'] ?? a['upiId'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: _fundFieldStyle,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _bankId = v),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            style: _fundFieldStyle,
            maxLines: 2,
            decoration: fundInputDecoration(context, label: 'Note (optional)').copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _accounts.isEmpty || _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.buttonPaddingV,
                horizontal: AppSpacing.buttonPaddingH,
              ),
              minimumSize: const Size(0, AppSpacing.buttonMinHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Request withdrawal'),
          ),
        ],
      ),
    );
  }
}

/// Bank details — [BankDetail.jsx]
class BankDetailTab extends StatefulWidget {
  const BankDetailTab({super.key});

  @override
  State<BankDetailTab> createState() => _BankDetailTabState();
}

class _BankDetailTabState extends State<BankDetailTab> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _showForm = false;
  String? _editingId;
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _bankName = TextEditingController();
  final _upi = TextEditingController();
  String _accountType = 'savings';
  bool _submitting = false;
  String _err = '';
  String _info = '';

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _ifsc.dispose();
    _bankName.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await BankDetailsService.instance.listAccounts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) _list = r.data;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _resetForm() {
    setState(() {
      _holder.clear();
      _account.clear();
      _ifsc.clear();
      _bankName.clear();
      _upi.clear();
      _accountType = 'savings';
      _editingId = null;
      _showForm = false;
      _err = '';
    });
  }

  void _fill(Map<String, dynamic> a) {
    setState(() {
      _holder.text = a['accountHolderName']?.toString() ?? '';
      _account.text = a['accountNumber']?.toString() ?? '';
      _ifsc.text = a['ifscCode']?.toString() ?? '';
      _bankName.text = a['bankName']?.toString() ?? '';
      _upi.text = a['upiId']?.toString() ?? '';
      _accountType = a['accountType']?.toString() ?? 'savings';
      _editingId = a['_id']?.toString();
      _showForm = true;
      _err = '';
    });
  }

  Future<void> _save() async {
    setState(() {
      _err = '';
      _info = '';
    });
    if (_holder.text.trim().isEmpty) {
      setState(() => _err = 'Account holder name is required');
      return;
    }
    if (_upi.text.trim().isEmpty && (_account.text.trim().isEmpty || _ifsc.text.trim().isEmpty)) {
      setState(() => _err = 'Provide UPI ID or account number + IFSC');
      return;
    }
    final payload = {
      'accountHolderName': _holder.text.trim(),
      'accountNumber': _account.text.trim(),
      'ifscCode': _ifsc.text.trim(),
      'bankName': _bankName.text.trim(),
      'upiId': _upi.text.trim(),
      'accountType': _accountType,
    };
    setState(() => _submitting = true);
    final r = _editingId == null
        ? await BankDetailsService.instance.createAccount(payload)
        : await BankDetailsService.instance.updateAccount(_editingId!, payload);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (r.success) {
      _resetForm();
      setState(() => _info = 'Saved');
      await _load();
    } else {
      setState(() => _err = r.message ?? 'Failed');
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await BankDetailsService.instance.deleteAccount(id);
    if (r.success) await _load();
    if (mounted && !r.success) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message ?? 'Error')));
  }

  Future<void> _default(String id) async {
    await BankDetailsService.instance.setDefault(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CasinoUi.neutralShellBorderColor(alpha: 0.16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_list.length}/5 accounts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: CasinoUi.lightGold,
                    fontSize: 13,
                  ),
                ),
                if (_list.length < 5 && !_showForm)
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _showForm = true;
                      _editingId = null;
                      _holder.clear();
                      _account.clear();
                      _ifsc.clear();
                      _bankName.clear();
                      _upi.clear();
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Account'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF1A1408),
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
            ),
          ),
          const SizedBox(height: 8),
          if (_err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_err, style: TextStyle(color: Colors.red.shade300, fontSize: 13)),
            ),
          if (_info.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_info, style: TextStyle(color: AppColors.accentEmerald, fontSize: 13)),
            ),
          if (_showForm) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CasinoUi.neutralShellBorderColor(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bank Account Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: CasinoUi.lightGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _holder,
                    style: _fundFieldStyle,
                    decoration: fundInputDecoration(context, label: 'Account holder *'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _upi,
                    style: _fundFieldStyle,
                    decoration: fundInputDecoration(context, label: 'UPI ID'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: CasinoUi.neutralShellBorderColor(alpha: 0.14), height: 1),
                  ),
                  TextField(
                    controller: _account,
                    style: _fundFieldStyle,
                    decoration: fundInputDecoration(context, label: 'Account number'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ifsc,
                    style: _fundFieldStyle,
                    decoration: fundInputDecoration(context, label: 'IFSC'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bankName,
                    style: _fundFieldStyle,
                    decoration: fundInputDecoration(context, label: 'Bank name'),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('acct_$_accountType'),
                    initialValue: _accountType,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: CasinoUi.fieldFill,
                    style: _fundFieldStyle,
                    decoration: fundInputDecoration(context, label: 'Account type'),
                    items: const [
                      DropdownMenuItem(value: 'savings', child: Text('Savings')),
                      DropdownMenuItem(value: 'current', child: Text('Current')),
                    ],
                    onChanged: (v) => setState(() => _accountType = v ?? 'savings'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _submitting ? null : _resetForm,
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
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting ? null : _save,
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
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1408)),
                                )
                              : Text(_editingId == null ? 'Save Account' : 'Update Account'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ..._list.map((a) {
            final id = a['_id']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: CasinoUi.neutralShellBorderColor(alpha: 0.16)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['accountHolderName']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: CasinoUi.lightGold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a['bankName'] ?? ''} ${a['accountNumber'] != null ? '****${a['accountNumber'].toString().length > 4 ? a['accountNumber'].toString().substring(a['accountNumber'].toString().length - 4) : ''}' : ''}',
                      style: TextStyle(color: CasinoUi.mutedGold(0.78), fontSize: 12),
                    ),
                    if (a['upiId'] != null && a['upiId'].toString().isNotEmpty)
                      Text(
                        'UPI: ${a['upiId']}',
                        style: TextStyle(color: CasinoUi.mutedGold(0.78), fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    if (a['isDefault'] == true)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          'Default',
                          style: const TextStyle(fontSize: 10, color: CasinoUi.lightGold),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(color: CasinoUi.neutralShellBorderColor(alpha: 0.2)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _fill(a)),
                          style: TextButton.styleFrom(
                            foregroundColor: CasinoUi.lightGold,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Edit', style: TextStyle(fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: () => _default(id),
                          style: TextButton.styleFrom(
                            foregroundColor: CasinoUi.mutedGold(0.85),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Set default', style: TextStyle(fontSize: 13)),
                        ),
                        TextButton(
                          onPressed: () => _delete(id),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentRose,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Delete', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Deposit history — [AddFundHistory.jsx]
class AddFundHistoryTab extends StatefulWidget {
  const AddFundHistoryTab({super.key});

  @override
  State<AddFundHistoryTab> createState() => _AddFundHistoryTabState();
}

class _AddFundHistoryTabState extends State<AddFundHistoryTab> {
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all';
  bool _loading = true;

  Color _amountColorForStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'approved') return Colors.green.shade600;
    if (s == 'rejected') return Colors.red.shade500;
    return Colors.white;
  }

  String? _rejectedReason(Map<String, dynamic> d) {
    final candidates = <String?>[
      d['rejectedReason']?.toString(),
      d['rejectionReason']?.toString(),
      d['reason']?.toString(),
      d['adminRemark']?.toString(),
      d['adminRemarks']?.toString(),
      d['remark']?.toString(),
      d['remarks']?.toString(),
      d['message']?.toString(),
    ];
    for (final raw in candidates) {
      final txt = raw?.trim();
      if (txt != null && txt.isNotEmpty && txt.toLowerCase() != 'null') {
        return txt;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await PaymentsService.instance.fetchMyDeposits();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) _items = r.data;
    });
  }

  Future<void> _openShot(String? url) async {
    if (url == null || url.isEmpty) return;
    final u = await AuthService.instance.getStoredUser();
    final uid = u?['id'] ?? u?['_id'];
    String full = url;
    if (!url.startsWith('http')) {
      full = '$kApiBaseUrl${url.startsWith('/') ? '' : '/'}$url${uid != null ? '?userId=$uid' : ''}';
    }
    final uri = Uri.tryParse(full);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    final filtered = _filter == 'all' ? _items : _items.where((d) => d['status'] == _filter).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _fChip('all', 'All'),
                _fChip('pending', 'Pending'),
                _fChip('approved', 'OK'),
                _fChip('rejected', 'No'),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text('No deposits', style: TextStyle(color: CasinoUi.mutedGold(0.65))),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final d = filtered[i];
                final st = d['status']?.toString() ?? '';
                final stNorm = st.trim().toLowerCase();
                final rejectedReason = _rejectedReason(d);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: Colors.transparent,
                  elevation: 0,
                  shape: CasinoUi.supportCardShape(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '₹${d['amount']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _amountColorForStatus(st),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (d['screenshotUrl'] != null)
                              TextButton(
                                onPressed: () => _openShot(d['screenshotUrl']?.toString()),
                                style: TextButton.styleFrom(
                                  foregroundColor: CasinoUi.lightGold,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Screenshot', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${d['createdAt']} · $st',
                          style: TextStyle(
                            color: CasinoUi.mutedGold(0.68),
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                        if (stNorm == 'rejected' && rejectedReason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reason: $rejectedReason',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              childCount: filtered.length,
            ),
          ),
      ],
    );
  }

  Widget _fChip(String key, String label) {
    final on = _filter == key;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      selected: on,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      selectedColor: Colors.white.withValues(alpha: 0.14),
      side: BorderSide(
        color: CasinoUi.neutralShellBorderColor(alpha: on ? 0.38 : 0.14),
      ),
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}

/// Withdrawal history — [WithdrawFundHistory.jsx]
class WithdrawFundHistoryTab extends StatefulWidget {
  const WithdrawFundHistoryTab({super.key});

  @override
  State<WithdrawFundHistoryTab> createState() => _WithdrawFundHistoryTabState();
}

class _WithdrawFundHistoryTabState extends State<WithdrawFundHistoryTab> {
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await PaymentsService.instance.fetchMyWithdrawals();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) _items = r.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    final filtered = _filter == 'all' ? _items : _items.where((w) => w['status'] == _filter).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _fChip('all', 'All'),
                _fChip('pending', 'Pending'),
                _fChip('approved', 'OK'),
                _fChip('rejected', 'No'),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text('No withdrawals', style: TextStyle(color: CasinoUi.mutedGold(0.65))),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final w = filtered[i];
                final st = w['status']?.toString() ?? '';
                final bank = w['bankDetailId'];
                String? bankLine;
                if (bank is Map) {
                  bankLine = bank['accountHolderName']?.toString();
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  color: Colors.transparent,
                  elevation: 0,
                  shape: CasinoUi.supportCardShape(),
                  child: ListTile(
                    dense: false,
                    visualDensity: VisualDensity.standard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minVerticalPadding: 8,
                    title: Text(
                      '₹${w['amount']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: CasinoUi.lightGold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${w['createdAt']}\n$st${bankLine != null ? '\n$bankLine' : ''}',
                      style: TextStyle(color: CasinoUi.mutedGold(0.6), fontSize: 11, height: 1.25),
                    ),
                  ),
                );
              },
              childCount: filtered.length,
            ),
          ),
      ],
    );
  }

  Widget _fChip(String key, String label) {
    final on = _filter == key;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      selected: on,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      selectedColor: Colors.white.withValues(alpha: 0.14),
      side: BorderSide(
        color: CasinoUi.neutralShellBorderColor(alpha: on ? 0.38 : 0.14),
      ),
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}
