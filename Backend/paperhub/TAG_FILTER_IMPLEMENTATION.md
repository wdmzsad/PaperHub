# 标签过滤功能实现说明

## 问题背景
之前从首页分区进去和标签点进去展示的帖子内容不一致，原因是：
1. 首页分区使用前端过滤（从已加载的帖子中过滤）
2. 独立分区页面尝试使用后端过滤，但后端没有实现标签过滤功能

## 解决方案
实现了完整的后端标签过滤逻辑，确保前后端过滤逻辑一致。

## 修改的文件

### 1. PostRepository.java
添加了两个按标签查询的方法：
```java
/**
 * 按标签查询帖子（支持精确匹配标签名）
 * @param tag 标签名称
 * @param pageable 分页参数
 * @return 包含指定标签的帖子分页
 */
@Query("SELECT DISTINCT p FROM Post p JOIN p.tags t WHERE t = :tag ORDER BY p.createdAt DESC")
Page<Post> findByTagOrderByCreatedAtDesc(@Param("tag") String tag, Pageable pageable);

/**
 * 统计包含指定标签的帖子数量
 * @param tag 标签名称
 * @return 包含指定标签的帖子数量
 */
@Query("SELECT COUNT(DISTINCT p) FROM Post p JOIN p.tags t WHERE t = :tag")
long countByTag(@Param("tag") String tag);
```

### 2. PostService.java
添加了支持标签过滤的`getPosts`方法重载：
```java
/**
 * 获取帖子列表（分页），支持按标签过滤
 * @param page 页码（从1开始）
 * @param pageSize 每页大小
 * @param tag 标签名称（可选，为null时返回所有帖子）
 * @return 帖子分页结果
 */
public Page<Post> getPosts(int page, int pageSize, String tag) {
    Pageable pageable = PageRequest.of(page - 1, pageSize);
    if (tag != null && !tag.trim().isEmpty()) {
        return postRepository.findByTagOrderByCreatedAtDesc(tag.trim(), pageable);
    } else {
        return postRepository.findAllByOrderByCreatedAtDesc(pageable);
    }
}
```

修改了原来的`getPosts`方法，让它调用新的重载方法以保持向后兼容性：
```java
/**
 * 获取帖子列表（分页）
 * @deprecated 请使用 {@link #getPosts(int, int, String)} 方法
 */
public Page<Post> getPosts(int page, int pageSize) {
    return getPosts(page, pageSize, null);
}
```

### 3. PostController.java
修改了`getPosts`方法，添加了`tag`参数：
```java
/**
 * 获取帖子列表
 * GET /posts?page=1&pageSize=20&tag=信息科学（CS）
 */
@GetMapping
public ResponseEntity<PostDtos.PostListResp> getPosts(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int pageSize,
        @RequestParam(required = false) String tag,  // 新增的tag参数
        @AuthenticationPrincipal User user) {

    try {
        Page<Post> postPage = postService.getPosts(page, pageSize, tag);  // 传递tag参数
        // ... 其余代码不变
    }
}
```

## API使用示例

### 1. 获取所有帖子（不按标签过滤）
```
GET /posts?page=1&pageSize=20
```

### 2. 获取指定标签的帖子
```
GET /posts?page=1&pageSize=20&tag=信息科学（CS）
```

### 3. 获取其他分区的帖子
```
GET /posts?page=1&pageSize=20&tag=理学
GET /posts?page=1&pageSize=20&tag=工学
GET /posts?page=1&pageSize=20&tag=生命科学
... 其他分区
```

## 测试方法

### 1. 编译项目
```bash
cd /mnt/e/sw/paperhub/Backend/paperhub
mvn clean compile
```

### 2. 运行测试
```bash
mvn test
```

### 3. 启动服务后测试API
```bash
# 启动服务后，使用curl或Postman测试
curl "http://localhost:8080/posts?page=1&pageSize=10&tag=信息科学（CS）"
```

## 前端适配说明

前端已经正确传递`disciplineTag`参数，无需修改：
- `ApiService.getPosts()`方法已经支持`disciplineTag`参数
- `ZoneScreen`页面已经正确调用带标签参数的API

## 效果
现在首页分区和独立分区页面都会显示完整的该分区帖子，内容保持一致：
1. 首页分区：使用后端过滤，显示完整数据
2. 独立分区页面：使用后端过滤，显示完整数据

两个页面都会调用相同的后端API：`GET /posts?tag=分区名称`