import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_coordinator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/auth_widgets.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const String routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _showPassword = false;
  bool _isAbove18 = false;
  String? _error;
  bool _loading = false;

  /// Mirrors [Login.jsx] `DEVICE_LIMIT_REACHED` + `activeDevices` panel.
  String? _deviceLimitMessage;
  List<Map<String, dynamic>> _deviceLimitDevices = const [];
  String? _deviceActionLoadingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final msg = SessionCoordinator.instance.consumePendingLoginMessage();
      if (msg != null && msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String _formatLastSeen(Object? iso) {
    if (iso == null || iso.toString().trim().isEmpty) {
      return 'Last used: recently';
    }
    final ts = DateTime.tryParse(iso.toString())?.millisecondsSinceEpoch;
    if (ts == null) return 'Last used: recently';
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    final mins = diff ~/ 60000;
    if (mins < 1) return 'Last used: just now';
    if (mins < 60) return 'Last used: $mins min ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return 'Last used: $hrs hour${hrs > 1 ? 's' : ''} ago';
    final days = hrs ~/ 24;
    return 'Last used: $days day${days > 1 ? 's' : ''} ago';
  }

  Future<void> _persistSessionAndGoHome(Map<String, dynamic> userFromResponse) async {
    final previous = await AuthService.instance.getStoredUser();
    String? previousCreatedAt;
    if (previous != null) {
      previousCreatedAt = previous['createdAt']?.toString() ??
          previous['created_at']?.toString() ??
          previous['createdOn']?.toString();
    }
    final merged = Map<String, dynamic>.from(userFromResponse);
    merged['createdAt'] = merged['createdAt'] ??
        merged['created_at'] ??
        merged['createdOn'] ??
        previousCreatedAt;
    await AuthService.instance.saveUser(merged);
    SessionCoordinator.instance.startHeartbeatIfLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  /// Same flow as [Login.jsx] `handleSubmit` (and `handleLogoutDevice` + form retry).
  Future<void> _submit() async {
    setState(() {
      _error = null;
      _deviceLimitMessage = null;
      _deviceLimitDevices = const [];
    });

    if (!_isAbove18) {
      setState(() => _error = 'You must be above 18 years to continue');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final result = await AuthService.instance.login(
        phone: _phone.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;

      if (result.ok && result.user != null) {
        await _persistSessionAndGoHome(result.user!);
      } else if (result.code?.toUpperCase() == 'DEVICE_LIMIT_REACHED') {
        setState(() {
          _deviceLimitMessage =
              result.message.isNotEmpty ? result.message : 'Login pending, device limit reached';
          _deviceLimitDevices = result.activeDevices ?? const [];
          _error = null;
        });
      } else {
        setState(() => _error = result.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Network error. Please check if the server is running.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logoutRemoteDevice(String remoteDeviceId) async {
    if (remoteDeviceId.isEmpty || _loading || _deviceActionLoadingId != null) return;
    setState(() {
      _error = null;
      _deviceActionLoadingId = remoteDeviceId;
    });
    try {
      final res = await AuthService.instance.logoutDevice(
        phone: _phone.text.trim(),
        password: _password.text,
        deviceId: remoteDeviceId,
      );
      if (!mounted) return;
      if (!res.ok) {
        setState(() => _error = res.message.isNotEmpty ? res.message : 'Failed to log out device');
        return;
      }
      setState(() {
        _deviceLimitMessage = null;
        _deviceLimitDevices = const [];
      });
      await _submit();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Network error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _deviceActionLoadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final scheme = Theme.of(context).colorScheme;
    if (wide) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Row(
          children: [
            Expanded(
              child: Image.network(
                kAuthBannerUrl,
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHigh),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: scheme.surface,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _formSection(context, mobileStyle: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.authBackgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Image.network(
                  kAuthBannerUrl,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(height: 10),
                ),
                const SizedBox(height: 10),
                _formSection(context, mobileStyle: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formSection(BuildContext context, {required bool mobileStyle}) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: mobileStyle ? AppColors.neonGreen : AppColors.neonGreenDeep,
        );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: titleStyle,
            textAlign: mobileStyle ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to continue',
            style: TextStyle(
              color: mobileStyle ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: mobileStyle ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: _inputDecoration(
              label: 'Phone Number *',
              hint: '10-digit phone number',
              mobileStyle: mobileStyle,
              prefixIcon: Icons.phone_outlined,
            ),
            onChanged: (v) {
              setState(() {
                _error = null;
                _deviceLimitMessage = null;
                _deviceLimitDevices = const [];
              });
              final digits = v.replaceAll(RegExp(r'\D'), '');
              if (digits != v) {
                _phone.value = TextEditingValue(
                  text: digits,
                  selection: TextSelection.collapsed(offset: digits.length),
                );
              }
            },
            style: TextStyle(color: mobileStyle ? Colors.white : null),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Phone number is required';
              if (t.length != 10) return 'Enter a 10-digit phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            onChanged: (_) => setState(() {
              _error = null;
              _deviceLimitMessage = null;
              _deviceLimitDevices = const [];
            }),
            style: TextStyle(color: mobileStyle ? Colors.white : null),
            decoration: _inputDecoration(
              label: 'Password *',
              hint: 'Enter your password',
              mobileStyle: mobileStyle,
              prefixIcon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          AuthAgeCheckbox(
            value: _isAbove18,
            onChanged: (v) => setState(() {
              _isAbove18 = v ?? false;
              _error = null;
              _deviceLimitMessage = null;
              _deviceLimitDevices = const [];
            }),
            mobileStyle: mobileStyle,
          ),
          const SizedBox(height: 10),
          if (_error != null) AuthErrorBanner(message: _error!, mobileStyle: mobileStyle),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.ctaButtonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FilledButton(
              onPressed: (_loading || !_isAbove18 || _deviceActionLoadingId != null)
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFF04140C),
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.buttonPaddingV,
                  horizontal: AppSpacing.buttonPaddingH,
                ),
                minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                disabledBackgroundColor: Colors.grey.shade400.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.grey.shade600,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF04140C),
                      ),
                    )
                  : const Text('SIGN IN'),
            ),
          ),
          if (_deviceLimitMessage != null) ...[
            const SizedBox(height: 14),
            _DeviceLimitPanel(
              mobileStyle: mobileStyle,
              message: _deviceLimitMessage!,
              devices: _deviceLimitDevices,
              actionLoadingId: _deviceActionLoadingId,
              onLogoutDevice: _logoutRemoteDevice,
              formatLastSeen: _formatLastSeen,
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(SignupPage.routeName),
            child: Text(
              'Create an account',
              style: TextStyle(
                color: mobileStyle ? AppColors.neonGreen : AppColors.neonGreenDeep,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'By continuing, you agree to our Terms of Use and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: mobileStyle ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required bool mobileStyle,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    if (mobileStyle) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inputPaddingH,
          vertical: AppSpacing.inputPaddingV,
        ),
        prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade800.withValues(alpha: 0.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neonGreen, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade300),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      );
    }
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade600),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.neonGreenDeep, width: 2),
      ),
    );
  }
}

/// Same UX as [Login.jsx] device-limit block (below Sign In).
class _DeviceLimitPanel extends StatelessWidget {
  const _DeviceLimitPanel({
    required this.mobileStyle,
    required this.message,
    required this.devices,
    required this.actionLoadingId,
    required this.onLogoutDevice,
    required this.formatLastSeen,
  });

  final bool mobileStyle;
  final String message;
  final List<Map<String, dynamic>> devices;
  final String? actionLoadingId;
  final Future<void> Function(String deviceId) onLogoutDevice;
  final String Function(Object? iso) formatLastSeen;

  String _deviceIdOf(Map<String, dynamic> d) =>
      d['deviceId']?.toString() ?? d['id']?.toString() ?? d['_id']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final borderColor =
        mobileStyle ? Colors.grey.shade600.withValues(alpha: 0.55) : Colors.grey.shade300;
    final bg = mobileStyle ? Colors.grey.shade900.withValues(alpha: 0.35) : Colors.grey.shade50;
    final titleColor = mobileStyle ? Colors.white : const Color(0xFF1B3150);
    final subColor = mobileStyle ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can log out other devices to log in on this device',
            style: TextStyle(fontSize: 12, color: subColor),
          ),
          if (devices.isNotEmpty) const SizedBox(height: 12),
          for (final d in devices) ...[
            () {
              final id = _deviceIdOf(d);
              final busy = actionLoadingId == id;
              return Padding(
                key: ValueKey<String>('dl-$id'),
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: mobileStyle
                        ? Colors.grey.shade800.withValues(alpha: 0.45)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor.withValues(alpha: 0.85)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['deviceName']?.toString() ?? 'Active Device',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: mobileStyle ? Colors.white : const Color(0xFF1B3150),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatLastSeen(d['lastSeenAt']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: (actionLoadingId != null || id.isEmpty)
                              ? null
                              : () => onLogoutDevice(id),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: mobileStyle ? AppColors.neonGreen : AppColors.neonGreenDeep,
                            foregroundColor: mobileStyle ? const Color(0xFF04140C) : Colors.white,
                          ),
                          child: busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: mobileStyle ? const Color(0xFF04140C) : Colors.white,
                                  ),
                                )
                              : const Text('Log out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ],
        ],
      ),
    );
  }
}
