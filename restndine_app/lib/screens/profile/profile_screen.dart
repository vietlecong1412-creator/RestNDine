import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/launcher.dart';
import '../../widgets/common.dart';
import '../auth/auth_widgets.dart';
import '../auth/login_screen.dart';

/// Tab "Tài khoản": thông tin người dùng hoặc lời mời đăng nhập, thông tin ứng dụng.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (auth.isRestoring)
            const SkeletonPulse(child: SkeletonBox(height: 104, radius: AppTheme.radiusLg))
          else if (user == null)
            const _GuestCard()
          else
            _ProfileCard(user: user),
          if (user?.isOwner == true) ...[
            const SizedBox(height: 12),
            const _OwnerNote(),
          ],
          const SizedBox(height: 24),
          _MenuGroup(
            title: 'Ứng dụng',
            children: [
              _MenuTile(
                icon: Icons.info_outline_rounded,
                title: 'Về RestNDine',
                subtitle: 'Phiên bản 1.0.0',
                onTap: () => _showAbout(context),
              ),
              _MenuTile(
                icon: Icons.public_rounded,
                title: 'Mở trang web RestNDine',
                subtitle: user?.isOwner == true
                    ? 'Quản lý địa điểm, banner và tin nhắn'
                    : 'Xem RestNDine trên trình duyệt',
                trailing: Icons.open_in_new_rounded,
                onTap: () => Launcher.website(context, AppConfig.baseUrl),
              ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.danger,
                side: BorderSide(color: context.colors.danger.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.appName,
      applicationVersion: '1.0.0',
      applicationIcon: const BrandMark(size: 44, showName: false),
      applicationLegalese: '© 2026 RestNDine · Đồ án cơ sở',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Ứng dụng review và gợi ý nhà hàng, quán cafe, khách sạn với bản đồ tương tác '
          'và AI tóm tắt cảm xúc từ đánh giá (PhoBERT).',
        ),
        const SizedBox(height: 12),
        Text(
          'Công nghệ: Flutter · ASP.NET Core · JWT · SignalR · PhoBERT',
          style: context.text.bodySmall,
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để viết đánh giá và nhắn tin với chủ quán.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await auth.logout();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã đăng xuất')));
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: context.scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.person_outline_rounded, size: 36, color: context.scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Text('Bạn chưa đăng nhập', style: context.text.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Đăng nhập để viết đánh giá, bình chọn đánh giá hữu ích và nhắn tin trực tiếp với chủ quán.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Đăng nhập / Đăng ký'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (roleIcon, roleColor, roleBg) = user.isAdmin
        ? (Icons.admin_panel_settings_outlined, colors.ai, colors.aiContainer)
        : user.isOwner
            ? (Icons.storefront_rounded, colors.success, colors.successContainer)
            : (Icons.person_rounded, context.scheme.onPrimaryContainer, context.scheme.primaryContainer);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          UserAvatar(name: user.displayName, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge),
                const SizedBox(height: 2),
                Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                const SizedBox(height: 10),
                Pill(label: user.roleLabel, icon: roleIcon, color: roleColor, background: roleBg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerNote extends StatelessWidget {
  const _OwnerNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: colors.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Quản lý địa điểm, mua banner quảng cáo và trả lời tin nhắn của khách trên trang web RestNDine.',
              style: context.text.bodySmall!.copyWith(color: colors.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MenuGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: context.text.labelSmall!.copyWith(color: colors.textMuted, letterSpacing: 0.8),
          ),
        ),
        // Material (không phải Container) để hiệu ứng chạm của ListTile hiện được
        Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(indent: 60),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing = Icons.chevron_right_rounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: colors.field, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: colors.textSecondary),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(trailing, color: colors.textMuted, size: 20),
    );
  }
}
