# 自建后端代理部署指南（Cloudflare Workers）

## 为什么需要自建代理？

Flutter Web端直接请求交易所API会遇到CORS跨域限制。目前使用的免费代理（corsproxy.io等）存在以下问题：
- 请求频率限制
- 不稳定，偶尔超时
- 大数据量请求（K线）容易失败

自建Cloudflare Workers代理可以彻底解决这些问题，免费版每天10万次请求，完全够用。

## 部署步骤

### 1. 注册Cloudflare账号
访问 https://dash.cloudflare.com/ 注册免费账号

### 2. 安装Wrangler CLI
```bash
npm install -g wrangler
```

### 3. 登录
```bash
wrangler login
```
浏览器会自动打开，授权登录

### 4. 创建项目
```bash
wrangler init eth-proxy
```
选择：
- TypeScript? No
- Worker? Yes
- Git? No

### 5. 替换代码
把 `cloudflare-worker-proxy.js` 的内容复制到 `src/index.js`

### 6. 部署
```bash
cd eth-proxy
wrangler deploy
```

部署成功后会显示你的Worker URL，例如：
```
https://eth-proxy.yourname.workers.dev
```

### 7. 测试代理
在浏览器中访问：
```
https://eth-proxy.yourname.workers.dev/health
```
应该返回 `{"status":"ok","time":...}`

测试代理请求：
```
https://eth-proxy.yourname.workers.dev/proxy?url=https://fapi.binance.com/fapi/v1/ticker/price?symbol=ETHUSDT
```
应该返回ETH价格数据

### 8. 在APP中配置
1. 打开APP → 设置页面
2. 找到"自定义代理"设置
3. 填入你的Worker URL，例如 `https://eth-proxy.yourname.workers.dev/proxy?url=`
4. 保存

## 安全说明

- 代理只允许白名单内的交易所域名，防止被滥用
- 不存储任何请求数据
- 免费版每天10万次请求，8秒轮询一天约10800次，完全够用
- 如需更高限额，可升级Cloudflare付费版（$5/月，1000万次请求）

## 故障排查

### 部署失败
- 检查Wrangler是否登录成功：`wrangler whoami`
- 检查Node.js版本是否>=16

### 代理请求失败
- 检查URL是否正确，必须以 `/proxy?url=` 开头
- 检查目标URL是否在白名单内
- 查看Cloudflare Workers日志：`wrangler tail`

### CORS错误
- 确认Worker已正确部署
- 确认APP中配置的代理URL正确
- 尝试清除浏览器缓存
