package com.example.paperhub.post;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 用于首页推荐的用户兴趣画像：
 * - 研究方向（从 User.researchDirections 拆分）
 * - 收藏、浏览、自己发帖的标签权重
 * - 已浏览 / 已收藏 / 自己发帖的帖子 ID 集合
 */
public class UserInterest {

    /**
     * 用户填写的研究方向（已经拆分好的列表）
     */
    private List<String> researchDirections;

    /**
     * 用户的近期搜索关键词（去重后的小写列表）
     */
    private List<String> searchKeywords;

    /**
     * 从收藏得到的标签权重
     */
    private final Map<String, Double> favoriteTagWeights = new HashMap<>();

    /**
     * 从浏览历史得到的标签权重
     */
    private final Map<String, Double> browseTagWeights = new HashMap<>();

    /**
     * 从自己发帖得到的标签权重
     */
    private final Map<String, Double> selfPostTagWeights = new HashMap<>();

    /**
     * 已浏览过的帖子 ID
     */
    private final Set<Long> viewedPostIds = new HashSet<>();

    /**
     * 已收藏的帖子 ID
     */
    private final Set<Long> favoritedPostIds = new HashSet<>();

    /**
     * 用户自己发的帖子 ID
     */
    private final Set<Long> ownPostIds = new HashSet<>();

    public List<String> getResearchDirections() {
        return researchDirections;
    }

    public void setResearchDirections(List<String> researchDirections) {
        this.researchDirections = researchDirections;
    }

    public Map<String, Double> getFavoriteTagWeights() {
        return favoriteTagWeights;
    }

    public Map<String, Double> getBrowseTagWeights() {
        return browseTagWeights;
    }

    public Map<String, Double> getSelfPostTagWeights() {
        return selfPostTagWeights;
    }

    public Set<Long> getViewedPostIds() {
        return viewedPostIds;
    }

    public Set<Long> getFavoritedPostIds() {
        return favoritedPostIds;
    }

    public Set<Long> getOwnPostIds() {
        return ownPostIds;
    }

    public List<String> getSearchKeywords() {
        return searchKeywords;
    }

    public void setSearchKeywords(List<String> searchKeywords) {
        this.searchKeywords = searchKeywords;
    }

    /**
     * 工具方法：为某个 map 中的标签增加权重。
     */
    public static void addTagWeights(Map<String, Double> map, List<String> tags, double delta) {
        if (tags == null || tags.isEmpty()) {
            return;
        }
        for (String raw : tags) {
            if (raw == null) continue;
            String tag = raw.trim();
            if (tag.isEmpty()) continue;
            map.merge(tag, delta, Double::sum);
        }
    }
}


