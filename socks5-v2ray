#!/bin/bash

# 安装必要的依赖
install_dependencies() {
    echo "Installing dependencies..."
    yum install -y epel-release
    yum install -y wget unzip
}

# 下载并安装 v2ray
install_v2ray() {
    echo "Downloading and installing v2ray..."
    wget https://github.com/v2fly/v2ray-core/releases/download/v1.5.10/v2ray-linux-64.zip
    unzip v2ray-linux-64.zip -d /usr/local/v2ray
    cp /usr/local/v2ray/v2ray /usr/local/bin/
    cp /usr/local/v2ray/geoip.dat /usr/local/bin/
    cp /usr/local/v2ray/geosite.dat /usr/local/bin/
    mkdir -p /etc/v2ray
    rm -f v2ray-linux-64.zip
}

# 创建 v2ray 配置文件
create_v2ray_config() {
    echo "Creating v2ray configuration..."
    cat > /etc/v2ray/config.json << EOL
{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbound": {
        "port": 1080,
        "protocol": "socks",
        "listen": "0.0.0.0",
        "settings": {
            "auth": "password",
            "accounts": [
                {
                    "user": "admin",
                    "pass": "123456"
                }
            ],
            "udp": false,
            "ip": "127.0.0.1"
        }
    },
    "outbound": {
        "protocol": "freedom"
    }
}
EOL
}

# 创建 systemunit 文件
create_service_file() {
    echo "Creating systemd service file..."
    cat > /etc/systemd/system/v2ray.service << EOL
[Unit]
Description=v2ray Socks5 Proxy
After=network.target

[Service]
User=v2ray
ExecStart=/usr/local/bin/v2ray -config=/etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
}

# 创建 v2ray 用户和组
create_v2ray_user() {
    echo "Creating v2ray user and group..."
    groupadd -r v2ray
    useradd -r -g v2ray -d /etc/v2ray -s /sbin/nologin v2ray
    chown -R v2ray:v2ray /etc/v2ray
    chown -R v2ray:v2ray /usr/local/bin/v2ray
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
    create_v2ray_user
    create_v2ray_config
    create_service_file
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
    userdel v2ray
    groupdel v2ray
}

# 添加用户
add_user() {
    username=$1
    password=$2
    echo "Adding user: $username"
    # 加密密码（这里使用简单的 base64 加密，你可以根据需要修改）
    encrypted_password=$(echo -n "$password" | base64)
    # 更新配置文件
    sed -i "/\"accounts\": \[/c\\\"accounts\": [\\{\\\"user\\\": \\\"$username\\\", \\\"pass\\\": \\\"$encrypted_password\\\"\\}\\]" /etc/v2ray/config.json
    systemctl restart v2ray
}

# 删除用户
delete_user() {
    username=$1
    echo "Deleting user: $username"
    # 从配置文件中删除用户
    sed -i "/\"user\": \"$username\"/d" /etc/v2ray/config.json
    systemctl restart v2ray
}

# 列出用户
list_users() {
    echo "Current users:"
    grep -oP '(?<="user": ")[^"]*' /etc/v2ray/config.json
}

# 更新 v2ray
update_v2ray() {
    echo "Updating v2ray..."
    systemctl stop v2ray
    rm -f /usr/local/bin/v2ray
    wget https://github.com/v2fly/v2ray-core/releases/download/v1.5.10/v2ray-linux-64.zip
    unzip v2ray-linux-64.zip -d /usr/local/v2ray
    cp /usr/local/v2ray/v2ray /usr/local/bin/
    rm -f v2ray-linux-64.zip
    systemctl start v2ray
}

# 显示信息
show_info() {
    echo "v2ray version: 1.5.10"
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
        ;;
esac
