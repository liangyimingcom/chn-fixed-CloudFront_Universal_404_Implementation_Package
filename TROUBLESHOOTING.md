# 故障排除指南

## 常见问题诊断和解决方案

### 1. 部署相关问题

#### 问题: AWS CLI权限不足
**症状**: 部署脚本报错 "AccessDenied" 或 "UnauthorizedOperation"

**解决方案**:
```bash
# 检查当前用户权限
aws sts get-caller-identity

# 确认具有以下权限:
# - lambda:UpdateFunctionCode
# - lambda:PublishVersion
# - cloudfront:GetDistributionConfig
# - cloudfront:UpdateDistribution
# - cloudfront:CreateInvalidation
```

**所需IAM策略**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:PublishVersion",
        "lambda:GetFunction",
        "cloudfront:GetDistributionConfig",
        "cloudfront:UpdateDistribution",
        "cloudfront:CreateInvalidation",
        "cloudfront:GetDistribution"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 问题: Lambda函数不存在
**症状**: "ResourceNotFoundException: The resource you requested does not exist"

**解决方案**:
```bash
# 1. 检查函数是否存在
aws lambda list-functions --query 'Functions[?contains(FunctionName, `404`)].FunctionName'

# 2. 如果不存在，创建新函数
aws lambda create-function \
  --function-name micro-frontend-404-redirect \
  --runtime nodejs18.x \
  --role arn:aws:iam::YOUR_ACCOUNT:role/lambda-edge-execution-role \
  --handler index.handler \
  --zip-file fileb://lambda-function.zip \
  --region us-east-1
```

#### 问题: CloudFront分配ID错误
**症状**: "NoSuchDistribution: The specified distribution does not exist"

**解决方案**:
```bash
# 1. 列出所有CloudFront分配
aws cloudfront list-distributions --output table

# 2. 获取正确的分配ID
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Status:Status}'

# 3. 更新deploy.sh中的CLOUDFRONT_DISTRIBUTION_ID
```

### 2. 功能相关问题

#### 问题: 重定向不工作
**症状**: 访问子目录返回404而不是重定向

**诊断步骤**:
```bash
# 1. 检查Lambda@Edge关联
aws cloudfront get-distribution-config --id YOUR_DISTRIBUTION_ID \
  --query 'DistributionConfig.DefaultCacheBehavior.LambdaFunctionAssociations'

# 2. 验证Lambda函数版本
aws lambda list-versions-by-function --function-name YOUR_FUNCTION_NAME

# 3. 检查CloudFront部署状态
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID \
  --query 'Distribution.Status'
```

**解决方案**:
```bash
# 1. 确保使用最新的Lambda版本
# 2. 等待CloudFront部署完成（可能需要15分钟）
aws cloudfront wait distribution-deployed --id YOUR_DISTRIBUTION_ID

# 3. 创建缓存失效
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

#### 问题: 中文字符重定向失败
**症状**: 中文路径返回错误或重定向到错误位置

**诊断**:
```bash
# 测试中文字符编码
curl -v "https://your-domain.cloudfront.net/产品/" 

# 检查Lambda日志
aws logs filter-log-events \
  --log-group-name "/aws/lambda/us-east-1.your-function-name" \
  --filter-pattern "产品"
```

**解决方案**:
1. 确认S3存储桶中的文件夹名称使用UTF-8编码
2. 验证Lambda函数中的`safeHeaderValue`函数正确处理中文字符
3. 检查浏览器URL编码设置

#### 问题: 静态资源被错误重定向
**症状**: CSS、JS文件被重定向而不是返回403

**诊断**:
```bash
# 测试静态资源
curl -I "https://your-domain.cloudfront.net/website1/style.css"
# 应该返回403，而不是302

# 检查Lambda日志中的静态资源检测
aws logs filter-log-events \
  --log-group-name "/aws/lambda/us-east-1.your-function-name" \
  --filter-pattern "Static resource detected"
```

**解决方案**:
1. 检查`hasStaticExtension`函数中的扩展名列表
2. 确认文件扩展名匹配逻辑正确
3. 验证Lambda函数版本是否为最新

### 3. 性能相关问题

#### 问题: 响应时间过长
**症状**: 重定向响应时间超过2秒

**诊断**:
```bash
# 测试响应时间
time curl -I "https://your-domain.cloudfront.net/website1/"

# 检查Lambda执行时间
aws logs filter-log-events \
  --log-group-name "/aws/lambda/us-east-1.your-function-name" \
  --filter-pattern "Duration"
```

**解决方案**:
1. 优化Lambda函数代码，减少不必要的计算
2. 增加Lambda函数内存配置（128MB → 256MB）
3. 检查S3存储桶区域设置，确保就近访问

#### 问题: 缓存命中率低
**症状**: 大量请求直接到达Lambda@Edge

**诊断**:
```bash
# 检查CloudFront缓存行为
aws cloudfront get-distribution-config --id YOUR_DISTRIBUTION_ID \
  --query 'DistributionConfig.DefaultCacheBehavior.CachePolicyId'

# 查看缓存统计
# 在CloudFront控制台查看缓存命中率指标
```

**解决方案**:
1. 调整CloudFront缓存策略
2. 设置适当的Cache-Control头部
3. 优化缓存键设置

### 4. 监控和日志问题

#### 问题: 找不到Lambda@Edge日志
**症状**: CloudWatch中没有Lambda函数日志

**解决方案**:
Lambda@Edge日志分布在全球各个区域：
```bash
# 检查不同区域的日志组
aws logs describe-log-groups --region us-east-1 --log-group-name-prefix "/aws/lambda/us-east-1"
aws logs describe-log-groups --region eu-west-1 --log-group-name-prefix "/aws/lambda/eu-west-1"
aws logs describe-log-groups --region ap-southeast-1 --log-group-name-prefix "/aws/lambda/ap-southeast-1"
```

#### 问题: 日志信息不完整
**症状**: 日志中缺少关键调试信息

**解决方案**:
1. 增加Lambda函数中的日志输出
2. 使用结构化日志格式
3. 添加请求ID跟踪

### 5. 测试相关问题

#### 问题: 测试脚本失败
**症状**: `test.sh` 脚本报告多个测试失败

**诊断步骤**:
```bash
# 1. 检查CloudFront域名配置
cat .cloudfront-domain

# 2. 手动测试单个URL
curl -v -L "https://your-domain.cloudfront.net/website1/"

# 3. 检查S3存储桶内容
aws s3 ls s3://your-bucket-name/ --recursive
```

**解决方案**:
1. 确认CloudFront域名正确
2. 验证S3存储桶中存在测试所需的index.html文件
3. 等待CloudFront部署完全完成

#### 问题: 特定测试用例失败
**症状**: 某些特定的重定向场景不工作

**调试方法**:
```bash
# 启用详细日志
export DEBUG=1
./test.sh

# 单独测试失败的URL
curl -v -H "User-Agent: CloudFront-404-Test/1.0" \
  "https://your-domain.cloudfront.net/failing-path"
```

### 6. 紧急恢复程序

#### 如果系统完全不工作

**立即回滚步骤**:
```bash
# 1. 获取上一个Lambda版本
aws lambda list-versions-by-function --function-name YOUR_FUNCTION_NAME

# 2. 回滚到上一个版本
aws lambda publish-version --function-name YOUR_FUNCTION_NAME --code-sha-256 PREVIOUS_SHA

# 3. 更新CloudFront关联
# 使用之前工作的Lambda版本ARN更新CloudFront配置
```

#### 完全重置系统

```bash
# 1. 删除当前Lambda@Edge关联
aws cloudfront get-distribution-config --id YOUR_DISTRIBUTION_ID > current-config.json

# 2. 编辑配置，移除Lambda@Edge关联
# 3. 更新CloudFront分配
aws cloudfront update-distribution --id YOUR_DISTRIBUTION_ID --distribution-config file://reset-config.json --if-match ETAG

# 4. 重新部署
./deploy.sh
```

### 7. 预防措施

#### 部署前检查清单
- [ ] AWS凭证配置正确
- [ ] Lambda函数存在且可访问
- [ ] CloudFront分配ID正确
- [ ] S3存储桶权限设置正确
- [ ] 备份当前工作配置

#### 监控设置
```bash
# 设置CloudWatch告警
aws cloudwatch put-metric-alarm \
  --alarm-name "Lambda-404-Redirect-Errors" \
  --alarm-description "Lambda@Edge function errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

### 8. 获取帮助

如果以上解决方案都无法解决问题：

1. **收集诊断信息**:
   ```bash
   # 运行诊断脚本
   ./diagnose.sh > diagnostic-report.txt
   ```

2. **检查系统状态**:
   - Lambda函数版本和配置
   - CloudFront分配状态
   - S3存储桶权限
   - 最近的部署日志

3. **联系技术支持**:
   - 提供完整的错误信息
   - 包含相关的CloudWatch日志
   - 说明重现问题的步骤

---

**记住**: 大多数问题都与配置错误或部署时间延迟有关。耐心等待CloudFront部署完成（通常需要10-15分钟）通常可以解决许多问题。
