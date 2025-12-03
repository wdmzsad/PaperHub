-- ========================================
-- 修复枚举大小写问题
-- ========================================

-- 1. 修改 post 表的 status 字段为大写枚举值
ALTER TABLE post
MODIFY COLUMN status ENUM('NORMAL','REMOVED','DRAFT','AUDIT') DEFAULT 'NORMAL';

-- 2. 如果表中已有数据，需要先更新现有数据（如果有的话）
-- UPDATE post SET status = UPPER(status);

-- 3. 修改 report_post 表的 post_status_after 字段
ALTER TABLE report_post
MODIFY COLUMN post_status_after ENUM('NORMAL','REMOVED','AUDIT','DRAFT');

-- ========================================
-- 验证修改
-- ========================================

-- 查看 post 表结构
SHOW CREATE TABLE post;

-- 查看 report_post 表结构
SHOW CREATE TABLE report_post;
