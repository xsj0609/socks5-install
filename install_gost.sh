	#!/bin/bash
	# =================================================================
	# Gost SOCKS5 Proxy Server Auto-Installation Script
	# A modern, reliable, and simple alternative to ss5
	# Author: AI Expert
	# Date: 2025-10-19
	# =================================================================
	# --- Configuration ---
	GOST_VERSION="3.0.0-rc8"
	GOST_PORT="1080"
	GOST_USER="gostuser"
	# Generate a random password
	GOST_PASSWORD=$(openssl rand -base64 12)
	# --- Pre-install Checks ---
	set -e
	# Check for root privileges
	if [[ $EUID -ne 0 ]]; then
	   echo "错误：此脚本必须以 root 权限运行。" 
	   exit 1
	fi
	echo "开始安装 Gost SOCKS5 代理服务器..."
	echo "=========================================================="
	# --- Install Dependencies ---
	# Gost is a single binary, we only need wget/curl and systemd.
	yum install -y wget curl >/dev/null 2>&1 || apt-get install -y wget curl >/dev/null 2>&1
	echo "依赖检查完成。"
	# --- Download and Install Gost ---
	echo "正在下载 Gost..."
	cd /usr/local/bin
	# Detect system architecture
	ARCH=$(uname -m)
	case $ARCH in
	    x86_64)
	        GOST_ARCH="amd64"
	        ;;
	    aarch64)
	        GOST_ARCH="arm64"
	        ;;
	    *)
	        echo "错误：不支持的系统架构 $ARCH。"
	        exit 1
	        ;;
	esac
	DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/${GOST_VERSION}/gost-linux-${GOST_ARCH}-${GOST_VERSION}.gz"
	wget --no-check-certificate -O gost.gz "${DOWNLOAD_URL}"
	echo "正在安装 Gost..."
	gunzip gost.gz
	chmod +x gost
	# --- Create Systemd Service ---
	echo "正在配置 Gost 服务..."
	cat > /etc/systemd/system/gost.service <<EOF
	[Unit]
	Description=Gost SOCKS5 Proxy Server
	After=network.target
	[Service]
	Type=simple
	User=nobody
	Group=nobody
	ExecStart=/usr/local/bin/gost -L="socks5://${GOST_USER}:${GOST_PASSWORD}@:${GOST_PORT}"
	Restart=on-failure
	RestartSec=5s
	[Install]
	WantedBy=multi-user.target
	EOF
	# --- Start and Enable Gost Service ---
	echo "正在启动并启用 Gost 服务..."
	systemctl daemon-reload
	systemctl enable gost
	systemctl start gost
	# --- Firewall Configuration ---
	echo "正在配置防火墙..."
	if command -v firewall-cmd &> /dev/null; then
	    firewall-cmd --permanent --add-port=${GOST_PORT}/tcp
	    firewall-cmd --reload
	    echo "Firewalld 端口 ${GOST_PORT} 已开放。"
	elif command -v ufw &> /dev/null; then
	    ufw allow ${GOST_PORT}/tcp
	    echo "UFW 端口 ${GOST_PORT} 已开放。"
	else
	    echo "警告：未检测到 firewalld 或 ufw，请手动开放 TCP 端口 ${GOST_PORT}。"
	fi
	echo "=========================================================="
	echo "Gost SOCKS5 代理服务器安装成功！"
	echo ""
	echo "服务器信息:"
	echo "  IP 地址: $(curl -s ifconfig.me)"
	echo "  端口: ${GOST_PORT}"
	echo "  用户名: ${GOST_USER}"
	echo "  密码: ${GOST_PASSWORD}"
	echo ""
	echo "常用命令:"
	echo "  查看服务状态: systemctl status gost"
	echo "  启动服务: systemctl start gost"
	echo "  停止服务: systemctl stop gost"
	echo "  重启服务: systemctl restart gost"
	echo ""
	echo "如需修改用户名或密码，请编辑 /etc/systemd/system/gost.service 文件，"
	echo "然后执行 systemctl daemon-reload && systemctl restart gost。"
	echo "=========================================================="
