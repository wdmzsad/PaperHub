int _parseCount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? bio;
  final String avatar;
  final String backgroundImage;
  final List<String> researchDirections;
  final int followingCount;
  final int followersCount;
  final int postsCount;
  final int favoritesCount;
  final int likesCount;
  final bool? isFollowing;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatar,
    required this.backgroundImage,
    this.bio,
    this.researchDirections = const [],
    this.followingCount = 0,
    this.followersCount = 0,
    this.postsCount = 0,
    this.favoritesCount = 0,
    this.likesCount = 0,
    this.isFollowing,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId == null ? '' : rawId.toString();
    final email = json['email'] as String? ?? '';
    final rawDisplayName =
        json['name'] ?? json['displayName'] ?? json['nickname'];
    final fallbackName = email.contains('@') ? email.split('@').first : email;

    return UserProfile(
      id: id,
      email: email,
      displayName: (rawDisplayName as String?)?.trim().isNotEmpty == true
          ? rawDisplayName as String
          : fallbackName,
      avatar: (json['avatar'] as String?)?.trim().isNotEmpty == true
          ? json['avatar'] as String
          : 'images/DefaultAvatar.png',
      backgroundImage:
          (json['backgroundImage'] as String?)?.trim().isNotEmpty == true
          ? json['backgroundImage'] as String
          : 'images/profile_bg.jpg',
      bio: (json['bio'] as String?)?.trim().isNotEmpty == true
          ? json['bio'] as String
          : null,
      researchDirections:
          (json['researchDirections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      followingCount: _parseCount(json['following'] ?? json['followingCount']),
      followersCount: _parseCount(json['followers'] ?? json['followersCount']),
      postsCount: _parseCount(json['posts'] ?? json['postsCount']),
      favoritesCount: _parseCount(json['favorites'] ?? json['favoritesCount']),
      likesCount: _parseCount(json['likes'] ?? json['likesCount']),
      isFollowing: json['isFollowing'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'name': displayName,
    'avatar': avatar,
    'backgroundImage': backgroundImage,
    if (bio != null) 'bio': bio,
    'researchDirections': researchDirections,
    'following': followingCount,
    'followers': followersCount,
    'posts': postsCount,
    'favorites': favoritesCount,
    'likes': likesCount,
    if (isFollowing != null) 'isFollowing': isFollowing,
  };

  UserProfile copyWith({
    String? displayName,
    String? avatar,
    String? backgroundImage,
    String? bio,
    List<String>? researchDirections,
    int? followingCount,
    int? followersCount,
    int? postsCount,
    int? favoritesCount,
    int? likesCount,
    bool? isFollowing,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      bio: bio ?? this.bio,
      researchDirections: researchDirections ?? this.researchDirections,
      followingCount: followingCount ?? this.followingCount,
      followersCount: followersCount ?? this.followersCount,
      postsCount: postsCount ?? this.postsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      likesCount: likesCount ?? this.likesCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
