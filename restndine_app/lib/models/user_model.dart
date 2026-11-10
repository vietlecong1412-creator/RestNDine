import '../utils/formatters.dart';

class UserModel {
  final String id;
  final String email;
  final String userName;
  final List<String> roles;

  UserModel({
    required this.id,
    required this.email,
    required this.userName,
    required this.roles,
  });

  bool get isOwner => roles.contains('Owner') || roles.contains('Admin');
  bool get isAdmin => roles.contains('Admin');

  /// Tên ngắn để chào hỏi: userName mặc định là email nên chỉ lấy phần trước @.
  String get displayName => displayNameFromEmail(userName.isNotEmpty ? userName : email);

  /// Vai trò hiển thị bằng tiếng Việt, ưu tiên vai trò cao nhất.
  String get roleLabel => roles.contains('Admin')
      ? 'Quản trị viên'
      : roles.contains('Owner')
          ? 'Chủ quán'
          : 'Khách hàng';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      userName: json['userName'] ?? json['email'] ?? '',
      roles: (json['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'userName': userName,
        'roles': roles,
      };
}
