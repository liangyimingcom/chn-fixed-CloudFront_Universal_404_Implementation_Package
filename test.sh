#!/bin/bash

# CloudFront通用微前端404重定向系统测试脚本
# 版本: 1.0
# 创建时间: 2025-07-30
# 功能: 全面测试重定向功能，包括中文和特殊字符支持

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
CLOUDFRONT_DOMAIN="d1234567890123.cloudfront.net"  # 替换为实际域名
TEST_TIMEOUT=10
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# 获取CloudFront域名
get_cloudfront_domain() {
    if [ -f ".cloudfront-domain" ]; then
        CLOUDFRONT_DOMAIN=$(cat .cloudfront-domain)
    else
        # 尝试从AWS CLI获取
        local domain=$(aws cloudfront get-distribution \
            --id "E325IR6NR50F34" \
            --query 'Distribution.DomainName' \
            --output text 2>/dev/null)
        
        if [ $? -eq 0 ] && [ "$domain" != "None" ]; then
            CLOUDFRONT_DOMAIN="$domain"
            echo "$domain" > .cloudfront-domain
        else
            log_warning "无法自动获取CloudFront域名，使用默认值"
        fi
    fi
    
    log_info "使用CloudFront域名: $CLOUDFRONT_DOMAIN"
}

# 执行HTTP测试
test_http_request() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local expected_location="$4"
    local description="$5"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo ""
    log_info "测试 $TOTAL_TESTS: $test_name"
    log_info "描述: $description"
    log_info "URL: $url"
    
    # 执行HTTP请求
    local response=$(curl -s -w "\n%{http_code}\n%{redirect_url}\n" \
        --max-time $TEST_TIMEOUT \
        --user-agent "CloudFront-404-Test/1.0" \
        "$url" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "HTTP请求失败 (网络错误或超时)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    # 解析响应
    local body=$(echo "$response" | head -n -2)
    local status_code=$(echo "$response" | tail -n 2 | head -n 1)
    local redirect_url=$(echo "$response" | tail -n 1)
    
    log_info "状态码: $status_code"
    log_info "重定向URL: $redirect_url"
    
    # 验证状态码
    if [ "$status_code" != "$expected_status" ]; then
        log_error "状态码不匹配 (期望: $expected_status, 实际: $status_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    # 验证重定向位置（如果期望重定向）
    if [ "$expected_status" = "302" ] && [ -n "$expected_location" ]; then
        if [[ "$redirect_url" != *"$expected_location"* ]]; then
            log_error "重定向位置不匹配 (期望包含: $expected_location, 实际: $redirect_url)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    fi
    
    log_success "测试通过"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    return 0
}

# 基础重定向测试
test_basic_redirects() {
    echo ""
    echo "========================================"
    echo "基础重定向测试"
    echo "========================================"
    
    # 子目录访问重定向
    test_http_request \
        "子目录访问重定向" \
        "https://$CLOUDFRONT_DOMAIN/website1/" \
        "302" \
        "/website1/index.html" \
        "访问子目录应重定向到index.html"
    
    test_http_request \
        "子目录访问重定向(无斜杠)" \
        "https://$CLOUDFRONT_DOMAIN/website2" \
        "302" \
        "/website2/index.html" \
        "访问子目录(无斜杠)应重定向到index.html"
    
    # 子目录404重定向
    test_http_request \
        "子目录404重定向" \
        "https://$CLOUDFRONT_DOMAIN/website1/missing-page" \
        "302" \
        "/website1/index.html" \
        "子目录下不存在的页面应重定向到子目录index.html"
    
    test_http_request \
        "子目录深层404重定向" \
        "https://$CLOUDFRONT_DOMAIN/app1/components/button" \
        "302" \
        "/app1/index.html" \
        "子目录下多层路径应重定向到子目录index.html"
}

# 中文字符测试
test_chinese_characters() {
    echo ""
    echo "========================================"
    echo "中文字符支持测试"
    echo "========================================"
    
    test_http_request \
        "中文子目录重定向" \
        "https://$CLOUDFRONT_DOMAIN/产品/" \
        "302" \
        "/产品/index.html" \
        "中文子目录应正确重定向"
    
    test_http_request \
        "中文子目录404重定向" \
        "https://$CLOUDFRONT_DOMAIN/产品/详情" \
        "302" \
        "/产品/index.html" \
        "中文子目录下的404应重定向到中文子目录index.html"
    
    test_http_request \
        "中文文档子目录" \
        "https://$CLOUDFRONT_DOMAIN/文档/api" \
        "302" \
        "/文档/index.html" \
        "中文文档子目录404重定向"
}

# 特殊字符测试
test_special_characters() {
    echo ""
    echo "========================================"
    echo "特殊字符支持测试"
    echo "========================================"
    
    test_http_request \
        "连字符子目录" \
        "https://$CLOUDFRONT_DOMAIN/app-v2/" \
        "302" \
        "/app-v2/index.html" \
        "包含连字符的子目录应正确重定向"
    
    test_http_request \
        "下划线子目录" \
        "https://$CLOUDFRONT_DOMAIN/app_v3/component" \
        "302" \
        "/app_v3/index.html" \
        "包含下划线的子目录404重定向"
    
    test_http_request \
        "数字子目录" \
        "https://$CLOUDFRONT_DOMAIN/app123/test" \
        "302" \
        "/app123/index.html" \
        "包含数字的子目录404重定向"
}

# 静态资源测试
test_static_resources() {
    echo ""
    echo "========================================"
    echo "静态资源过滤测试"
    echo "========================================"
    
    # 这些测试期望返回403或404，而不是重定向
    test_http_request \
        "CSS文件访问" \
        "https://$CLOUDFRONT_DOMAIN/website1/style.css" \
        "403" \
        "" \
        "CSS文件应返回403而不是重定向"
    
    test_http_request \
        "JavaScript文件访问" \
        "https://$CLOUDFRONT_DOMAIN/website1/app.js" \
        "403" \
        "" \
        "JavaScript文件应返回403而不是重定向"
    
    test_http_request \
        "图片文件访问" \
        "https://$CLOUDFRONT_DOMAIN/website1/logo.png" \
        "403" \
        "" \
        "图片文件应返回403而不是重定向"
    
    test_http_request \
        "字体文件访问" \
        "https://$CLOUDFRONT_DOMAIN/website1/font.woff2" \
        "403" \
        "" \
        "字体文件应返回403而不是重定向"
}

# 边界条件测试
test_edge_cases() {
    echo ""
    echo "========================================"
    echo "边界条件测试"
    echo "========================================"
    
    test_http_request \
        "根目录访问" \
        "https://$CLOUDFRONT_DOMAIN/" \
        "200" \
        "" \
        "根目录应正常访问"
    
    test_http_request \
        "根目录404回退" \
        "https://$CLOUDFRONT_DOMAIN/nonexistent-page" \
        "302" \
        "/index.html" \
        "根目录下不存在的页面应回退到根index.html"
    
    test_http_request \
        "多层级路径重定向" \
        "https://$CLOUDFRONT_DOMAIN/website1/deep/nested/path" \
        "302" \
        "/website1/index.html" \
        "多层级路径应重定向到一级子目录index.html"
}

# 性能测试
test_performance() {
    echo ""
    echo "========================================"
    echo "性能测试"
    echo "========================================"
    
    log_info "执行性能测试..."
    
    local test_url="https://$CLOUDFRONT_DOMAIN/website1/performance-test"
    local total_time=0
    local test_count=5
    
    for i in $(seq 1 $test_count); do
        local start_time=$(date +%s%N)
        
        curl -s -o /dev/null \
            --max-time $TEST_TIMEOUT \
            --user-agent "CloudFront-404-Performance-Test/1.0" \
            "$test_url" 2>/dev/null
        
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒
        
        log_info "测试 $i: ${duration}ms"
        total_time=$((total_time + duration))
    done
    
    local avg_time=$((total_time / test_count))
    log_info "平均响应时间: ${avg_time}ms"
    
    if [ $avg_time -lt 2000 ]; then
        log_success "性能测试通过 (平均响应时间 < 2秒)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_warning "性能测试警告 (平均响应时间 >= 2秒)"
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# 生成测试报告
generate_report() {
    echo ""
    echo "========================================"
    echo "测试报告"
    echo "========================================"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    echo "总测试数: $TOTAL_TESTS"
    echo "通过测试: $PASSED_TESTS"
    echo "失败测试: $FAILED_TESTS"
    echo "成功率: ${success_rate}%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "所有测试通过！系统运行正常"
        echo ""
        log_info "系统特性验证:"
        echo "  ✓ 通用子目录重定向支持"
        echo "  ✓ 中文字符完全支持"
        echo "  ✓ 特殊字符处理正确"
        echo "  ✓ 静态资源智能过滤"
        echo "  ✓ 多层级路径重定向"
        echo "  ✓ 根目录回退机制"
        echo "  ✓ 性能表现良好"
        return 0
    else
        log_error "存在失败的测试，请检查系统配置"
        return 1
    fi
}

# 主测试流程
main() {
    echo "========================================"
    echo "CloudFront通用微前端404重定向系统测试"
    echo "========================================"
    echo ""
    
    # 获取CloudFront域名
    get_cloudfront_domain
    
    # 确认开始测试
    read -p "确认开始测试? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "测试已取消"
        exit 0
    fi
    
    # 执行测试套件
    test_basic_redirects
    test_chinese_characters
    test_special_characters
    test_static_resources
    test_edge_cases
    test_performance
    
    # 生成报告
    generate_report
}

# 执行主函数
main "$@"
