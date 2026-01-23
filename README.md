# glash

🚀 基于最新 **Mihomo v1.19.18** 内核 + **MetacubexD** Dashboard 的 Clash Docker 镜像


## 特性

- ✅ Mihomo (Clash Meta) v1.19.18 内核
- ✅ MetacubexD Web Dashboard 内置
- ✅ 预打包 GeoIP 数据库，无需运行时下载
- ✅ 支持 amd64 / arm64 架构
- ✅ **订阅功能**：支持远程订阅链接自动下载配置
- ✅ **自动更新**：支持定时自动更新订阅并重启生效
- ✅ **容错处理**：订阅下载失败时自动回退到本地配置

## 支持的协议

| 协议 | 说明 |
| ---- | ---- |
| Shadowsocks (SS) | 经典轻量级加密代理 |
| VMess | V2Ray 原生协议 |
| VLESS | V2Ray 轻量协议，性能更优 |
| Trojan | 基于 TLS 的隐蔽协议 |
| Hysteria | 基于 QUIC 的高速协议 |
| Hysteria2 | Hysteria 第二代，更快更稳 |
| TUIC | 基于 QUIC 的多路复用协议 |
| WireGuard | 现代化 VPN 协议 |
| HTTP | HTTP/HTTPS 代理 |
| SOCKS5 | 通用 SOCKS5 代理 |

## 快速开始

### Docker Run

```bash
docker run -d \
  --name glash \
  --restart unless-stopped \
  -p 7890:7890 \
  -p 7891:7891 \
  -p 9090:9090 \
  -v /path/to/config.yaml:/root/.config/mihomo/config.yaml:ro \
  gangz1o/glash:latest
```

### 指定架构下载

默认自动匹配当前平台，如需指定架构：

```bash
# x86_64 / amd64
docker pull --platform linux/amd64 gangz1o/glash:latest

# ARM64 (Apple Silicon / ARM 服务器)
docker pull --platform linux/arm64 gangz1o/glash:latest
```

### Docker Compose

```yaml
services:
  glash:
    image: gangz1o/glash:latest
    container_name: glash
    restart: unless-stopped
    ports:
      - '7890:7890' # HTTP 代理
      - '7891:7891' # SOCKS5 代理
      - '9090:9090' # Dashboard
    volumes:
      - ./config.yaml:/root/.config/mihomo/config.yaml:ro
```

## 订阅功能

glash 支持通过订阅链接自动下载和更新配置文件，无需手动维护 `config.yaml`。

### 环境变量

| 变量 | 说明 | 示例 |
| ---- | ---- | ---- |
| `SUB_URL` | 订阅地址，支持返回 Clash 配置的链接 | `https://example.com/sub` |
| `SUB_CRON` | 自动更新的 cron 表达式 | `0 */6 * * *` |
| `SECRET` | Dashboard 登录密钥，会自动注入配置 | `my-password` |
| `DOWNLOAD_PROXY` | 首次下载订阅时使用的外部代理（可选） | `http://192.168.1.1:7890` |

### 使用订阅（推荐）

```bash
docker run -d \
  --name glash \
  --restart unless-stopped \
  -p 7890:7890 \
  -p 7891:7891 \
  -p 9090:9090 \
  -v /path/to/config:/root/.config/mihomo \
  -e SUB_URL=https://your-subscription-url.com/config \
  -e SUB_CRON="0 */6 * * *" \
  -e SECRET=your-dashboard-password \
  gangz1o/glash:latest
```

### Docker Compose（订阅模式）

```yaml
services:
  glash:
    image: gangz1o/glash:latest
    container_name: glash
    restart: unless-stopped
    ports:
      - '7890:7890'
      - '7891:7891'
      - '9090:9090'
    volumes:
      - ./config:/root/.config/mihomo
    environment:
      - TZ=Asia/Shanghai
      - SUB_URL=https://your-subscription-url.com/config
      - SUB_CRON=0 */6 * * *
      - SECRET=your-dashboard-password
```

### 工作逻辑

1. **启动时（本地有配置）**：
   - 先用本地配置启动 mihomo
   - 等待代理服务就绪后，通过本地代理 (127.0.0.1:7890) 更新订阅
   - 更新成功后自动重启生效

2. **启动时（本地无配置）**：
   - 先尝试直连下载订阅
   - 直连失败时，如果设置了 `DOWNLOAD_PROXY`，使用外部代理下载
   - 下载成功后启动 mihomo

3. **定时更新**：
   - 如果设置了 `SUB_CRON`，按照 cron 表达式定时更新
   - 通过本地代理下载订阅
   - 更新成功后自动重启 mihomo 生效
   - 更新失败时保持当前配置运行

4. **SECRET 注入**：
   - 如果设置了 `SECRET`，会自动写入配置文件的 `secret` 字段
   - 方便统一管理 Dashboard 密码

> **提示**：如果订阅地址需要代理访问且本地没有配置文件，请设置 `DOWNLOAD_PROXY` 指向一个可用的代理。

### 常用 Cron 表达式

| 表达式 | 说明 |
| ------ | ---- |
| `0 */6 * * *` | 每 6 小时更新 |
| `0 0 * * *` | 每天凌晨更新 |
| `0 */12 * * *` | 每 12 小时更新 |
| `*/30 * * * *` | 每 30 分钟更新 |
| `0 8 * * *` | 每天早上 8 点更新 |

### 查看订阅更新日志

```bash
docker exec glash cat /var/log/subscription.log
```

## ⚠️ 配置要求

你的 `config.yaml` 必须包含以下配置才能正常使用 Dashboard：

```yaml
# 允许外部访问 API
external-controller: 0.0.0.0:9090
或者是
external-controller::9090
# 密钥（用于登录dashboard ，可不填，建议填上，提高安全性）
secret: ''
```

## 端口说明

| 端口 | 用途                     |
| ---- | ------------------------ |
| 7890 | HTTP 代理                |
| 7891 | SOCKS5 代理              |
| 7892 | 混合代理 (HTTP + SOCKS5) |
| 9090 | RESTful API & Dashboard  |

## Dashboard 访问

启动后访问：http://127.0.0.1:9090/ui/
![h1FjVgrMZpnADJ70Tp5wjzp3KloXMkvB.webp](https://cdn.nodeimage.com/i/h1FjVgrMZpnADJ70Tp5wjzp3KloXMkvB.webp)

首次访问需要配置：

- 后端地址：`http://127.0.0.1:9090`
- 密钥：与 config.yaml 中的 `secret` 一致

## 配置示例

```yaml
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info

# Dashboard 必需配置
external-controller: 0.0.0.0:9090
secret: ''

proxies:
  - name: '节点名称'
    type: vmess
    server: example.com
    port: 443
    uuid: your-uuid
    # ... 其他配置

proxy-groups:
  - name: '🚀 节点选择'
    type: select
    proxies:
      - 节点名称

rules:
  - GEOIP,CN,DIRECT
  - MATCH,🚀 节点选择
```
## 界面一览
![NUhSXxFpzP5AkQgOM0F5SaCOYEdUOMpG.webp](https://cdn.nodeimage.com/i/NUhSXxFpzP5AkQgOM0F5SaCOYEdUOMpG.webp)
![dIMBzYuhfUcBZ9pml6p8SK6dCK7fcZAK.webp](https://cdn.nodeimage.com/i/dIMBzYuhfUcBZ9pml6p8SK6dCK7fcZAK.webp)
![qNyg0qN1s0yAKK2VDwmzUFznng39WrHN.webp](https://cdn.nodeimage.com/i/qNyg0qN1s0yAKK2VDwmzUFznng39WrHN.webp)
![LYlfD2Av4Pryg1y3bcBCjrQZ7NQdjkSU.webp](https://cdn.nodeimage.com/i/LYlfD2Av4Pryg1y3bcBCjrQZ7NQdjkSU.webp)
![hNFus4r6SRr5gP7sz0oZcgcEITN9NaZO.webp](https://cdn.nodeimage.com/i/hNFus4r6SRr5gP7sz0oZcgcEITN9NaZO.webp)

## 版本信息

- **Mihomo**: v1.19.18
- **MetacubexD**: v1.186.1
- **架构**: linux/amd64, linux/arm64

## 致谢

感谢以下开源项目：

- [Mihomo](https://github.com/MetaCubeX/mihomo) - 强大的代理内核
- [MetacubexD](https://github.com/MetaCubeX/metacubexd) - 现代化 Web Dashboard
- [meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) - GeoIP & GeoSite 数据库

## License

MIT
