	#!/bin/bash
	# =================================================================
	# SS5 SOCKS5 Proxy Server Auto-Installation Script (Robust Version)
	# Enhanced for modern Linux distributions (Systemd)
	# Author: AI Expert
	# Date: 2025-10-19
	# =================================================================
	# --- Configuration ---
	SS5_VERSION="3.8.9-8"
	SS5_PORT="1080"
	SS5_USER="ss5user"
	# Generate a random password
	SS5_PASSWORD=$(openssl rand -base64 12)
	# --- Pre-install Checks ---
	# Exit immediately if a command exits with a non-zero status.
	set -e
	# Check for root privileges
	if [[ $EUID -ne 0 ]]; then
	   echo "错误：此脚本必须以 root 权限运行。" 
	   exit 1
	fi
	echo "开始安装 SS5 SOCKS5 代理服务器..."
	echo "=========================================================="
	# --- System Detection ---
	if [ -f /etc/os-release ]; then
	    . /etc/os-release
	    OS=$ID
	    VER=$VERSION_ID
	else
	    echo "错误：无法检测您的操作系统。"
	    exit 1
	fi
	echo "检测到操作系统: $OS $VER"
	# --- Install Dependencies ---
	echo "正在安装必要的依赖..."
	if [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
	    yum update -y
	    yum groupinstall -y "Development Tools"
	    yum install -y pam-devel openssl-devel openldap-devel cyrus-sasl-devel wget curl
	elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
	    apt-get update
	    apt-get install -y build-essential libpam0g-dev libssl-dev libldap2-dev libsasl2-dev wget curl
	else
	    echo "错误：不支持的操作系统 $OS。"
	    exit 1
	fi
	echo "依赖安装完成。"
	# --- Download and Compile SS5 ---
	echo "正在下载 SS5 源码..."
	cd /usr/local/src
	DOWNLOAD_URL="https://sourceforge.net/projects/ss5/files/ss5/${SS5_VERSION}/ss5-${SS5_VERSION}.tar.gz/download"
	DOWNLOADED_FILE="ss5-${SS5_VERSION}.tar.gz"
	DOWNLOAD_SUCCESS=0
	# Try wget first with timeout and retries
	echo "尝试使用 wget 下载..."
	if wget --timeout=30 --tries=3 --no-check-certificate -O "${DOWNLOADED_FILE}" "${DOWNLOAD_URL}"; then
	    DOWNLOAD_SUCCESS=1
	    echo "wget 下载成功。"
	else
	    echo "wget 下载失败，尝试使用 curl 作为备用方案..."
	    # Try curl as a fallback
	    if curl -L --connect-timeout 30 --retry 3 -o "${DOWNLOADED_FILE}" "${DOWNLOAD_URL}"; then
	        DOWNLOAD_SUCCESS=1
	        echo "curl 下载成功。"
	    else
	        echo "错误：所有下载尝试均失败。"
	    fi
	fi
	# Check if download was successful
	if [ "$DOWNLOAD_SUCCESS" -eq 0 ]; then
	    echo "=========================================================="
	    echo "错误：无法下载 SS5 源码。"
	    echo "这可能是由于网络问题或 SourceForge 镜像故障。"
	    echo "请稍后重试，或参考手动安装指南。"
	    echo "=========================================================="
	    exit 1
	fi
	echo "正在解压和编译 SS5..."
	tar xzf "${DOWNLOADED_FILE}"
	cd "ss5-${SS5_VERSION}"
	./configure
	make
	make install
	echo "SS5 编译安装完成。"
	# --- Configure SS5 ---
	echo "正在配置 SS5..."
	# Backup original config
	if [ -f /etc/opt/ss5/ss5.conf ]; then
	    mv /etc/opt/ss5/ss5.conf /etc/opt/ss5/ss5.conf.bak.$(date +%F_%T)
	fi
	# Create a new, secure configuration
	cat > /etc/opt/ss5/ss5.conf <<EOF
	# SS5 Configuration
	# Auth: u = username/password
	auth    0.0.0.0/0               -              u
	# Permit authenticated users
	permit u    0.0.0.0/0               -       0.0.0.0/0               -       -       -       -       -
	EOF
	# Create password file
	touch /etc/opt/ss5/ss5.passwd
	chown root:root /etc/opt/ss5/ss5.passwd
	chmod 640 /etc/opt/ss5/ss5.passwd
	# Add the user
	echo "${SS5_USER}:${SS5_PASSWORD}" > /etc/opt/ss5/ss5.passwd
	echo "SS5 配置完成。"
	# --- Create Systemd Service ---
	echo "正在创建 Systemd 服务..."
	cat > /etc/systemd/system/ss5.service <<EOF
	[Unit]
	Description=SS5 SOCKS5 Proxy Server
	After=network.target
	[Service]
	Type=forking
	ExecStart=/usr/sbin/ss5 -t -m
	ExecReload=/bin/kill -HUP \$MAINPID
	KillMode=process
	Restart=on-failure
	RestartSec=5s
	[Install]
	WantedBy=multi-user.target
	EOF
	# --- Start and Enable SS5 Service ---
	echo "正在启动并启用 SS5 服务..."
	systemctl daemon-reload
	systemctl enable ss5
	systemctl start ss5
	# --- Firewall Configuration ---
	echo "正在配置防火墙..."
	if command -v firewall-cmd &> /dev/null; then
	    firewall-cmd --permanent --add-port=${SS5_PORT}/tcp
	    firewall-cmd --reload
	    echo "Firewalld 端口 ${SS5_PORT} 已开放。"
	elif command -v ufw &> /dev/null; then
	    ufw allow ${SS5_PORT}/tcp
	    echo "UFW 端口 ${SS5_PORT} 已开放。"
	else
	    echo "警告：未检测到 firewalld 或 ufw，请手动开放 TCP 端口 ${SS5_PORT}。"
	fi
	# --- Cleanup ---
	cd /usr/local/src
	rm -rf "ss5-${SS5_VERSION}"
	rm -f "${DOWNLOADED_FILE}"
	echo "=========================================================="
	echo "SS5 SOCKS5 代理服务器安装成功！"
	echo ""
	echo "服务器信息:"
	echo "  IP 地址: $(curl -s ifconfig.me)"
	echo "  端口: ${SS5_PORT}"
	echo "  用户名: ${SS5_USER}"
	echo "  密码: ${SS5_PASSWORD}"
	echo ""
	echo "常用命令:"
	echo "  查看服务状态: systemctl status ss5"
	echo "  启动服务: systemctl start ss5"
	echo "  停止服务: systemctl stop ss5"
	echo "  重启服务: systemctl restart ss5"
	echo ""
	echo "用户管理: 请编辑 /etc/opt/ss5/ss5.passwd 文件，格式为 用户名:密码，每行一个。"
	echo "      修改后需重启服务: systemctl restart ss5"
	echo "=========================================================="
