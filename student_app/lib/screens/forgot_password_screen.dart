import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

enum ForgotPasswordStep {
  requestEmail,
  verifyAndReset,
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  ForgotPasswordStep _currentStep = ForgotPasswordStep.requestEmail;

  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _successMessage;
  String? _maskedEmail;

  int _resendCooldown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() => _resendCooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 1) {
        setState(() => _resendCooldown--);
      } else {
        setState(() => _resendCooldown = 0);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _requestResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your student email address.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final authProv = context.read<AuthProvider>();
      final res = await authProv.forgotPassword(email);
      if (!mounted) return;

      final data = res['data'] is Map ? res['data'] as Map : null;
      setState(() {
        _maskedEmail = data?['email']?.toString() ?? email;
        _currentStep = ForgotPasswordStep.verifyAndReset;
        _successMessage = 'A 6-digit reset code has been sent to your email.';
      });
      _startCooldownTimer();

      // Focus first OTP input field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _otpFocusNodes.isNotEmpty) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = humanizeError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _resending) return;

    final email = _emailController.text.trim();
    setState(() {
      _resending = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final authProv = context.read<AuthProvider>();
      await authProv.resendResetOtp(email: email);
      if (!mounted) return;
      _startCooldownTimer();
      setState(() {
        _successMessage = 'A new 6-digit reset code has been sent to your email.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = humanizeError(e));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Pasted code
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6; i++) {
        if (i < digits.length) {
          _otpControllers[i].text = digits[i];
        }
      }
      final nextIndex = digits.length < 6 ? digits.length : 5;
      _otpFocusNodes[nextIndex].requestFocus();
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
    }
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    final otp = _currentOtp;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits of the reset code.');
      return;
    }
    if (newPassword.isEmpty) {
      setState(() => _error = 'Please enter a new password.');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _error = 'New password and confirmation do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final authProv = context.read<AuthProvider>();
      await authProv.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please login with your new password.'),
          backgroundColor: AppTheme.emerald,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pop(email);
    } catch (e) {
      if (mounted) {
        setState(() => _error = humanizeError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _currentStep == ForgotPasswordStep.requestEmail ? 'Forgot Password' : 'Reset Password',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == ForgotPasswordStep.verifyAndReset) {
              setState(() {
                _currentStep = ForgotPasswordStep.requestEmail;
                _error = null;
                _successMessage = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: _currentStep == ForgotPasswordStep.requestEmail
                ? _buildRequestEmailStep()
                : _buildVerifyAndResetStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand / Key Icon Badge
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Center(
            child: Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 30),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppTheme.navy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your registered student email address. We will send you a 6-digit verification code to reset your password.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 32),

        // Email Field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Student Email',
            hintText: 'student@dhsgu.ac.in',
            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.muted, size: 20),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          _buildErrorBox(_error!),
        ],

        const SizedBox(height: 28),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _busy ? null : _requestResetCode,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'SEND RESET CODE',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyAndResetStep() {
    final displayEmail = _maskedEmail ?? _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Center(
            child: Icon(Icons.mark_email_read_outlined, color: AppTheme.primary, size: 28),
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Reset Your Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppTheme.navy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code sent to $displayEmail and set your new password.',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),

        // 6-digit OTP Box
        const Text(
          'Verification Code',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 44,
              height: 52,
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2.0),
                  ),
                ),
                onChanged: (val) => _onDigitChanged(i, val),
                onTap: () {
                  _otpControllers[i].selection = TextSelection.fromPosition(
                    TextPosition(offset: _otpControllers[i].text.length),
                  );
                },
              ),
            );
          }),
        ),

        // Resend Timer Row
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = ForgotPasswordStep.requestEmail;
                  _error = null;
                  _successMessage = null;
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Change email', style: TextStyle(fontSize: 13, color: AppTheme.muted)),
            ),
            if (_resendCooldown > 0)
              Text(
                'Resend in ${_resendCooldown}s',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              )
            else
              TextButton.icon(
                onPressed: _resending ? null : _resendCode,
                icon: _resending
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // New Password Field
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'New Password',
            hintText: 'At least 8 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.muted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.muted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password Field
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            hintText: 'Re-enter your new password',
            prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppTheme.muted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.muted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),

        // Success / Error Message
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: AppTheme.emerald, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 16),
          _buildErrorBox(_error!),
        ],

        const SizedBox(height: 28),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _busy ? null : _submitReset,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'RESET PASSWORD',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.coral, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.coral,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
