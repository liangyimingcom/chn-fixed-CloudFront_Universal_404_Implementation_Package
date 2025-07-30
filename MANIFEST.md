# 项目文件清单

## CloudFront通用微前端404重定向系统实现包

### 核心文件

| 文件名 | 类型 | 大小 | 描述 | 必需 |
|--------|------|------|------|------|
| `universal-lambda-edge.js` | JavaScript | ~15KB | Lambda@Edge函数核心实现 | ✅ |
| `deploy.sh` | Shell脚本 | ~8KB | 自动化部署脚本 | ✅ |
| `test.sh` | Shell脚本 | ~12KB | 全面功能测试脚本 | ✅ |
| `README.md` | 文档 | ~25KB | 完整项目文档和使用指南 | ✅ |

### 配置文件

| 文件名 | 类型 | 大小 | 描述 | 必需 |
|--------|------|------|------|------|
| `config.json` | JSON配置 | ~3KB | 项目配置和参数定义 | 📋 |
| `QUICKSTART.md` | 文档 | ~5KB | 5分钟快速部署指南 | 📋 |
| `TROUBLESHOOTING.md` | 文档 | ~15KB | 详细故障排除指南 | 📋 |
| `MANIFEST.md` | 文档 | ~2KB | 本文件清单 | 📋 |

### 运行时生成文件

| 文件名 | 类型 | 描述 | 生成时机 |
|--------|------|------|---------|
| `lambda-function.zip` | ZIP包 | Lambda部署包 | 部署时 |
| `.lambda-version` | 文本 | 当前Lambda版本号 | 部署后 |
| `.cloudfront-domain` | 文本 | CloudFront域名缓存 | 测试时 |
| `current-config.json` | JSON | CloudFront当前配置 | 部署时 |
| `updated-config.json` | JSON | CloudFront更新配置 | 部署时 |

## 文件功能详解

### 1. universal-lambda-edge.js
**核心Lambda@Edge函数实现**

**主要功能**:
- 通用子目录路径解析
- 智能重定向逻辑判断
- 静态资源过滤
- 中文和特殊字符处理
- 完整响应头设置
- 错误处理和日志记录

**关键函数**:
- `exports.handler()` - 主处理函数
- `getSubdirectoryFromPath()` - 路径解析
- `shouldRedirectToIndex()` - 重定向判断
- `hasStaticExtension()` - 静态资源检测
- `createRedirectResponse()` - 响应构建
- `safeHeaderValue()` - 安全编码

### 2. deploy.sh
**自动化部署脚本**

**执行流程**:
1. 检查部署前置条件
2. 创建Lambda函数部署包
3. 更新Lambda@Edge函数代码
4. 发布新的Lambda函数版本
5. 更新CloudFront分配配置
6. 创建缓存失效
7. 验证部署结果
8. 清理临时文件

**配置变量**:
- `LAMBDA_FUNCTION_NAME` - Lambda函数名称
- `CLOUDFRONT_DISTRIBUTION_ID` - CloudFront分配ID
- `S3_BUCKET` - S3存储桶名称
- `AWS_REGION` - AWS区域（Lambda@Edge必须us-east-1）

### 3. test.sh
**全面功能测试脚本**

**测试套件**:
- 基础重定向测试（6个用例）
- 中文字符支持测试（3个用例）
- 特殊字符支持测试（3个用例）
- 静态资源过滤测试（4个用例）
- 边界条件测试（3个用例）
- 性能测试（响应时间评估）

**测试覆盖**:
- 子目录访问重定向
- 404页面重定向
- 多层级路径处理
- 根目录回退机制
- 静态资源正确过滤
- 响应时间性能验证

### 4. README.md
**完整项目文档**

**内容结构**:
- 项目概述和核心特性
- 技术实现详解
- 快速开始指南
- 配置说明
- 性能对比分析
- 监控和日志
- 故障排除
- 安全考虑
- 扩展和定制
- 版本历史

## 部署要求

### 系统要求
- **操作系统**: macOS, Linux, Windows (WSL)
- **Shell**: Bash 4.0+
- **工具**: curl, jq (可选)

### AWS要求
- **AWS CLI**: 2.0+
- **Node.js**: 18.x (Lambda运行时)
- **权限**: Lambda和CloudFront管理权限

### 网络要求
- **互联网连接**: 用于AWS API调用
- **HTTPS访问**: 用于测试CloudFront端点

## 使用流程

### 标准部署流程
```bash
1. 下载/克隆项目文件
2. 配置deploy.sh中的AWS参数
3. 执行 ./deploy.sh
4. 运行 ./test.sh 验证
5. 查看README.md了解详细功能
```

### 故障排除流程
```bash
1. 查看TROUBLESHOOTING.md
2. 检查CloudWatch日志
3. 运行诊断命令
4. 联系技术支持
```

## 文件依赖关系

```
universal-lambda-edge.js (核心)
    ↓
deploy.sh (部署) → test.sh (测试)
    ↓                ↓
config.json      README.md
    ↓                ↓
QUICKSTART.md    TROUBLESHOOTING.md
```

## 版本控制

### 文件版本标识
每个核心文件都包含版本信息：
- JavaScript文件: 文件头部注释
- Shell脚本: 脚本开头变量
- 文档文件: 元数据部分

### 兼容性矩阵
| 组件版本 | Lambda@Edge | CloudFront | S3 | 兼容性 |
|---------|-------------|------------|----|----|
| v1.0 | Node.js 18.x | 任意版本 | 任意版本 | ✅ |

## 安全注意事项

### 敏感信息
- AWS凭证不包含在文件中
- 配置参数需要手动设置
- 日志中不记录敏感数据

### 权限最小化
- 脚本仅请求必要的AWS权限
- Lambda函数使用最小权限角色
- S3访问仅限CloudFront

## 支持和维护

### 更新频率
- 核心功能: 稳定版本，按需更新
- 文档: 持续更新和改进
- 测试用例: 根据新需求扩展

### 技术支持
- 文档: README.md, TROUBLESHOOTING.md
- 快速开始: QUICKSTART.md
- 配置参考: config.json

---

**文件完整性检查**:
```bash
# 验证所有必需文件存在
ls -la universal-lambda-edge.js deploy.sh test.sh README.md

# 检查脚本执行权限
ls -la *.sh
```

**总计**: 8个核心文件，完整实现CloudFront通用微前端404重定向系统。
