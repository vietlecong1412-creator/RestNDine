import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
      ),
      body: user == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar & Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Role Badges
                        Wrap(
                          spacing: 6,
                          children: user.roles.map((r) {
                            Color badgeColor = AppTheme.primaryColor;
                            if (r == 'Owner') badgeColor = Colors.orange;
                            if (r == 'Admin') badgeColor = Colors.purple;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: badgeColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Settings & Details
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                          title: const Text('Về dự án RestNDine'),
                          subtitle: const Text('Đồ án cơ sở - Bản đồ đa nền tảng & AI PhoBERT'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'RestNDine',
                              applicationVersion: '1.0.0 (Multi-platform)',
                              applicationLegalese: '© 2026 RestNDine Project. ASP.NET Core & Flutter.',
                              children: [
                                const Text(
                                  'Hệ thống review và gợi ý nhà hàng, khách sạn, quán cafe tích hợp AI phân tích cảm xúc (PhoBERT) và bản đồ tương tác.',
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.security_outlined, color: Colors.blue),
                          title: const Text('Phương thức xác thực'),
                          subtitle: const Text('JSON Web Token (JWT Bearer)'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.cloud_sync_outlined, color: Colors.green),
                          title: const Text('Đồng bộ thời gian thực'),
                          subtitle: const Text('SignalR WebSocket'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Đăng xuất'),
                            content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  await auth.logout();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
