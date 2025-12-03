package com.example.paperhub.report;

/**
 * 举报处理状态枚举
 */
public enum ReportStatus {
    /**
     * 待处理
     */
    PENDING,

    /**
     * 已处理（已下架）
     */
    PROCESSED,

    /**
     * 已忽略
     */
    IGNORED
}
