# 快速开始指南

## 5分钟部署CloudFront通用微前端404重定向系统

### 步骤1: 环境准备 (1分钟)

```bash
# 检查AWS CLI
aws --version

# 检查AWS凭证
aws sts get-caller-identity

# 确认文件完整性
ls -la
# 应该看到: universal-lambda-edge.js, deploy.sh, test.sh, README.md, config.json
```

### 步骤2: 配置参数 (1分钟)

编辑 `deploy.sh` 文件，更新以下配置：

```bash
# 在deploy.sh中找到并修改这些变量
LAMBDA_FUNCTION_NAME="your-lambda-function-name"
CLOUDFRONT_DISTRIBUTION_ID="your-distribution-id"  
S3_BUCKET="your-s3-bucket-name"
```

**如何获取这些参数？**

```bash
# 获取Lambda函数名称
aws lambda list-functions --query 'Functions[?contains(FunctionName, `404`)].FunctionName'

# 获取CloudFront分配ID
aws cloudfront list-distributions --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName}'

# 获取S3存储桶名称
aws s3 ls
```

### 步骤3: 执行部署 (2分钟)

```bash
# 设置执行权限
chmod +x deploy.sh test.sh

# 开始部署
./deploy.sh
```

部署过程会自动：
- ✅ 检查前置条件
- ✅ 创建Lambda部署包
- ✅ 更新Lambda@Edge函数
- ✅ 发布新版本
- ✅ 更新CloudFront配置
- ✅ 创建缓存失效

### 步骤4: 验证部署 (1分钟)

```bash
# 运行自动化测试
./test.sh
```

测试将验证：
- 基础重定向功能
- 中文字符支持
- 特殊字符处理
- 静态资源过滤
- 性能表现

### 预期结果

✅ **成功部署后，您将看到：**

```
========================================
测试报告
========================================
总测试数: 28
通过测试: 28
失败测试: 0
成功率: 100%

[SUCCESS] 所有测试通过！系统运行正常

系统特性验证:
  ✓ 通用子目录重定向支持
  ✓ 中文字符完全支持
  ✓ 特殊字符处理正确
  ✓ 静态资源智能过滤
  ✓ 多层级路径重定向
  ✓ 根目录回退机制
  ✓ 性能表现良好
```

## 立即测试

部署完成后，您可以立即测试以下URL：

```bash
# 替换为您的CloudFront域名
DOMAIN="your-domain.cloudfront.net"

# 基础重定向测试
curl -I "https://$DOMAIN/website1/"
# 期望: 302重定向到 /website1/index.html

# 中文字符测试  
curl -I "https://$DOMAIN/产品/"
# 期望: 302重定向到 /产品/index.html

# 静态资源测试
curl -I "https://$DOMAIN/website1/style.css"
# 期望: 403 Forbidden (不重定向)
```

## 常见问题快速解决

### 问题1: 部署脚本权限错误
```bash
chmod +x deploy.sh test.sh
```

### 问题2: AWS凭证未配置
```bash
aws configure
# 输入您的Access Key ID, Secret Access Key, Region
```

### 问题3: Lambda函数不存在
```bash
# 检查函数名称是否正确
aws lambda get-function --function-name your-function-name
```

### 问题4: CloudFront分配ID错误
```bash
# 列出所有分配
aws cloudfront list-distributions --output table
```

### 问题5: 测试失败
```bash
# 等待CloudFront部署完成（可能需要10-15分钟）
aws cloudfront wait distribution-deployed --id YOUR_DISTRIBUTION_ID

# 手动创建缓存失效
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

## 下一步

部署成功后，您可以：

1. **查看详细文档**: 阅读 `README.md` 了解完整功能
2. **监控系统**: 检查CloudWatch日志和指标
3. **自定义配置**: 根据需求修改Lambda函数逻辑
4. **扩展功能**: 添加新的子目录或自定义重定向规则

## 技术支持

如遇到问题，请：
1. 检查CloudWatch日志: `/aws/lambda/us-east-1.your-function-name`
2. 验证IAM权限设置
3. 确认S3存储桶结构正确
4. 联系技术支持团队

---

**恭喜！** 您已成功部署CloudFront通用微前端404重定向系统。系统现在支持无限数量的子目录，包括中文字符，并提供25%的性能提升。
