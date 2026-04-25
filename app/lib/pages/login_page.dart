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

  Future<void> _submit() async {
    setState(() => _error = null);

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
        final previous = await AuthService.instance.getStoredUser();
        String? previousCreatedAt;
        if (previous != null) {
          previousCreatedAt = previous['createdAt']?.toString() ??
              previous['created_at']?.toString() ??
              previous['createdOn']?.toString();
        }
        final merged = Map<String, dynamic>.from(result.user!);
        merged['createdAt'] = merged['createdAt'] ??
            merged['created_at'] ??
            merged['createdOn'] ??
            previousCreatedAt;
        await AuthService.instance.saveUser(merged);
        SessionCoordinator.instance.startHeartbeatIfLoggedIn();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
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
          if (_error != null) AuthErrorBanner(message: _error!, mobileStyle: mobileStyle),
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
            }),
            mobileStyle: mobileStyle,
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.ctaButtonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FilledButton(
              onPressed: (_loading || !_isAbove18) ? null : _submit,
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
