#!/bin/bash

# CloudFront通用微前端404重定向系统部署脚本
# 版本: 1.0
# 创建时间: 2025-07-30
# 功能: 自动化部署Lambda@Edge函数和CloudFront配置

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
LAMBDA_FUNCTION_NAME="micro-frontend-404-poc-frankfurt-404-redirect"
CLOUDFRONT_DISTRIBUTION_ID="E325IR6NR50F34"
S3_BUCKET="micro-frontend-404-poc-frankfurt-153705321444-eu-central-1"
AWS_REGION="us-east-1"  # Lambda@Edge必须在us-east-1
LAMBDA_ROLE_ARN="arn:aws:iam::153705321444:role/lambda-edge-execution-role"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要工具
check_prerequisites() {
    log_info "检查部署前置条件..."
    
    # 检查AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI未安装，请先安装AWS CLI"
        exit 1
    fi
    
    # 检查AWS凭证
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS凭证未配置，请运行 'aws configure'"
        exit 1
    fi
    
    # 检查必要文件
    if [ ! -f "universal-lambda-edge.js" ]; then
        log_error "Lambda函数文件 universal-lambda-edge.js 不存在"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# 创建Lambda函数部署包
create_deployment_package() {
    log_info "创建Lambda函数部署包..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    
    # 复制Lambda函数文件
    cp universal-lambda-edge.js "$TEMP_DIR/index.js"
    
    # 创建ZIP包
    cd "$TEMP_DIR"
    zip -r lambda-function.zip index.js
    
    # 移动到工作目录
    mv lambda-function.zip "$OLDPWD/"
    
    # 清理临时目录
    cd "$OLDPWD"
    rm -rf "$TEMP_DIR"
    
    log_success "部署包创建完成: lambda-function.zip"
}

# 更新Lambda函数
update_lambda_function() {
    log_info "更新Lambda@Edge函数..."
    
    # 更新函数代码
    aws lambda update-function-code \
        --region "$AWS_REGION" \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --zip-file fileb://lambda-function.zip \
        --output table
    
    if [ $? -eq 0 ]; then
        log_success "Lambda函数代码更新成功"
    else
        log_error "Lambda函数代码更新失败"
        exit 1
    fi
    
    # 等待函数更新完成
    log_info "等待函数更新完成..."
    aws lambda wait function-updated \
        --region "$AWS_REGION" \
        --function-name "$LAMBDA_FUNCTION_NAME"
    
    # 发布新版本
    log_info "发布Lambda函数新版本..."
    NEW_VERSION=$(aws lambda publish-version \
        --region "$AWS_REGION" \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --description "Universal 404 redirect implementation - $(date '+%Y-%m-%d %H:%M:%S')" \
        --query 'Version' \
        --output text)
    
    if [ $? -eq 0 ]; then
        log_success "Lambda函数新版本发布成功: $NEW_VERSION"
        echo "$NEW_VERSION" > .lambda-version
    else
        log_error "Lambda函数版本发布失败"
        exit 1
    fi
}

# 更新CloudFront分配
update_cloudfront_distribution() {
    log_info "更新CloudFront分配配置..."
    
    # 读取Lambda版本
    if [ ! -f ".lambda-version" ]; then
        log_error "Lambda版本文件不存在，请先更新Lambda函数"
        exit 1
    fi
    
    LAMBDA_VERSION=$(cat .lambda-version)
    LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:153705321444:function:$LAMBDA_FUNCTION_NAME:$LAMBDA_VERSION"
    
    log_info "使用Lambda函数版本: $LAMBDA_VERSION"
    log_info "Lambda ARN: $LAMBDA_ARN"
    
    # 获取当前分配配置
    log_info "获取当前CloudFront分配配置..."
    aws cloudfront get-distribution-config \
        --id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --output json > current-config.json
    
    if [ $? -ne 0 ]; then
        log_error "获取CloudFront分配配置失败"
        exit 1
    fi
    
    # 提取ETag
    ETAG=$(jq -r '.ETag' current-config.json)
    log_info "当前配置ETag: $ETAG"
    
    # 更新配置中的Lambda@Edge关联
    log_info "更新Lambda@Edge关联..."
    jq --arg lambda_arn "$LAMBDA_ARN" '
        .DistributionConfig.DefaultCacheBehavior.LambdaFunctionAssociations.Items[0].LambdaFunctionARN = $lambda_arn |
        del(.ETag)
    ' current-config.json > updated-config.json
    
    # 应用更新的配置
    log_info "应用CloudFront配置更新..."
    aws cloudfront update-distribution \
        --id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --distribution-config file://updated-config.json \
        --if-match "$ETAG" \
        --output table
    
    if [ $? -eq 0 ]; then
        log_success "CloudFront分配更新成功"
    else
        log_error "CloudFront分配更新失败"
        exit 1
    fi
    
    # 等待分配部署完成
    log_info "等待CloudFront分配部署完成（这可能需要几分钟）..."
    aws cloudfront wait distribution-deployed \
        --id "$CLOUDFRONT_DISTRIBUTION_ID"
    
    if [ $? -eq 0 ]; then
        log_success "CloudFront分配部署完成"
    else
        log_warning "CloudFront分配部署等待超时，但更新可能仍在进行中"
    fi
}

# 创建缓存失效
create_cache_invalidation() {
    log_info "创建CloudFront缓存失效..."
    
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)
    
    if [ $? -eq 0 ]; then
        log_success "缓存失效创建成功: $INVALIDATION_ID"
        log_info "缓存失效通常需要10-15分钟完成"
    else
        log_warning "缓存失效创建失败，但不影响部署"
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署结果..."
    
    # 获取CloudFront域名
    DOMAIN_NAME=$(aws cloudfront get-distribution \
        --id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --query 'Distribution.DomainName' \
        --output text)
    
    if [ $? -eq 0 ]; then
        log_success "CloudFront域名: $DOMAIN_NAME"
        
        # 提供测试URL
        echo ""
        log_info "测试URL示例:"
        echo "  - https://$DOMAIN_NAME/website1/"
        echo "  - https://$DOMAIN_NAME/website2/missing-page"
        echo "  - https://$DOMAIN_NAME/产品/"
        echo "  - https://$DOMAIN_NAME/app-v2/component"
        echo ""
        
        log_info "运行测试脚本: ./test.sh"
    else
        log_warning "无法获取CloudFront域名"
    fi
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    
    rm -f lambda-function.zip
    rm -f current-config.json
    rm -f updated-config.json
    
    log_success "清理完成"
}

# 主部署流程
main() {
    echo "========================================"
    echo "CloudFront通用微前端404重定向系统部署"
    echo "========================================"
    echo ""
    
    # 显示配置信息
    log_info "部署配置:"
    echo "  Lambda函数: $LAMBDA_FUNCTION_NAME"
    echo "  CloudFront分配: $CLOUDFRONT_DISTRIBUTION_ID"
    echo "  S3存储桶: $S3_BUCKET"
    echo "  AWS区域: $AWS_REGION"
    echo ""
    
    # 确认部署
    read -p "确认开始部署? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    # 执行部署步骤
    check_prerequisites
    create_deployment_package
    update_lambda_function
    update_cloudfront_distribution
    create_cache_invalidation
    verify_deployment
    cleanup
    
    echo ""
    log_success "部署完成！"
    echo "========================================"
}

# 错误处理
trap 'log_error "部署过程中发生错误，正在清理..."; cleanup; exit 1' ERR

# 执行主函数
main "$@"
