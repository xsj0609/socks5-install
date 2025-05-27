#!/bin/bash

V2RAY_VERSION="5.32.0"

# 安装必要的依赖
install_dependencies() {
    echo "Installing dependencies..."
    yum install -y epel-release
    yum install -y wget unzip
}

# 下载并安装 v2ray
install_v2ray() {
    echo "Downloading and installing v2ray..."
    wget -O /tmp/v2ray.zip https://github.com/v2fly/v2ray-core/releases/download/v${V2RAY_VERSION}/v2ray-linux-64.zip
    unzip /tmp/v2ray.zip -d /tmp/v2ray
    mkdir -p /usr/local/v2ray
    cp /tmp/v2ray/v2ray /usr/local/bin/
    cp /tmp/v2ray/geoip.dat /usr/local/bin/
    cp /tmp/v2ray/geosite.dat /usr/local/bin/
    rm -rf /tmp/v2ray /tmp/v2ray.zip
}

# 创建 v2ray 配置文件
create_v2ray_config() {
    echo "Creating v2ray configuration..."
    mkdir -p /etc/v2ray
    cat > /etc/v2ray/config.json << EOL
{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 1080,
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "admin",
                        "pass": "123456"
                    }
                ],
                "udp": false,
                "ip": "0.0.0.0"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOL
}

# 创建 systemd 服务文件
create_service_file() {
    echo "Creating systemd service file..."
    cat > /etc/systemd/system/v2ray.service << EOL
[Unit]
Description=V2Ray Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOL
}

# 创建日志目录和设置权限
setup_logs() {
    echo "Setting up logs and permissions..."
    mkdir -p /var/log/v2ray
    touch /var/log/v2ray/access.log
    touch /var/log/v2ray/error.log
    chown -R root:root /var/log/v2ray
    chmod -R 755 /var/log/v2ray
}

# 启用并启动服务
enable_and_start_service() {
    echo "Enabling and starting v2ray service..."
    systemctl daemon-reload
    systemctl enable v2ray
    systemctl start v2ray
}

# 安装主程序
install_main() {
    install_dependencies
    install_v2ray
    create_v2ray_config
    create_service_file
    setup_logs
    enable_and_start_service
}

# 卸载程序
uninstall_main() {
    echo "Uninstalling v2ray..."
    systemctl stop v2ray
    systemctl disable v2ray
    rm -f /etc/systemd/system/v2ray.service
    systemctl daemon-reload
    rm -rf /etc/v2ray
    rm -rf /usr/local/bin/v2ray
    rm -rf /usr/local/bin/geoip.dat
    rm -rf /usr/local/bin/geosite.dat
    rm -rf /var/log/v2ray
}

# 添加用户
add_user() {
    username=$1
    password=$2
    echo "Adding user: $username"
    
    # 从现有配置中提取用户列表
    users=$(jq -r '.inbounds[0].settings.accounts' /etc/v2ray/config.json)
    
    # 添加新用户
    new_user=$(jq -n --arg user "$username" --arg pass "$password" '{user: $user, pass: $pass}')
    updated_users=$(echo "$users" | jq ". + [$new_user]")
    
    # 更新配置文件
    jq --argjson users "$updated_users" '.inbounds[0].settings.accounts = $users' /etc/v2ray/config.json > /tmp/config.json
    mv /tmp/config.json /etc/v2ray/config.json
    
    systemctl restart v2ray
}

# 删除用户
delete_user() {
    username=$1
    echo "Deleting user: $username"
    
    # 更新配置文件
    jq --arg user "$username" 'del(.inbounds[0].settings.accounts[] | select(.user == $user))' /etc/v2ray/config.json > /tmp/config.json
    mv /tmp/config.json /etc/v2ray/config.json
    
    systemctl restart v2ray
}

# 列出用户
list_users() {
    echo "Current users:"
    jq -r '.inbounds[0].settings.accounts[].user' /etc/v2ray/config.json
}

# 更新 v2ray
update_v2ray() {
    echo "Updating v2ray..."
    systemctl stop v2ray
    rm -f /usr/local/bin/v2ray
    rm -f /usr/local/bin/geoip.dat
    rm -f /usr/local/bin/geosite.dat
    install_v2ray
    systemctl start v2ray
}

# 显示信息
show_info() {
    echo "v2ray version: ${V2RAY_VERSION}"
    echo "Listening port: $(jq -r '.inbounds[0].port' /etc/v2ray/config.json)"
    echo "Protocol: $(jq -r '.inbounds[0].protocol' /etc/v2ray/config.json)"
    systemctl status v2ray
}

case $1 in
    "install")
        install_main
        ;;
    "uninstall")
        uninstall_main
        ;;
    "user")
        case $2 in
            "add")
                add_user $3 $4
                ;;
            "del")
                delete_user $3
                ;;
            "list")
                list_users
                ;;
            *)
                echo "Usage: $0 user {add|del|list}"
                ;;
        esac
        ;;
    "start")
        systemctl start v2ray
        ;;
    "stop")
        systemctl stop v2ray
        ;;
    "restart")
        systemctl restart v2ray
        ;;
    "status")
        systemctl status v2ray
        ;;
    "update")
        update_v2ray
        ;;
    "info")
        show_info
        ;;
    *)
        echo "Usage: $0 {install|uninstall|user|start|stop|restart|status|update|info}"
        echo "  install      - Install v2ray and configure socks5 proxy"
        echo "  uninstall    - Remove v2ray and all related files"
        echo "  user add     - Add a new user (e.g. $0 user add username password)"
        echo "  user del     - Delete a user (e.g. $0 user del username)"
        echo "  user list    - List all users"
        echo "  start        - Start v2ray service"
        echo "  stop         - Stop v2ray service"
        echo "  restart      - Restart v2ray service"
        echo "  status       - Check v2ray service status"
        echo "  update       - Update v2ray to latest version"
        echo "  info         - Show v2ray configuration info"
        ;;
esac
