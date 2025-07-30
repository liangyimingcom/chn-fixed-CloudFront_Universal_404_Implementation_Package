'use strict';

/**
 * CloudFront通用微前端404重定向Lambda@Edge函数
 * 
 * 功能特性:
 * - 通用子目录重定向逻辑（无需硬编码子目录名）
 * - 支持中文和特殊字符
 * - 多层级路径重定向到一级子目录
 * - 智能静态资源过滤
 * - 完整的响应头设置
 * - 根目录回退支持
 * 
 * 版本: 1.0
 * 创建时间: 2025-07-30
 * 适用环境: 生产环境
 */

exports.handler = (event, context, callback) => {
    console.log('CloudFront Universal 404 Redirect Lambda@Edge function started');
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        const request = event.Records[0].cf.request;
        
        console.log('Processing request:', {
            uri: request.uri,
            method: request.method,
            headers: request.headers
        });
        
        // 解析路径获取子目录
        const subdirectory = getSubdirectoryFromPath(request.uri);
        console.log('Extracted subdirectory:', subdirectory);
        
        // 检查是否需要重定向
        if (shouldRedirectToIndex(request.uri, subdirectory)) {
            const targetPath = subdirectory ? `/${subdirectory}/index.html` : '/index.html';
            
            console.log(`Redirecting ${request.uri} to ${targetPath}`);
            
            const redirectResponse = createRedirectResponse(targetPath, request.uri, subdirectory);
            callback(null, redirectResponse);
            return;
        }
        
        // 继续正常请求
        console.log('No redirect needed, continuing with original request');
        callback(null, request);
        
    } catch (error) {
        console.error('Error in Lambda@Edge function:', error);
        // 继续原始请求而不是返回错误，确保系统稳定性
        callback(null, event.Records[0].cf.request);
    }
};

/**
 * 从URI路径中提取子目录名称
 * 支持中文和特殊字符
 * 
 * @param {string} uri - 请求URI
 * @returns {string|null} - 子目录名称或null
 * 
 * 示例:
 * - /blog/post → "blog"
 * - /产品/详情 → "产品"
 * - /app-v2/component → "app-v2"
 * - / → null
 */
function getSubdirectoryFromPath(uri) {
    try {
        // 移除开头的斜杠并分割路径
        const pathParts = uri.split('/').filter(part => part);
        
        // 返回第一个路径部分作为子目录
        const subdirectory = pathParts.length > 0 ? pathParts[0] : null;
        
        console.log(`Path analysis: ${uri} → subdirectory: ${subdirectory}`);
        return subdirectory;
        
    } catch (error) {
        console.error('Error in getSubdirectoryFromPath:', error);
        return null;
    }
}

/**
 * 判断是否应该重定向到index.html
 * 包含智能静态资源过滤和边界条件处理
 * 
 * @param {string} uri - 请求URI
 * @param {string|null} subdirectory - 子目录名称
 * @returns {boolean} - 是否需要重定向
 */
function shouldRedirectToIndex(uri, subdirectory) {
    try {
        // 根目录处理
        if (!subdirectory) {
            // 根目录下的不存在文件重定向到根index.html
            // 但排除明显的静态资源
            if (uri !== '/' && !hasStaticExtension(uri)) {
                console.log(`Root level redirect needed for: ${uri}`);
                return true;
            }
            return false;
        }
        
        // 静态资源文件不重定向（Web标准最佳实践）
        if (hasStaticExtension(uri)) {
            console.log(`Static resource detected: ${uri}, not redirecting`);
            return false;
        }
        
        // 子目录访问重定向 (例如: /website1/ 或 /website1)
        if (uri === `/${subdirectory}/` || uri === `/${subdirectory}`) {
            console.log(`Subdirectory access detected: ${uri}`);
            return true;
        }
        
        // 子目录下的404页面重定向 (例如: /website1/missing-page)
        if (uri.startsWith(`/${subdirectory}/`)) {
            console.log(`Subdirectory 404 detected: ${uri}`);
            return true;
        }
        
        return false;
        
    } catch (error) {
        console.error('Error in shouldRedirectToIndex:', error);
        return false;
    }
}

/**
 * 检查URI是否为静态资源
 * 支持常见的Web静态资源类型
 * 
 * @param {string} uri - 请求URI
 * @returns {boolean} - 是否为静态资源
 */
function hasStaticExtension(uri) {
    // 常见静态资源扩展名
    const staticExtensions = [
        // HTML文件
        '.html', '.htm',
        // 样式文件
        '.css', '.scss', '.sass', '.less',
        // JavaScript文件
        '.js', '.mjs', '.jsx', '.ts', '.tsx',
        // 图片文件
        '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.bmp',
        // 字体文件
        '.woff', '.woff2', '.ttf', '.otf', '.eot',
        // 文档文件
        '.pdf', '.txt', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
        // 数据文件
        '.json', '.xml', '.csv', '.yaml', '.yml',
        // 媒体文件
        '.mp4', '.mp3', '.avi', '.mov', '.wmv', '.flv', '.webm', '.ogg',
        // 压缩文件
        '.zip', '.tar', '.gz', '.rar', '.7z',
        // 其他常见文件
        '.map', '.manifest', '.webmanifest'
    ];
    
    const lowerUri = uri.toLowerCase();
    const hasExtension = staticExtensions.some(ext => lowerUri.endsWith(ext));
    
    if (hasExtension) {
        console.log(`Static extension detected in: ${uri}`);
    }
    
    return hasExtension;
}

/**
 * 创建重定向响应
 * 包含完整的响应头设置，与S3代理服务保持一致
 * 
 * @param {string} targetPath - 重定向目标路径
 * @param {string} originalUri - 原始请求URI
 * @param {string|null} subdirectory - 子目录名称
 * @returns {Object} - CloudFront重定向响应对象
 */
function createRedirectResponse(targetPath, originalUri, subdirectory) {
    try {
        // 创建完整的响应头，与S3代理服务保持一致
        const headers = {
            // 重定向位置
            location: [{
                key: 'Location',
                value: targetPath
            }],
            // 缓存控制 - 禁用缓存确保实时性
            'cache-control': [{
                key: 'Cache-Control',
                value: 'no-cache'
            }],
            // CORS支持 - 允许跨域访问
            'access-control-allow-origin': [{
                key: 'Access-Control-Allow-Origin',
                value: '*'
            }],
            // 内容处理 - 内联显示
            'content-disposition': [{
                key: 'Content-Disposition',
                value: 'inline'
            }],
            // 缓存优化 - 根据Origin头进行缓存变化
            'vary': [{
                key: 'Vary',
                value: 'Origin'
            }]
        };
        
        // 添加自定义重定向标识头部（类似S3代理服务）
        if (subdirectory) {
            // 子目录重定向
            headers['x-redirected-from'] = [{
                key: 'X-Redirected-From',
                value: safeHeaderValue(originalUri)
            }];
            headers['x-redirected-to'] = [{
                key: 'X-Redirected-To',
                value: targetPath
            }];
            headers['x-subdirectory-redirect'] = [{
                key: 'X-Subdirectory-Redirect',
                value: 'true'
            }];
        } else {
            // 根目录回退
            headers['x-redirected-from'] = [{
                key: 'X-Redirected-From',
                value: safeHeaderValue(originalUri)
            }];
            headers['x-redirected-to'] = [{
                key: 'X-Redirected-To',
                value: targetPath
            }];
            headers['x-root-fallback'] = [{
                key: 'X-Root-Fallback',
                value: 'true'
            }];
        }
        
        const redirectResponse = {
            status: '302',
            statusDescription: 'Found',
            headers: headers
        };
        
        console.log('Created redirect response:', JSON.stringify(redirectResponse, null, 2));
        
        return redirectResponse;
        
    } catch (error) {
        console.error('Error in createRedirectResponse:', error);
        // 返回简单的重定向响应
        return {
            status: '302',
            statusDescription: 'Found',
            headers: {
                location: [{
                    key: 'Location',
                    value: targetPath
                }]
            }
        };
    }
}

/**
 * URL安全编码函数
 * 处理中文和特殊字符，与S3代理服务的safe_header_value函数类似
 * 
 * @param {string} value - 需要编码的值
 * @returns {string} - 编码后的值
 */
function safeHeaderValue(value) {
    try {
        if (typeof value !== 'string') {
            return String(value);
        }
        
        // 检查是否包含非ASCII字符
        if (/[^\x00-\x7F]/.test(value)) {
            // 包含非ASCII字符，进行URL编码，但保留路径分隔符
            const encoded = encodeURIComponent(value).replace(/%2F/g, '/');
            console.log(`URL encoded: ${value} → ${encoded}`);
            return encoded;
        }
        
        return value;
        
    } catch (error) {
        console.error('Error in safeHeaderValue:', error);
        // 出错时使用基本的URL编码
        return encodeURIComponent(value).replace(/%2F/g, '/');
    }
}

/**
 * 获取请求的客户端信息（用于日志记录）
 * 
 * @param {Object} request - CloudFront请求对象
 * @returns {Object} - 客户端信息
 */
function getClientInfo(request) {
    try {
        const headers = request.headers || {};
        
        return {
            userAgent: headers['user-agent'] ? headers['user-agent'][0].value : 'Unknown',
            clientIp: headers['cloudfront-viewer-address'] ? headers['cloudfront-viewer-address'][0].value : 'Unknown',
            country: headers['cloudfront-viewer-country'] ? headers['cloudfront-viewer-country'][0].value : 'Unknown'
        };
    } catch (error) {
        console.error('Error getting client info:', error);
        return {
            userAgent: 'Unknown',
            clientIp: 'Unknown',
            country: 'Unknown'
        };
    }
}
