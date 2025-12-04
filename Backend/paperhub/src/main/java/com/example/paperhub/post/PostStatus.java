package com.example.paperhub.post;

/**
 * 帖子状态枚举
 */
public enum PostStatus {
    /**
     * 正常状态 - 帖子正常显示
     */
    NORMAL,

    /**
     * 已下架 - 被管理员下架，作者可见可修改
     */
    REMOVED,

    /**
     * 草稿 - 作者正在修改中
     */
    DRAFT,

    /**
     * 审核中 - 作者提交审核，等待管理员审核
     */
    AUDIT
}
