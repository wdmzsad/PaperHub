class UserSummary {
  final String id;
  final String displayName;
  final String avatar;
  final String? bio;

  UserSummary({
    required this.id,
    required this.displayName,
    required this.avatar,
    this.bio,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId == null ? '' : rawId.toString();
    return UserSummary(
      id: id,
      displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
      avatar: (json['avatar'] as String?)?.trim().isNotEmpty == true
          ? json['avatar'] as String
          : 'images/DefaultAvatar.png',
      bio: json['bio'] as String?,
    );
  }
}
