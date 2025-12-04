-- ========================================
-- 完整的举报帖子系统数据库设计
-- ========================================

-- 1. 修改 post 表，添加状态管理字段
ALTER TABLE posts
ADD COLUMN status ENUM('NORMAL','REMOVED','DRAFT','AUDIT') DEFAULT 'NORMAL' COMMENT '帖子状态：NORMAL=正常，REMOVED=已下架，DRAFT=草稿，AUDIT=审核中',
ADD COLUMN hidden_reason VARCHAR(255) COMMENT '下架原因（管理员填写）',
ADD COLUMN updated_by_admin BIGINT COMMENT '最后操作的管理员ID',
ADD COLUMN visible_to_author BOOLEAN DEFAULT TRUE COMMENT '作者是否可见（下架后作者仍可见以便修改）';

-- 2. 创建 report_post 表（举报帖子记录表）
CREATE TABLE IF NOT EXISTS report_post (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '举报记录ID',

    -- 举报信息
    reporter_id BIGINT NOT NULL COMMENT '举报人用户ID',
    post_id BIGINT NOT NULL COMMENT '被举报的帖子ID',
    description VARCHAR(500) COMMENT '举报描述（用户填写的举报理由）',
    report_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '举报时间',

    -- 处理状态
    status ENUM('PENDING', 'PROCESSED', 'IGNORED') DEFAULT 'PENDING' COMMENT '举报处理状态：PENDING=待处理，PROCESSED=已处理（已下架），IGNORED=已忽略',

    -- 管理员处理信息
    admin_id BIGINT COMMENT '处理该举报的管理员ID',
    handle_time TIMESTAMP NULL COMMENT '处理时间',
    handle_result VARCHAR(500) COMMENT '处理结果说明',

    -- 帖子处理后的状态
    post_status_after ENUM('NORMAL','REMOVED','AUDIT','DRAFT') COMMENT '处理后帖子的状态',

    -- 索引
    INDEX idx_reporter (reporter_id),
    INDEX idx_post (post_id),
    INDEX idx_status (status),
    INDEX idx_report_time (report_time),

    -- 外键约束
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='帖子举报记录表';

-- 3. 为 post 表添加索引以优化查询
ALTER TABLE posts
ADD INDEX idx_status (status),
ADD INDEX idx_author_status (author_id, status);

-- ========================================
-- 完整的业务流程说明
-- ========================================
--
-- 1. 用户举报帖子
--    INSERT INTO report_post (reporter_id, post_id, description)
--    VALUES (?, ?, ?)
--
-- 2. 管理员查看举报列表
--    SELECT * FROM report_post WHERE status = 'PENDING'
--
-- 3. 管理员下架帖子
--    UPDATE post SET status='REMOVED', hidden_reason=?, updated_by_admin=? WHERE id=?
--    UPDATE report_post SET status='PROCESSED', admin_id=?, handle_time=NOW(),
--           handle_result=?, post_status_after='REMOVED' WHERE id=?
--
-- 4. 管理员忽略举报
--    UPDATE report_post SET status='IGNORED', admin_id=?, handle_time=NOW(),
--           handle_result=? WHERE id=?
--
-- 5. 作者修改帖子（保存草稿）
--    UPDATE post SET status='DRAFT', content=?, title=? WHERE id=? AND author_id=?
--
-- 6. 作者提交审核
--    UPDATE post SET status='AUDIT' WHERE id=? AND author_id=? AND status='DRAFT'
--
-- 7. 管理员审核通过
--    UPDATE post SET status='NORMAL', hidden_reason=NULL, visible_to_author=TRUE
--    WHERE id=? AND status='AUDIT'
--
-- ========================================
