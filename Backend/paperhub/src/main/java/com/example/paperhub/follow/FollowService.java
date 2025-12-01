package com.example.paperhub.follow;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.notification.NotificationService;
import java.util.Objects;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 关注/粉丝业务封装。
 */
@Service
public class FollowService {
    private final UserFollowRepository followRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    public FollowService(
            UserFollowRepository followRepository, 
            UserRepository userRepository,
            NotificationService notificationService) {
        this.followRepository = followRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @Transactional
    public void follow(User follower, Long targetUserId) {
        Objects.requireNonNull(targetUserId, "targetUserId cannot be null");
        if (follower.getId().equals(targetUserId)) {
            throw new IllegalArgumentException("不能关注自己");
        }
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        if (followRepository.existsByFollowerIdAndFollowingId(follower.getId(), target.getId())) {
            return;
        }
        UserFollow follow = new UserFollow();
        follow.setFollower(follower);
        follow.setFollowing(target);
        followRepository.save(follow);
        
        // 创建通知
        try {
            notificationService.createFollowNotification(follower, targetUserId);
        } catch (Exception e) {
            // 通知创建失败不影响关注操作
            System.err.println("创建关注通知失败: " + e.getMessage());
        }
    }

    @Transactional
    public void unfollow(User follower, Long targetUserId) {
        Objects.requireNonNull(targetUserId, "targetUserId cannot be null");
        followRepository.deleteByFollowerIdAndFollowingId(follower.getId(), targetUserId);
    }

    public boolean isFollowing(Long followerId, Long targetUserId) {
        if (followerId == null || targetUserId == null) return false;
        return followRepository.existsByFollowerIdAndFollowingId(followerId, targetUserId);
    }

    public long countFollowing(Long userId) {
        return followRepository.countByFollowerId(userId);
    }

    public long countFollowers(Long userId) {
        return followRepository.countByFollowingId(userId);
    }

    public Page<UserFollow> getFollowing(Long userId, Pageable pageable) {
        return followRepository.findByFollowerId(userId, pageable);
    }

    public Page<UserFollow> getFollowers(Long userId, Pageable pageable) {
        return followRepository.findByFollowingId(userId, pageable);
    }

    public Page<UserFollow> getMutualFollows(Long userId, Pageable pageable) {
        return followRepository.findMutualFollows(userId, pageable);
    }
}

