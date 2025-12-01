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
  final int favoritesReceivedCount;
  final bool? isFollowing;
  final bool? isFollower;
  // 隐私设置：由后端返回，用于控制前端可见性
  final bool hideFollowing;
  final bool hideFollowers;
  final bool publicFavorites;

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
    this.favoritesReceivedCount = 0,
    this.isFollowing,
    this.isFollower,
    this.hideFollowing = false,
    this.hideFollowers = false,
    this.publicFavorites = true,
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
      favoritesReceivedCount:
          _parseCount(json['favoritesReceived'] ?? json['favoritesReceivedCount']),
      isFollowing: json['isFollowing'] as bool?,
      isFollower: json['isFollower'] as bool?,
      hideFollowing: json['hideFollowing'] as bool? ?? false,
      hideFollowers: json['hideFollowers'] as bool? ?? false,
      publicFavorites: json['publicFavorites'] as bool? ?? true,
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
    'favoritesReceived': favoritesReceivedCount,
    if (isFollowing != null) 'isFollowing': isFollowing,
    if (isFollower != null) 'isFollower': isFollower,
    'hideFollowing': hideFollowing,
    'hideFollowers': hideFollowers,
    'publicFavorites': publicFavorites,
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
    int? favoritesReceivedCount,
    bool? isFollowing,
    bool? isFollower,
    bool? hideFollowing,
    bool? hideFollowers,
    bool? publicFavorites,
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
      favoritesReceivedCount:
          favoritesReceivedCount ?? this.favoritesReceivedCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      hideFollowing: hideFollowing ?? this.hideFollowing,
      hideFollowers: hideFollowers ?? this.hideFollowers,
      publicFavorites: publicFavorites ?? this.publicFavorites,
    );
  }
}
