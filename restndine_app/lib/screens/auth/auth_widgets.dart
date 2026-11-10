import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Logo chữ của app: ô vuông gradient cam + tên.
class BrandMark extends StatelessWidget {
  final double size;
  final bool showName;

  const BrandMark({super.key, this.size = 52, this.showName = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: context.colors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(
                color: context.colors.brand.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: size * 0.5),
        ),
        if (showName) ...[
          const SizedBox(width: 12),
          Text('RestNDine', style: context.text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
        ],
      ],
    );
  }
}

/// Tiêu đề + mô tả đầu các màn hình đăng nhập/đăng ký/OTP.
class AuthHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget subtitle;

  const AuthHeader({super.key, required this.leading, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(height: 28),
        Text(title, style: context.text.headlineMedium),
        const SizedBox(height: 8),
        DefaultTextStyle.merge(
          style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary),
          child: subtitle,
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Nhãn đặt phía trên ô nhập (rõ ràng hơn nhãn nổi khi ô có nền không viền).
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(text, style: context.text.titleSmall),
    );
  }
}

/// Nút chính có trạng thái đang xử lý.
class SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const SubmitButton({super.key, required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: context.scheme.onPrimary),
              )
            : Text(label),
      ),
    );
  }
}

/// Dòng "Chưa có tài khoản? Đăng ký ngay".
class AuthSwitchLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({super.key, required this.prompt, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
          child: Text(action),
        ),
      ],
    );
  }
}
