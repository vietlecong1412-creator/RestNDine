import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Nhập mã OTP 6 số được gửi qua email để xác thực tài khoản.
/// Thành công → đã đăng nhập, màn hình đóng lại với kết quả `true`.
class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _resendCooldown = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;
  int _resendWait = _resendCooldown; // server vừa gửi mã khi đăng ký/đăng nhập
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown(_resendCooldown);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendWait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendWait--);
      if (_resendWait <= 0) t.cancel();
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().verifyOtp(widget.email, _codeCtrl.text.trim());
    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xác thực thành công! Chào mừng bạn đến với RestNDine.'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _errorMessage = error;
      });
    }
  }

  void _resend() async {
    final result = await context.read<AuthProvider>().resendOtp(widget.email);
    if (!mounted) return;

    if (result['success'] == true) {
      _codeCtrl.clear();
      setState(() => _errorMessage = null);
      _startCountdown(_resendCooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi lại mã OTP mới vào email của bạn.'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    } else {
      final retry = result['retryAfterSeconds'];
      if (retry is int && retry > 0) _startCountdown(retry);
      setState(() => _errorMessage = result['message'] as String?);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppTheme.primaryColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Xác thực email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Nhập mã gồm 6 chữ số đã được gửi tới ',
                    children: [
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const TextSpan(text: '. Mã có hiệu lực trong 10 phút.'),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Text('Mã OTP', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 12),
                  decoration: const InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                  ),
                  validator: (v) => v == null || v.length != 6 ? 'Mã OTP phải gồm đúng 6 chữ số' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Xác thực', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa nhận được mã? ', style: TextStyle(color: AppTheme.textSecondary)),
                    _resendWait > 0
                        ? Text(
                            'Gửi lại sau ${_resendWait}s',
                            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                          )
                        : GestureDetector(
                            onTap: _resend,
                            child: const Text(
                              'Gửi lại mã',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
