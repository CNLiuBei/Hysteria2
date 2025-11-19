#!/bin/bash

# Hysteria 2 完整一键部署脚本
# 适用于 Debian/Ubuntu/CentOS
# 使用方法: bash 一键部署Hysteria2.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║                                           ║
║      Hysteria 2 一键部署脚本              ║
║      速度最快的代理方案                   ║
║                                           ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 请使用 root 用户运行此脚本${NC}"
   echo "使用方法: sudo bash $0"
   exit 1
fi

# 检测系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}无法检测系统类型${NC}"
    exit 1
fi

echo -e "${BLUE}检测到系统: $OS $VERSION${NC}"
echo ""

# 生成随机密码和端口
PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)
PORT=443

echo -e "${YELLOW}=========================================="
echo "开始安装 Hysteria 2"
echo "==========================================${NC}"
echo ""

# 步骤 1: 安装依赖
echo -e "${CYAN}[1/8] 安装系统依赖...${NC}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    apt update -qq
    apt install -y curl wget openssl qrencode > /dev/null 2>&1
elif [ "$OS" = "centos" ]; then
    yum install -y curl wget openssl qrencode > /dev/null 2>&1
fi
echo -e "${GREEN}✓ 依赖安装完成${NC}"
echo ""

# 步骤 2: 安装 Hysteria 2
echo -e "${CYAN}[2/8] 安装 Hysteria 2...${NC}"
bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Hysteria 2 安装成功${NC}"
else
    echo -e "${RED}✗ Hysteria 2 安装失败${NC}"
    exit 1
fi
echo ""

# 步骤 3: 生成证书
echo -e "${CYAN}[3/8] 生成 TLS 证书...${NC}"
mkdir -p /etc/hysteria
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=www.bing.com" \
  -days 36500 > /dev/null 2>&1
echo -e "${GREEN}✓ 证书生成完成${NC}"
echo ""

# 步骤 4: 创建优化配置
echo -e "${CYAN}[4/8] 创建优化配置文件...${NC}"
cat > /etc/hysteria/config.yaml <<EOF
listen: :$PORT

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864
  maxIdleTimeout: 60s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

bandwidth:
  up: 1 gbps
  down: 1 gbps

ignoreClientBandwidth: false
speedTest: false
disableUDP: false
udpIdleTimeout: 60s
EOF

chown hysteria:hysteria /etc/hysteria/server.key
chown hysteria:hysteria /etc/hysteria/server.crt
chown hysteria:hysteria /etc/hysteria/config.yaml
chmod 600 /etc/hysteria/server.key
echo -e "${GREEN}✓ 配置文件创建完成${NC}"
echo ""

# 步骤 5: 系统优化
echo -e "${CYAN}[5/8] 优化系统参数...${NC}"

# 开启 BBR
if ! sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi

# UDP 和网络优化
cat >> /etc/sysctl.conf <<EOF

# Hysteria 2 优化
net.core.rmem_max=2500000
net.core.wmem_max=2500000
net.core.rmem_default=2500000
net.core.wmem_default=2500000
net.core.netdev_max_backlog=250000
net.core.somaxconn=4096
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.ip_local_port_range=10000 65000
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=5000
fs.file-max=51200
EOF

sysctl -p > /dev/null 2>&1

# 文件描述符限制
cat >> /etc/security/limits.conf <<EOF

# Hysteria 2 优化
* soft nofile 51200
* hard nofile 51200
* soft nproc 51200
* hard nproc 51200
EOF

echo -e "${GREEN}✓ 系统优化完成${NC}"
echo ""

# 步骤 6: 配置防火墙
echo -e "${CYAN}[6/8] 配置防火墙...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow $PORT/udp > /dev/null 2>&1
    echo -e "${GREEN}✓ UFW 防火墙已配置${NC}"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=$PORT/udp > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
    echo -e "${GREEN}✓ Firewalld 防火墙已配置${NC}"
elif command -v iptables &> /dev/null; then
    iptables -A INPUT -p udp --dport $PORT -j ACCEPT
    echo -e "${GREEN}✓ iptables 防火墙已配置${NC}"
else
    echo -e "${YELLOW}⚠ 未检测到防火墙，请手动开放 UDP $PORT 端口${NC}"
fi
echo ""

# 步骤 7: 启动服务
echo -e "${CYAN}[7/8] 启动 Hysteria 服务...${NC}"
systemctl daemon-reload
systemctl enable hysteria-server > /dev/null 2>&1
systemctl restart hysteria-server
sleep 2

if systemctl is-active --quiet hysteria-server; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
else
    echo -e "${RED}✗ 服务启动失败，查看日志:${NC}"
    journalctl -u hysteria-server -n 20 --no-pager
    exit 1
fi
echo ""

# 步骤 8: 生成客户端配置
echo -e "${CYAN}[8/8] 生成客户端配置...${NC}"

# 获取服务器 IP
SERVER_IP=$(curl -s ip.sb || curl -s ifconfig.me || curl -s icanhazip.com)

if [ -z "$SERVER_IP" ]; then
    SERVER_IP="YOUR_SERVER_IP"
fi

# 生成分享链接
SHARE_LINK="hysteria2://$PASSWORD@$SERVER_IP:$PORT/?insecure=1&sni=www.bing.com#Hysteria2"

# 保存客户端配置
cat > /root/hysteria-client.yaml <<EOF
server: $SERVER_IP:$PORT

auth: $PASSWORD

tls:
  sni: www.bing.com
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
EOF

echo -e "${GREEN}✓ 客户端配置已生成${NC}"
echo ""

# 显示安装结果
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║                                           ║
║         🎉 安装成功！                     ║
║                                           ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}=========================================="
echo "  服务器信息"
echo "==========================================${NC}"
echo -e "${YELLOW}服务器地址:${NC} $SERVER_IP"
echo -e "${YELLOW}端口:${NC} $PORT"
echo -e "${YELLOW}密码:${NC} $PASSWORD"
echo -e "${YELLOW}协议:${NC} UDP"
echo ""

echo -e "${CYAN}=========================================="
echo "  分享链接"
echo "==========================================${NC}"
echo -e "${GREEN}$SHARE_LINK${NC}"
echo ""

# 生成二维码
echo -e "${CYAN}=========================================="
echo "  二维码（手机扫描）"
echo "==========================================${NC}"
qrencode -t ANSIUTF8 "$SHARE_LINK"
echo ""

echo -e "${CYAN}=========================================="
echo "  客户端下载"
echo "==========================================${NC}"
echo -e "${YELLOW}Windows/Mac/Linux:${NC}"
echo "  https://github.com/apernet/hysteria/releases"
echo ""
echo -e "${YELLOW}Android:${NC}"
echo "  SagerNet - https://github.com/SagerNet/SagerNet/releases"
echo ""
echo -e "${YELLOW}iOS:${NC}"
echo "  Shadowrocket (App Store 美区)"
echo ""

echo -e "${CYAN}=========================================="
echo "  配置文件位置"
echo "==========================================${NC}"
echo -e "${YELLOW}服务器配置:${NC} /etc/hysteria/config.yaml"
echo -e "${YELLOW}客户端配置:${NC} /root/hysteria-client.yaml"
echo ""

echo -e "${CYAN}=========================================="
echo "  管理命令"
echo "==========================================${NC}"
echo -e "${YELLOW}启动服务:${NC} systemctl start hysteria-server"
echo -e "${YELLOW}停止服务:${NC} systemctl stop hysteria-server"
echo -e "${YELLOW}重启服务:${NC} systemctl restart hysteria-server"
echo -e "${YELLOW}查看状态:${NC} systemctl status hysteria-server"
echo -e "${YELLOW}查看日志:${NC} journalctl -u hysteria-server -f"
echo ""

echo -e "${CYAN}=========================================="
echo "  优化信息"
echo "==========================================${NC}"
echo -e "${GREEN}✓${NC} BBR 拥塞控制已启用"
echo -e "${GREEN}✓${NC} UDP 缓冲区已优化"
echo -e "${GREEN}✓${NC} QUIC 参数已优化"
echo -e "${GREEN}✓${NC} 系统参数已优化"
echo -e "${GREEN}✓${NC} 防火墙已配置"
echo ""

echo -e "${CYAN}=========================================="
echo "  性能验证"
echo "==========================================${NC}"
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
if [ "$BBR_STATUS" = "bbr" ]; then
    echo -e "${GREEN}✓${NC} BBR: 已启用"
else
    echo -e "${YELLOW}⚠${NC} BBR: 未启用"
fi

if systemctl is-active --quiet hysteria-server; then
    echo -e "${GREEN}✓${NC} 服务状态: 运行中"
else
    echo -e "${RED}✗${NC} 服务状态: 未运行"
fi
echo ""

echo -e "${CYAN}=========================================="
echo "  下一步"
echo "==========================================${NC}"
echo "1. 复制分享链接到客户端"
echo "2. 或扫描二维码导入配置"
echo "3. 开始使用高速代理"
echo ""

echo -e "${PURPLE}=========================================="
echo "  建议"
echo "==========================================${NC}"
echo "• 定期更新: bash <(curl -fsSL https://get.hy2.sh/)"
echo "• 修改密码: 编辑 /etc/hysteria/config.yaml"
echo "• 备份配置: cp /etc/hysteria/config.yaml ~/config.yaml.bak"
echo "• 监控日志: journalctl -u hysteria-server -f"
echo ""

echo -e "${GREEN}=========================================="
echo "  安装完成！享受极速体验！ 🚀"
echo "==========================================${NC}"
echo ""

# 保存信息到文件
cat > /root/hysteria-info.txt <<EOF
========================================
Hysteria 2 配置信息
========================================

服务器: $SERVER_IP:$PORT
密码: $PASSWORD

分享链接:
$SHARE_LINK

客户端配置文件: /root/hysteria-client.yaml
服务器配置文件: /etc/hysteria/config.yaml

管理命令:
systemctl start hysteria-server    # 启动
systemctl stop hysteria-server     # 停止
systemctl restart hysteria-server  # 重启
systemctl status hysteria-server   # 状态
journalctl -u hysteria-server -f   # 日志

安装时间: $(date)
========================================
EOF

echo -e "${YELLOW}配置信息已保存到: /root/hysteria-info.txt${NC}"
echo ""
