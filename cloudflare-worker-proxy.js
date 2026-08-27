/**
 * ETH信号监控 - Cloudflare Workers 代理
 * 彻底解决Flutter Web端CORS问题
 * 
 * 部署步骤：
 * 1. 注册 Cloudflare 账号：https://dash.cloudflare.com/
 * 2. 安装 Wrangler CLI：npm install -g wrangler
 * 3. 登录：wrangler login
 * 4. 创建项目：wrangler init eth-proxy
 * 5. 把此文件内容替换 src/index.js
 * 6. 部署：wrangler deploy
 * 7. 得到你的代理URL，例如 https://eth-proxy.yourname.workers.dev
 * 8. 在APP设置中填入代理URL
 */

// 允许的交易所域名白名单
const ALLOWED_DOMAINS = [
  'api.binance.com',
  'fapi.binance.com',
  'www.okx.com',
  'api.bybit.com',
  'api.bitget.com',
  'api.gateio.ws',
  'api.telegram.org',
];

// CORS头
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request, env, ctx) {
    // 处理OPTIONS预检请求
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    
    // 健康检查
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', time: Date.now() }), {
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      });
    }

    // 代理请求：/proxy?url=https://api.binance.com/...
    if (url.pathname === '/proxy') {
      const targetUrl = url.searchParams.get('url');
      
      if (!targetUrl) {
        return new Response(JSON.stringify({ error: 'Missing url parameter' }), {
          status: 400,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        });
      }

      // 验证域名白名单
      try {
        const target = new URL(targetUrl);
        if (!ALLOWED_DOMAINS.includes(target.hostname)) {
          return new Response(JSON.stringify({ error: 'Domain not allowed' }), {
            status: 403,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          });
        }
      } catch (e) {
        return new Response(JSON.stringify({ error: 'Invalid URL' }), {
          status: 400,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        });
      }

      // 转发请求
      try {
        const proxyRequest = new Request(targetUrl, {
          method: request.method,
          headers: {
            'Content-Type': request.headers.get('Content-Type') || 'application/json',
            'User-Agent': 'ETH-Signal-Proxy/1.0',
          },
          body: request.method !== 'GET' ? request.body : undefined,
        });

        const response = await fetch(proxyRequest);
        const data = await response.text();

        return new Response(data, {
          status: response.status,
          headers: {
            ...CORS_HEADERS,
            'Content-Type': response.headers.get('Content-Type') || 'application/json',
          },
        });
      } catch (e) {
        return new Response(JSON.stringify({ error: 'Proxy request failed', detail: e.message }), {
          status: 502,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        });
      }
    }

    // 默认404
    return new Response(JSON.stringify({ error: 'Not found', usage: '/proxy?url=YOUR_URL' }), {
      status: 404,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  },
};
