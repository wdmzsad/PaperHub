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

    // 使用 HTTPS，因为 arXiv API 会从 HTTP 重定向到 HTTPS
    private static final String ARXIV_API_BASE_URL = "https://export.arxiv.org/api/query";
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

            // 构建 arXiv API URL
            // 注意：arXiv ID 格式为 YYMM.NNNNN，不包含特殊字符，直接拼接即可
            String url = ARXIV_API_BASE_URL + "?id_list=" + cleanId;
            
            System.out.println("========== arXiv 代理请求 ==========");
            System.out.println("接收前端请求: GET /arxiv?id=" + cleanId);
            System.out.println("转发到 arXiv API: " + url);
            System.out.println("=====================================");

            // 设置请求头
            org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
            headers.set("User-Agent", "Mozilla/5.0 (compatible; PaperHub/1.0)");
            headers.set("Accept", "application/atom+xml, application/xml, text/xml, */*");
            org.springframework.http.HttpEntity<?> entity = new org.springframework.http.HttpEntity<>(headers);

            // 调用 arXiv API（服务器端调用，不受 CORS 限制）
            // 使用 exchange 方法以便设置请求头
            org.springframework.http.ResponseEntity<String> responseEntity = 
                restTemplate.exchange(url, org.springframework.http.HttpMethod.GET, entity, String.class);
            
            String response = responseEntity.getBody();
            int statusCode = responseEntity.getStatusCode().value();
            
            System.out.println("arXiv API 响应状态码: " + statusCode);
            System.out.println("arXiv API 响应长度: " + (response != null ? response.length() : 0) + " 字符");
            System.out.println("响应头 Content-Type: " + responseEntity.getHeaders().getContentType());
            
            // 如果状态码不是 200，记录详细信息
            if (statusCode != 200) {
                System.err.println("arXiv API 返回非 200 状态码: " + statusCode);
                System.err.println("响应头: " + responseEntity.getHeaders());
                if (response != null && !response.isEmpty()) {
                    System.err.println("响应体前 500 字符: " + 
                        (response.length() > 500 ? response.substring(0, 500) : response));
                }
            }
            
            // 如果响应为空但状态码是 200，可能是编码问题
            if ((response == null || response.isEmpty()) && statusCode == 200) {
                System.err.println("警告：状态码 200 但响应体为空");
                System.err.println("所有响应头: " + responseEntity.getHeaders());
                // 尝试使用字节数组方式获取
                try {
                    org.springframework.http.ResponseEntity<byte[]> byteResponse = 
                        restTemplate.exchange(url, org.springframework.http.HttpMethod.GET, entity, byte[].class);
                    byte[] bodyBytes = byteResponse.getBody();
                    if (bodyBytes != null && bodyBytes.length > 0) {
                        response = new String(bodyBytes, java.nio.charset.StandardCharsets.UTF_8);
                        System.out.println("使用字节数组方式获取成功，长度: " + response.length());
                    }
                } catch (Exception e) {
                    System.err.println("尝试字节数组方式失败: " + e.getMessage());
                }
            }

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

        } catch (org.springframework.web.client.HttpClientErrorException.NotFound e) {
            // 404 错误
            System.err.println("arXiv API 404 错误: " + e.getMessage());
            System.err.println("响应体: " + e.getResponseBodyAsString());
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body("错误：arXiv API 返回 404，请确认 ID 是否正确");
        } catch (org.springframework.web.client.HttpClientErrorException e) {
            // HTTP 客户端错误（4xx）
            System.err.println("arXiv API 错误: " + e.getStatusCode() + " - " + e.getMessage());
            System.err.println("响应体: " + e.getResponseBodyAsString());
            return ResponseEntity.status(e.getStatusCode())
                .body("错误：无法连接到 arXiv 服务器，状态码: " + e.getStatusCode() + " - " + e.getMessage());
        } catch (ResourceAccessException e) {
            // 网络连接错误
            System.err.println("网络连接错误: " + e.getMessage());
            e.printStackTrace();
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

