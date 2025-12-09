-- 热搜榜单表
-- 存储计算后的热搜排名结果，定时更新（每10分钟）
CREATE TABLE hot_search (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    keyword VARCHAR(512) NOT NULL,
    search_type VARCHAR(20) NOT NULL COMMENT '搜索类型: keyword, tag, author',
    heat_score DOUBLE NOT NULL COMMENT '热度分数（计算得出，用于排序）',
    rank_position INT NOT NULL COMMENT '排名（1-based）',
    tag VARCHAR(10) COMMENT '标签: 新 - 新上榜，热 - 持续热门，null - 普通',
    search_count BIGINT NOT NULL COMMENT '搜索总次数（统计周期内）',
    unique_users BIGINT NOT NULL COMMENT '独立用户数（统计周期内）',
    growth_rate DOUBLE COMMENT '增长率（与上一周期比较）',
    period_start TIMESTAMP NOT NULL COMMENT '统计周期开始时间',
    period_end TIMESTAMP NOT NULL COMMENT '统计周期结束时间',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_type_rank (search_type, rank_position),
    INDEX idx_period_end (period_end),
    INDEX idx_calculated_at (period_end)
) COMMENT='热搜榜单，每10分钟更新一次';

-- 示例数据（用于测试）
INSERT INTO hot_search (keyword, search_type, heat_score, rank_position, tag, search_count, unique_users, growth_rate, period_start, period_end) VALUES
('深度学习', 'keyword', 125.6, 1, '热', 150, 45, 1.8, NOW() - INTERVAL 24 HOUR, NOW()),
('机器学习', 'keyword', 98.3, 2, '热', 120, 38, 1.5, NOW() - INTERVAL 24 HOUR, NOW()),
('计算机视觉', 'keyword', 76.2, 3, '新', 95, 28, 2.1, NOW() - INTERVAL 24 HOUR, NOW()),
('自然语言处理', 'keyword', 65.8, 4, NULL, 80, 25, 1.2, NOW() - INTERVAL 24 HOUR, NOW()),
('强化学习', 'keyword', 54.1, 5, NULL, 65, 20, 1.0, NOW() - INTERVAL 24 HOUR, NOW()),
('Python', 'tag', 35.4, 6, '新', 45, 18, 2.3, NOW() - INTERVAL 24 HOUR, NOW()),
('TensorFlow', 'tag', 32.1, 7, NULL, 40, 15, 1.1, NOW() - INTERVAL 24 HOUR, NOW()),
('PyTorch', 'tag', 29.8, 8, NULL, 38, 14, 1.0, NOW() - INTERVAL 24 HOUR, NOW()),
('李沐', 'author', 19.7, 9, NULL, 25, 10, 1.5, NOW() - INTERVAL 24 HOUR, NOW()),
('吴恩达', 'author', 18.2, 10, NULL, 22, 9, 1.3, NOW() - INTERVAL 24 HOUR, NOW());

-- 清理旧数据（保留最近7天的数据）
-- 可以设置定时任务执行：DELETE FROM hot_search WHERE period_end < NOW() - INTERVAL 7 DAY;