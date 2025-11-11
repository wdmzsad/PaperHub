# 故障排查指南

## 问题：前端显示"加载帖子失败，请检查网络连接"

### 可能的原因和解决方法

#### 1. 后端服务未启动 ⚠️ 最常见

**检查方法：**
- 在浏览器中访问：`http://localhost:8080/posts?page=1&pageSize=6`
- 如果无法访问，说明后端未启动

**解决方法：**
1. 在IntelliJ IDEA中打开后端项目
2. 找到 `PaperhubApplication.java`
3. 右键点击 -> Run 'PaperhubApplication'
4. 等待启动完成，看到类似日志：
   ```
   Started PaperhubApplication in X.XXX seconds
   ```

#### 2. 后端启动失败

**检查后端日志：**
- 查看IntelliJ IDEA的控制台输出
- 常见错误：
  - 数据库连接失败
  - 端口8080被占用

**解决方法：**

**数据库连接问题：**
- 检查 `application.properties` 中的数据库配置
- 确保华为云数据库可访问（不需要打开华为云界面，数据库服务器是一直运行的）
- 测试数据库连接：
  ```bash
  mysql -h 124.70.87.106 -u team -p
  ```

**端口被占用：**
- 修改 `application.properties` 添加：
  ```properties
  server.port=8081
  ```
- 同时修改前端 `api_service.dart` 中的 `baseUrl` 为 `http://localhost:8081`

#### 3. CORS跨域问题

**检查方法：**
- 打开浏览器开发者工具（F12）
- 查看Console标签，看是否有CORS错误

**解决方法：**
- 后端已经配置了CORS，允许所有来源
- 如果还有问题，检查 `SecurityConfig.java` 中的CORS配置

#### 4. 前端连接地址错误

**检查方法：**
- 打开 `Frontend/lib/services/api_service.dart`
- 确认 `baseUrl` 是否正确：
  ```dart
  const String baseUrl = 'http://localhost:8080';
  ```

**如果后端运行在其他地址：**
- 修改 `baseUrl` 为实际的后端地址
- 例如：`http://192.168.1.100:8080`（后端运行在其他机器）

#### 5. 数据库中没有数据

**检查方法：**
- 后端启动后，数据库中可能没有帖子数据
- 首次使用，帖子列表为空是正常的

**解决方法：**
- 可以先发布一个测试帖子
- 或者在后端添加一些测试数据

### 调试步骤

#### 步骤1：检查后端是否运行
```bash
# 在浏览器中访问
http://localhost:8080/posts?page=1&pageSize=6

# 或者使用curl
curl http://localhost:8080/posts?page=1&pageSize=6
```

**期望响应：**
```json
{
  "posts": [],
  "total": 0,
  "page": 1,
  "pageSize": 6
}
```

#### 步骤2：检查前端控制台
1. 在Chrome中按F12打开开发者工具
2. 查看Console标签
3. 查看Network标签，检查API请求
4. 查看请求的URL、状态码、响应内容

#### 步骤3：检查后端日志
1. 查看IntelliJ IDEA的控制台
2. 查看是否有错误信息
3. 查看SQL日志（如果启用了 `spring.jpa.show-sql=true`）

### 常见错误信息

#### "Connection refused"
- **原因：** 后端服务未启动
- **解决：** 启动后端服务

#### "Request timeout"
- **原因：** 后端响应太慢或未响应
- **解决：** 检查后端日志，查看是否有错误

#### "CORS policy"
- **原因：** 跨域问题
- **解决：** 检查后端CORS配置

#### "404 Not Found"
- **原因：** API路径错误
- **解决：** 检查API路径是否正确

#### "401 Unauthorized" 或 "403 Forbidden"
- **原因：** 认证问题（对于GET /posts不应该出现）
- **解决：** 检查SecurityConfig配置

### 快速测试

#### 测试后端API
```bash
# 测试获取帖子列表（不需要认证）
curl http://localhost:8080/posts?page=1&pageSize=6

# 测试获取帖子详情（需要有效的postId）
curl http://localhost:8080/posts/1
```

#### 测试数据库连接
- 检查 `application.properties` 中的数据库配置
- 确保网络可以访问 `124.70.87.106:3306`

### 华为云数据库

**不需要打开华为云界面**
- 数据库服务器是一直运行的
- 只要网络可以访问 `124.70.87.106:3306` 即可
- 如果本地无法访问，可能需要：
  1. 检查防火墙设置
  2. 检查安全组配置（在华为云控制台）
  3. 确认数据库允许从你的IP访问

### 如果还是无法解决

1. **查看详细日志：**
   - 前端：浏览器控制台
   - 后端：IntelliJ IDEA控制台

2. **检查网络：**
   - 确保可以访问 `http://localhost:8080`
   - 确保可以访问数据库 `124.70.87.106:3306`

3. **临时解决方案：**
   - 如果后端暂时无法启动，可以修改前端使用模拟数据
   - 在 `home_screen.dart` 的 `_loadInitialPosts()` 方法中，添加降级逻辑

