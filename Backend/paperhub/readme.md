关于paperhub后端的说明文件 
 
一、项目架构
paperhub/                          # 项目根目录   
├── pom.xml                        # Maven配置文件，添加新的依赖需要修改该文件    
├── mvnw / mvnw.cmd                # Maven包装器（可在没有Maven的window环境运行的必备文件）    
├── src/    
│   ├── main/     
│   │   ├── java/com/example/paperhub/          # Java源代码，项目的主要代码存放处    
│   │   └── resources/                          # 资源文件夹    
│   │       └── application.properties          # 配置文件（类似config.ini），目前该文件中包含数据库路径、163邮箱发送验证码等服务    
│   └── test/                                   # 测试代码   
└── target/                                     # 编译输出目录，无需修改   

二、源代码部分具体分析    
本项目作为Springboot框架的的项目遵循Spring Boot三层架构（Controller控制器层 → Service服务层 → Repository数据访问层）。     
1.模块运行中的功能分配是 Controller 接收请求后调用 Service 处理具体逻辑并调用 Repository 操作数据库，而 Entity/DTO 负责决定数据结构。    
2.每个模块之间是相互独立的，比如说auth和JWT。前端通过接口发送的需求会通过 Spring 的注解路由匹配自动分发至对应模块的控制器激活后端模块进行处理。因此后续添加新功能可以通过划分模块的方式独立开发，不用修改其他的模块。   
3.修改项目主要修改main文件夹下的代码，如果有添加新的依赖则需要修改pml.xml，新的配置需要修改application.properties，基本不用修改其他文件     
 main/     
 │   ├── java/                  # Java源代码（类似.c/.cpp文件）    
 │   │   └── com/example/paperhub/   
 │   │       ├── PaperhubApplication.java    # 程序入口（类似main函数），目前的内容在后续开发中无需修改！   
 │   │       ├── auth/                       # 用户认证模块，负责注册、登录、邮箱验证、密码重置等功能   
 │   │       │   ├── AuthController.java       # Controller，定义 HTTP 接口路径和请求方法，负责接收前端请求并将任务交给AuthService   
 │   │       │   ├── AuthService.java          # Service，包含具体业务逻辑，例如生成验证码、校验用户信息、调用邮件服务发送验证码等     
 │   │       │   ├── User.java                 # Entity，是用户数据实体类，映射数据库中的users表   
 │   │       │   ├── UserRepository.java       # Repository，定义操作数据库的接口，SpringBoot会自动生成对应实现   
 │   │       │   └── dto/   
 │   │       │       └── AuthDtos.java       # 数据传输对象（DTO），定义前端与后端交互的数据格式   
 │   │       ├── config/                     # 配置模块   
 │   │       │   └── SecurityConfig.java       # 安全配置文件   
 │   │       ├── jwt/                        # JWT令牌管理模块   
 │   │       │   └── JwtService.java           # 提供JWT服务（生成/验证令牌），登录成功后生成 Token，用于用户身份验证。   
 │   │       └── notify/                     # 邮件通知模块   
 │   │           └── MailService.java          # 负责向用户发送邮件，包括：注册验证码和重置密码验证码，使用163邮箱，配置在application.properties   
 │   └── resources/        
 │       └── ststic/                         # 静态资源（图片、CSS、JS）,目前暂无   
 │       └── templates                       # 前端模板（如 Thymeleaf），目前暂无   
 │       └── application.properties            # 配置文件（类似config.ini）   
 └── test/                                   # 测试代码   
   
三、运行项目   
使用 IDE（如 IntelliJ IDEA）直接运行 PaperhubApplication.java。   
注：如果这里关于Springboot出现大量报错，说明没有同步maven项目需要的配置，右侧m标同步所有项目解决。   
运行成功后，后端服务会在：http://localhost:8080/监听前端请求，然后再运行前端就能正确响应。   