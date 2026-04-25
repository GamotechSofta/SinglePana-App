import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_coordinator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/auth_widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  static const String routeName = '/signup';

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _showPassword = false;
  bool _isAbove18 = false;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
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
      final result = await AuthService.instance.register(
        phone: _phone.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;

      if (result.ok && result.user != null) {
        final token = result.user!['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await AuthService.instance.saveUser(result.user!);
          SessionCoordinator.instance.startHeartbeatIfLoggedIn();
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          return;
        }
      }

      if (result.ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'Account created. Please sign in.')),
        );
        Navigator.of(context).pop();
        return;
      }

      setState(() => _error = result.message);
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

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create account',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: wide ? AppColors.navy : AppColors.gold,
                ),
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Sign up with your phone number',
            style: TextStyle(
              color: wide ? Colors.grey.shade600 : Colors.grey.shade400,
              fontSize: 14,
            ),
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (_error != null) AuthErrorBanner(message: _error!, mobileStyle: !wide),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: _decoration(
              label: 'Phone Number *',
              hint: '10-digit phone number',
              wide: wide,
              icon: Icons.phone_outlined,
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
            decoration: _decoration(
              label: 'Password *',
              hint: 'Choose a password',
              wide: wide,
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Use at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: !_showPassword,
            decoration: _decoration(
              label: 'Confirm password *',
              hint: 'Repeat password',
              wide: wide,
              icon: Icons.lock_outline,
            ),
            validator: (v) {
              if (v != _password.text) return 'Passwords do not match';
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
            mobileStyle: !wide,
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
                  : const Text('SIGN UP'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Already have an account? Sign in',
              style: TextStyle(
                color: wide ? AppColors.neonGreenDeep : AppColors.neonGreen,
              ),
            ),
          ),
        ],
      ),
    );

    final scheme = Theme.of(context).colorScheme;
    if (wide) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          elevation: 0,
          foregroundColor: scheme.primary,
        ),
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
                      child: form,
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.gold,
        title: const Text('Sign up'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.authBackgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: form,
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required bool wide,
    required IconData icon,
    Widget? suffix,
  }) {
    if (wide) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inputPaddingH,
          vertical: AppSpacing.inputPaddingV,
        ),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.neonGreenDeep, width: 2),
        ),
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
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
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
}
