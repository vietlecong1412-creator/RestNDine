import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';

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
  static const _length = 6;

  final _codeCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;
  bool _resending = false;
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
    _focus.dispose();
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

  Future<void> _submit() async {
    if (_submitting) return;
    if (_codeCtrl.text.length != _length) {
      setState(() => _errorMessage = 'Mã OTP gồm đúng 6 chữ số.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().verifyOtp(widget.email, _codeCtrl.text);
    if (!mounted) return;

    if (error == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Xác thực thành công! Chào mừng bạn đến với RestNDine.')),
      );
    } else {
      setState(() {
        _submitting = false;
        _errorMessage = error;
      });
      _codeCtrl.clear();
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final result = await context.read<AuthProvider>().resendOtp(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);

    if (result['success'] == true) {
      _codeCtrl.clear();
      setState(() => _errorMessage = null);
      _startCountdown(_resendCooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi mã mới. Kiểm tra hộp thư (cả mục Spam) nhé.')),
      );
    } else {
      final retry = result['retryAfterSeconds'];
      if (retry is int && retry > 0) _startCountdown(retry);
      setState(() => _errorMessage = result['message'] as String?);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(
                leading: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.mark_email_read_outlined, color: context.scheme.onPrimaryContainer, size: 28),
                  ),
                ),
                title: 'Xác thực email',
                subtitle: Text.rich(
                  TextSpan(
                    text: 'Nhập mã 6 số vừa được gửi tới ',
                    children: [
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      const TextSpan(text: '. Mã có hiệu lực trong 10 phút.'),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              _OtpInput(
                controller: _codeCtrl,
                focusNode: _focus,
                length: _length,
                hasError: _errorMessage != null,
                enabled: !_submitting,
                onCompleted: _submit,
              ),
              const SizedBox(height: 28),
              SubmitButton(label: 'Xác thực', loading: _submitting, onPressed: _submit),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Chưa nhận được mã?', style: context.text.bodyMedium!.copyWith(color: colors.textSecondary)),
                  TextButton(
                    onPressed: _resendWait > 0 || _resending ? null : _resend,
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                    child: Text(_resendWait > 0 ? 'Gửi lại sau ${_resendWait}s' : 'Gửi lại mã'),
                  ),
                ],
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                  child: const Text('Dùng email khác'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6 ô mã OTP. Một ô nhập ẩn phía trên nhận bàn phím, dán và tự điền mã từ hệ thống.
class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final VoidCallback onCompleted;

  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;

    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.field,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(
                            width: 1.6,
                            color: hasError
                                ? scheme.error
                                : focusNode.hasFocus && i == text.length.clamp(0, length - 1)
                                    ? scheme.primary
                                    : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: context.text.headlineSmall,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: length,
                showCursor: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (v) {
                  if (v.length == length) onCompleted();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
