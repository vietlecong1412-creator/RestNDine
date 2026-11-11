import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/launcher.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

/// Đăng nhập. Đóng lại với kết quả `true` khi đã đăng nhập (kể cả sau khi xác thực OTP
/// hoặc đăng ký mới) để nơi mở màn hình làm tiếp hành động dở dang.
class LoginScreen extends StatefulWidget {
  /// Lý do cần đăng nhập, ví dụ "Đăng nhập để viết đánh giá".
  final String? message;

  const LoginScreen({super.key, this.message});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Sau lần gửi lỗi đầu tiên thì kiểm tra lại ngay khi người dùng sửa, để lỗi cũ không đứng mãi
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  // Chỉ điền sẵn tài khoản mẫu khi debug, bản release không chứa mật khẩu này
  final _emailCtrl = TextEditingController(text: kDebugMode ? 'customer1@gmail.com' : '');
  final _passCtrl = TextEditingController(text: kDebugMode ? 'Password@123' : '');
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Không hiện lại lỗi của lần đăng nhập/đăng ký trước
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(content: Text('Chào mừng trở lại, ${auth.user?.displayName ?? ''}!')),
      );
    } else if (auth.pendingOtpEmail != null) {
      // Tài khoản chưa xác thực email: server đã gửi OTP
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => OtpScreen(email: auth.pendingOtpEmail!)),
      );
      if (verified == true && mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _openRegister() async {
    final auth = context.read<AuthProvider>();
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted) return;
    if (done == true) {
      Navigator.of(context).pop(true);
    } else {
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(
                    leading: const Align(alignment: Alignment.centerLeft, child: BrandMark()),
                    title: 'Chào mừng trở lại',
                    subtitle: Text(
                      widget.message ??
                          'Đăng nhập để viết đánh giá, xem phân tích AI và nhắn tin trực tiếp với chủ quán.',
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  const FieldLabel('Email'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    decoration: const InputDecoration(
                      hintText: 'ten@vidu.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) =>
                        emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Vui lòng nhập email hợp lệ',
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Mật khẩu'),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Launcher.website(
                        context,
                        '${AppConfig.baseUrl}/Identity/Account/ForgotPassword',
                      ),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SubmitButton(label: 'Đăng nhập', loading: auth.isSubmitting, onPressed: _submit),
                  const SizedBox(height: 12),
                  AuthSwitchLink(prompt: 'Chưa có tài khoản?', action: 'Đăng ký ngay', onTap: _openRegister),
                  const SizedBox(height: 8),
                  Text(
                    'Bạn vẫn có thể xem địa điểm và đánh giá mà không cần đăng nhập.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall!.copyWith(color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
