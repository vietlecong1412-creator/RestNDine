import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';
import 'otp_screen.dart';

/// Quy tắc mật khẩu mặc định của ASP.NET Identity ở backend — kiểm tra trước khi gửi
/// để người dùng không nhận lỗi tiếng Anh từ server.
final _passwordRules = <(String, bool Function(String))>[
  ('Ít nhất 6 ký tự', (p) => p.length >= 6),
  ('Chữ hoa', (p) => RegExp(r'\p{Lu}', unicode: true).hasMatch(p)),
  ('Chữ thường', (p) => RegExp(r'\p{Ll}', unicode: true).hasMatch(p)),
  ('Chữ số', (p) => RegExp(r'[0-9]').hasMatch(p)),
  ('Ký tự đặc biệt', (p) => RegExp(r'[^\p{L}\p{N}]', unicode: true).hasMatch(p)),
];

/// Đăng ký. Mở từ [LoginScreen]; trả về `true` khi đã tạo và xác thực tài khoản.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Sau lần gửi lỗi đầu tiên thì kiểm tra lại ngay khi người dùng sửa, để lỗi cũ không đứng mãi
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _selectedRole = 'Customer';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(_emailCtrl.text.trim(), _passCtrl.text, role: _selectedRole);

    if (success && mounted && auth.pendingOtpEmail != null) {
      // Tài khoản đã tạo nhưng phải xác thực email bằng OTP mới đăng nhập được
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => OtpScreen(email: auth.pendingOtpEmail!)),
      );
      if (verified == true && mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final password = _passCtrl.text;

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
                  const AuthHeader(
                    leading: Align(alignment: Alignment.centerLeft, child: BrandMark(showName: false)),
                    title: 'Tạo tài khoản',
                    subtitle: Text('Tham gia cộng đồng review quán ăn, quán cafe và khách sạn.'),
                  ),
                  if (auth.errorMessage != null) ...[
                    ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  Text('Bạn là', style: context.text.titleSmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Khách hàng',
                          description: 'Tìm quán, đánh giá, nhắn tin',
                          selected: _selectedRole == 'Customer',
                          onTap: () => setState(() => _selectedRole = 'Customer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.storefront_outlined,
                          title: 'Chủ quán',
                          description: 'Đăng địa điểm, trả lời khách',
                          selected: _selectedRole == 'Owner',
                          onTap: () => setState(() => _selectedRole = 'Owner'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const FieldLabel('Email'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
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
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      hintText: 'Tạo mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => _passwordRules.every((r) => r.$2(v ?? ''))
                        ? null
                        : 'Mật khẩu chưa đáp ứng đủ các yêu cầu bên dưới',
                  ),
                  const SizedBox(height: 10),
                  _PasswordChecklist(password: password),
                  const SizedBox(height: 16),
                  const FieldLabel('Nhập lại mật khẩu'),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: 'Nhập lại mật khẩu ở trên',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                    ),
                    validator: (v) => v != _passCtrl.text ? 'Mật khẩu nhập lại không khớp' : null,
                  ),
                  const SizedBox(height: 28),
                  SubmitButton(label: 'Tạo tài khoản', loading: auth.isSubmitting, onPressed: _submit),
                  const SizedBox(height: 12),
                  AuthSwitchLink(
                    prompt: 'Đã có tài khoản?',
                    action: 'Đăng nhập',
                    onTap: () => Navigator.of(context).pop(false),
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

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : colors.field,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 1.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: selected ? scheme.onPrimaryContainer : colors.textSecondary),
                    const Spacer(),
                    Icon(
                      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected ? scheme.primary : colors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(description, style: context.text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  final String password;

  const _PasswordChecklist({required this.password});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (label, test) in _passwordRules)
          Builder(builder: (context) {
            final ok = test(password);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                    key: ValueKey(ok),
                    size: 15,
                    color: ok ? colors.success : colors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: context.text.labelSmall!.copyWith(color: ok ? colors.success : colors.textMuted),
                ),
              ],
            );
          }),
      ],
    );
  }
}
