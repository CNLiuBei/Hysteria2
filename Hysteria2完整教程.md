# Hysteria 2 完整搭建教程 - 速度最快的代理方案

## 简介

Hysteria 2 是目前速度最快的代理协议，基于 QUIC 协议，专为恶劣网络环境优化。

### 核心优势
- ✅ **速度最快** - 可跑满带宽
- ✅ **抗丢包** - 5% 丢包环境下依然高速
- ✅ **低延迟** - 游戏、视频完美体验
- ✅ **易部署** - 一键安装，5 分钟搞定
- ✅ **跨平台** - 支持所有主流平台

---

## 快速开始（3 分钟）

### 一键安装
```bash
bash hysteria2-install.sh
```

安装完成后会显示：
- 服务器地址
- 端口
- 密码
- 分享链接

直接导入客户端即可使用！

---

## 详细安装步骤

### 1. 安装 Hysteria 2

```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

### 2. 生成自签名证书

```bash
# 创建配置目录
mkdir -p /etc/hysteria

# 生成证书
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=bing.com" \
  -days 36500
```

### 3. 创建服务器配置

创建 `/etc/hysteria/config.yaml`：

```yaml
# 监听端口
listen: :443

# TLS 配置
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

# 认证
auth:
  type: password
  password: your_strong_password  # 修改为强密码

# 伪装网站（被探测时显示）
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

# QUIC 参数优化
quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

# 带宽限制（根据实际情况调整）
bandwidth:
  up: 1 gbps    # 上传带宽
  down: 1 gbps  # 下载带宽

# 其他配置
ignoreClientBandwidth: false  # 是否忽略客户端带宽设置
speedTest: false              # 是否启用速度测试
disableUDP: false             # 是否禁用 UDP
udpIdleTimeout: 60s           # UDP 空闲超时
```

### 4. 创建系统服务

创建 `/etc/systemd/system/hysteria-server.service`：

```ini
[Unit]
Description=Hysteria Server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
User=root
Group=root
Environment="HYSTERIA_LOG_LEVEL=info"
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
```

### 5. 启动服务

```bash
# 重载 systemd
systemctl daemon-reload

# 启动服务
systemctl start hysteria-server

# 设置开机自启
systemctl enable hysteria-server

# 查看状态
systemctl status hysteria-server
```

### 6. 配置防火墙

```bash
# UFW (Ubuntu/Debian)
ufw allow 443/udp

# Firewalld (CentOS)
firewall-cmd --permanent --add-port=443/udp
firewall-cmd --reload
```

---

## 客户端配置

### Windows

**1. 下载客户端**
- 官方：https://github.com/apernet/hysteria/releases
- 下载 `hysteria-windows-amd64.exe`

**2. 创建配置文件 `config.yaml`**
```yaml
server: your-server-ip:443

auth: your_password

tls:
  sni: bing.com
  insecure: true

bandwidth:
  up: 100 mbps
  down: 500 mbps

fastOpen: true
lazy: false

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080
```

**3. 运行**
```cmd
hysteria-windows-amd64.exe -c config.yaml
```

**4. 配置系统代理**
- SOCKS5: 127.0.0.1:1080
- HTTP: 127.0.0.1:8080

### Mac

**1. 下载**
```bash
curl -Lo hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-darwin-amd64
chmod +x hysteria
```

**2. 配置同 Windows**

**3. 运行**
```bash
./hysteria -c config.yaml
```

### Linux

**1. 安装**
```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

**2. 创建客户端配置 `/etc/hysteria/client.yaml`**

**3. 运行**
```bash
hysteria -c /etc/hysteria/client.yaml
```

### Android

**使用 SagerNet**

1. 下载：https://github.com/SagerNet/SagerNet/releases
2. 安装 APK
3. 点击 + 号 → 手动设置 → Hysteria 2
4. 填写配置：
   - 服务器：your-server-ip
   - 端口：443
   - 密码：your_password
   - SNI：bing.com
   - 允许不安全：开启

或直接导入分享链接：
```
hysteria2://your_password@your-server-ip:443/?insecure=1&sni=bing.com#Hysteria2
```

### iOS

**使用 Shadowrocket**

1. App Store 下载 Shadowrocket（需美区账号）
2. 点击右上角 +
3. 类型选择 Hysteria 2
4. 填写配置或扫描二维码

---

## 高级配置

### 使用真实域名和证书

**1. 申请证书**
```bash
# 安装 acme.sh
curl https://get.acme.sh | sh

# 申请证书
~/.acme.sh/acme.sh --register-account -m your@email.com
~/.acme.sh/acme.sh --issue -d your-domain.com --standalone

# 安装证书
~/.acme.sh/acme.sh --installcert -d your-domain.com \
  --key-file /etc/hysteria/server.key \
  --fullchain-file /etc/hysteria/server.crt
```

**2. 修改配置**
```yaml
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

masquerade:
  type: proxy
  proxy:
    url: https://your-domain.com
    rewriteHost: true
```

### 多用户配置

```yaml
auth:
  type: userpass
  userpass:
    user1: password1
    user2: password2
    user3: password3
```

### 流量统计

```yaml
trafficStats:
  listen: :8080
  secret: your_secret_key
```

访问 `http://your-server-ip:8080/traffic?secret=your_secret_key` 查看流量。

### 端口跳跃

```yaml
listen: :20000-30000  # 使用端口范围
```

客户端配置：
```yaml
server: your-server-ip:20000-30000
```

---

## 性能优化

### 1. 系统优化

```bash
cat >> /etc/sysctl.conf <<EOF
# 增加 UDP 缓冲区
net.core.rmem_max=2500000
net.core.wmem_max=2500000

# BBR 拥塞控制
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# 增加文件描述符
fs.file-max=51200

# 网络优化
net.core.netdev_max_backlog=250000
net.core.somaxconn=4096
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.ip_local_port_range=10000 65000
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=5000
EOF

sysctl -p
```

### 2. 带宽设置

根据实际带宽调整：

**服务器端**：
```yaml
bandwidth:
  up: 500 mbps    # VPS 上传带宽
  down: 500 mbps  # VPS 下载带宽
```

**客户端**：
```yaml
bandwidth:
  up: 50 mbps     # 本地上传带宽
  down: 200 mbps  # 本地下载带宽
```

### 3. QUIC 参数调优

```yaml
quic:
  initStreamReceiveWindow: 16777216      # 16MB
  maxStreamReceiveWindow: 16777216       # 16MB
  initConnReceiveWindow: 33554432        # 32MB
  maxConnReceiveWindow: 33554432         # 32MB
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false
```

---

## 管理命令

```bash
# 启动
systemctl start hysteria-server

# 停止
systemctl stop hysteria-server

# 重启
systemctl restart hysteria-server

# 查看状态
systemctl status hysteria-server

# 查看日志
journalctl -u hysteria-server -f

# 查看实时日志（详细）
journalctl -u hysteria-server -f --output=cat

# 测试配置
hysteria server -c /etc/hysteria/config.yaml --test
```

---

## 故障排查

### 1. 无法连接

**检查服务状态**：
```bash
systemctl status hysteria-server
```

**检查端口监听**：
```bash
ss -ulnp | grep hysteria
```

**检查防火墙**：
```bash
ufw status
firewall-cmd --list-all
```

### 2. 速度慢

**检查带宽设置**：
- 确保服务器和客户端带宽设置正确
- 不要设置过高或过低

**检查 BBR**：
```bash
sysctl net.ipv4.tcp_congestion_control
```

**查看日志**：
```bash
journalctl -u hysteria-server -n 100
```

### 3. 连接不稳定

**调整 QUIC 参数**：
```yaml
quic:
  maxIdleTimeout: 60s  # 增加超时时间
```

**检查 UDP 丢包**：
```bash
netstat -su | grep -i "packet receive errors"
```

---

## 性能测试

### 速度测试

```bash
# 使用 iperf3
iperf3 -c speedtest.net -p 5201

# 使用 speedtest-cli
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

### 延迟测试

```bash
# ping 测试
ping -c 10 your-server-ip

# mtr 测试
mtr -r -c 100 your-server-ip
```

---

## 安全建议

### 1. 使用强密码
```bash
# 生成随机密码
openssl rand -base64 32
```

### 2. 更改默认端口
```yaml
listen: :12345  # 使用非标准端口
```

### 3. 限制连接数
```yaml
# 在配置中添加
acl:
  inline:
    - reject(all, udp/443)  # 禁止特定流量
```

### 4. 定期更新
```bash
bash <(curl -fsSL https://get.hy2.sh/)
systemctl restart hysteria-server
```

---

## 实战案例

### 案例 1：个人使用

**配置**：
- 带宽：100M
- 用户：1 人
- 用途：日常浏览、视频

**服务器配置**：
```yaml
bandwidth:
  up: 100 mbps
  down: 100 mbps
```

### 案例 2：多人共享

**配置**：
- 带宽：500M
- 用户：5 人
- 用途：共享使用

**服务器配置**：
```yaml
auth:
  type: userpass
  userpass:
    user1: pass1
    user2: pass2
    user3: pass3
    user4: pass4
    user5: pass5

bandwidth:
  up: 500 mbps
  down: 500 mbps
```

### 案例 3：游戏加速

**配置**：
- 优先低延迟
- UDP 优化

**服务器配置**：
```yaml
quic:
  maxIdleTimeout: 60s
  disablePathMTUDiscovery: false

bandwidth:
  up: 200 mbps
  down: 200 mbps
```

---

## 总结

### 优势
- ✅ 速度最快，可跑满带宽
- ✅ 抗丢包能力强
- ✅ 延迟低，适合游戏
- ✅ 配置简单
- ✅ 跨平台支持好

### 适用场景
- 高速下载
- 4K/8K 视频
- 游戏加速
- 日常使用

### 注意事项
- 需要 UDP 端口
- 部分运营商可能限制 UDP
- 建议配合 BBR 使用

**开始享受最快的代理体验吧！** 🚀
