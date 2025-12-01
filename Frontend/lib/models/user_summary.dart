class UserSummary {
  final String id;
  final String displayName;
  final String avatar;
  final String? bio;
  final bool? isFollowing; // 当前用户是否已关注TA
  final bool? isFollower; // TA是否关注了当前用户
  final bool? isMutual; // 是否互相关注

  UserSummary({
    required this.id,
    required this.displayName,
    required this.avatar,
    this.bio,
    this.isFollowing,
    this.isFollower,
    this.isMutual,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId == null ? '' : rawId.toString();

    final followingFlag = _extractBool(json, const [
      'isFollowing',
      'is_following',
      'isFollowed',
      'is_followed',
      'isFollowedByMe',
      'is_followed_by_me',
      'hasFollowedBack',
      'has_followed_back',
    ]);

    final followerFlag = _extractBool(json, const [
      'isFollower',
      'is_follower',
      'followsMe',
      'follows_me',
      'isFollowedMe',
      'is_followed_me',
      'isFollowingMe',
      'is_following_me',
      'isFollowedByThem',
      'is_followed_by_them',
    ]);

    final mutualFlag = _extractBool(json, const [
      'isMutual',
      'is_mutual',
      'isFriend',
      'is_friend',
      'isFriends',
      'is_friends',
      'isTwoWay',
      'is_two_way',
    ]);

    return UserSummary(
      id: id,
      displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
      avatar: (json['avatar'] as String?)?.trim().isNotEmpty == true
          ? json['avatar'] as String
          : 'images/DefaultAvatar.png',
      bio: json['bio'] as String?,
      isFollowing: followingFlag ?? (mutualFlag == true ? true : null),
      isFollower: followerFlag ?? (mutualFlag == true ? true : null),
      isMutual: mutualFlag ?? ((followingFlag == true && followerFlag == true) ? true : null),
    );
  }

  UserSummary copyWith({
    String? id,
    String? displayName,
    String? avatar,
    String? bio,
    bool? isFollowing,
    bool? isFollower,
    bool? isMutual,
  }) {
    return UserSummary(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      isMutual: isMutual ?? this.isMutual,
    );
  }
}

bool? _extractBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return _parseBool(json[key]);
    }
  }
  return null;
}

bool? _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}
