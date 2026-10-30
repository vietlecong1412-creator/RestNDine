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
