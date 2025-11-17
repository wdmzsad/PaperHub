package com.example.paperhub.user.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

/**
 * 用户资料相关 DTO。
 */
public class UserDtos {

    /**
     * 个人主页展示响应。
     */
    public record ProfileResp(
            Long id,
            String email,
            String displayName,
            String avatar,
            String backgroundImage,
            String bio,
            List<String> researchDirections,
            int followingCount,
            int followersCount,
            int postsCount,
            int favoritesCount,
            int likesCount,
            Boolean isFollowing
    ) {}

    /**
     * 更新个人资料请求体。
     */
    public record UpdateProfileReq(
            @NotBlank(message = "昵称不能为空")
            String name,
            String bio,
            List<String> researchDirections,
            String backgroundImage
    ) {}

    /**
     * 头像上传响应。
     */
    public record AvatarUploadResp(String url, String message) {}

    /**
     * 背景图上传响应。
     */
    public record BackgroundUploadResp(String url, String message) {}

    /**
     * 用户列表响应。
     */
    public record UserListResp(
            List<ProfileResp> users,
            long total,
            int page,
            int pageSize
    ) {}
}

