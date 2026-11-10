import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

/// Hành động cần đăng nhập: mở màn hình đăng nhập (kèm lý do), trả về true nếu
/// sau đó người dùng đã đăng nhập để nơi gọi làm tiếp hành động dở dang.
Future<bool> ensureLoggedIn(BuildContext context, {String? message}) async {
  final auth = context.read<AuthProvider>();
  if (auth.isAuthenticated) return true;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => LoginScreen(message: message)),
  );
  return auth.isAuthenticated;
}
