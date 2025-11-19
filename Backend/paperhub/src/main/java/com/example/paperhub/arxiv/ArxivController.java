package com.example.paperhub.arxiv;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * arXiv API 代理控制器
 * 用于解决前端直接访问 arXiv API 时的 CORS 问题
 */
@RestController
@RequestMapping("/arxiv")
@CrossOrigin(origins = "*") // 允许跨域访问
public class ArxivController {

    private static final String ARXIV_API_BASE_URL = "http://export.arxiv.org/api/query";
    private final RestTemplate restTemplate;

    @Autowired
    public ArxivController(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    /**
     * 获取 arXiv 文献元数据（通过 ID）
     * 
     * 请求流程：
     * 1. 前端 Flutter Web → GET /arxiv?id=1512.03385
     * 2. 后端服务器 → GET http://export.arxiv.org/api/query?id_list=1512.03385
     * 3. arXiv API → 返回 XML 数据
     * 4. 后端服务器 → 返回 XML 给前端
     * 
     * @param id arXiv ID (例如: 1512.03385 或 2301.12345)
     * @return arXiv API 返回的 XML 响应
     */
    @GetMapping
    public ResponseEntity<String> getArxivMetadata(@RequestParam String id) {
        try {
            // 验证 arXiv ID 格式
            if (id == null || id.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                    .body("错误：arXiv ID 不能为空");
            }

            // 清理 ID（移除可能的版本号后缀，如果需要的话）
            String cleanId = id.trim();
            
            // URL 编码 arXiv ID（处理特殊字符）
            String encodedId = java.net.URLEncoder.encode(cleanId, java.nio.charset.StandardCharsets.UTF_8);

            // 构建 arXiv API URL
            String url = ARXIV_API_BASE_URL + "?id_list=" + encodedId;
            
            System.out.println("========== arXiv 代理请求 ==========");
            System.out.println("接收前端请求: GET /arxiv?id=" + cleanId);
            System.out.println("转发到 arXiv API: " + url);
            System.out.println("=====================================");

            // 调用 arXiv API（服务器端调用，不受 CORS 限制）
            String response = restTemplate.getForObject(url, String.class);
            
            System.out.println("arXiv API 响应长度: " + (response != null ? response.length() : 0) + " 字符");

            if (response == null || response.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body("错误：未找到 arXiv ID 为 " + cleanId + " 的文献");
            }
            
            // 检查响应是否包含错误信息
            if (response.contains("<opensearch:totalResults>0</opensearch:totalResults>")) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body("错误：未找到 arXiv ID 为 " + cleanId + " 的文献");
            }

            // 返回 XML 响应
            return ResponseEntity.ok()
                .header("Content-Type", "application/xml; charset=utf-8")
                .body(response);

        } catch (HttpClientErrorException.NotFound e) {
            // 404 错误
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body("错误：arXiv API 返回 404，请确认 ID 是否正确");
        } catch (HttpClientErrorException e) {
            // HTTP 客户端错误（4xx）
            System.err.println("arXiv API 错误: " + e.getStatusCode() + " - " + e.getMessage());
            return ResponseEntity.status(e.getStatusCode())
                .body("错误：无法连接到 arXiv 服务器，状态码: " + e.getStatusCode() + " - " + e.getMessage());
        } catch (ResourceAccessException e) {
            // 网络连接错误
            System.err.println("网络连接错误: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body("错误：网络连接失败 - " + e.getMessage());
        } catch (Exception e) {
            // 其他错误
            System.err.println("获取 arXiv 信息异常: " + e.getClass().getName() + " - " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("错误：获取文献信息失败 - " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }
}

