# glash

🚀 基于最新 **Mihomo v1.19.18** 内核 + **MetacubexD** Dashboard 的 Clash Docker 镜像

## 特性

- ✅ Mihomo (Clash Meta) v1.19.18 内核
- ✅ MetacubexD Web Dashboard 内置
- ✅ 预打包 GeoIP 数据库，无需运行时下载
- ✅ 支持 amd64 / arm64 架构

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

## ⚠️ 配置要求

你的 `config.yaml` 必须包含以下配置才能正常使用 Dashboard：

```yaml
# 允许外部访问 API（必须是 0.0.0.0）
external-controller: 0.0.0.0:9090
# 密钥（可为空）
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
