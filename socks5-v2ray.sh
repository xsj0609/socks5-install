#!/bin/bash

# 检查是否是root用户
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# 安装目录
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="socks5"

# 安装dante-server
install_dante() {
    echo "Installing dependencies..."
    yum install -y gcc make pam-devel tcp_wrappers-devel
    
    echo "Downloading and compiling dante-server..."
    wget https://www.inet.no/dante/files/dante-1.4.3.tar.gz
    tar xzf dante-1.4.3.tar.gz
    cd dante-1.4.3
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-client --without-libwrap --without-bsdauth --without-gssapi --without-krb5 --without-upnp --without-pam
    make && make install
    cd ..
    rm -rf dante-1.4.3 dante-1.4.3.tar.gz
}

# 创建配置文件
create_config() {
    echo "Creating configuration..."
    mkdir -p /var/run/socks
    cat > /etc/sockd.conf <<'EOL'
logoutput: /var/log/sockd.log
internal: 0.0.0.0 port = 1080
external: eth0
user.privileged: root
user.notprivileged: nobody

# 必须明确指定认证方法
socksmethod: username

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
    method: username  # 必须明确指定
}
EOL
}

# 创建PAM配置文件
create_pam_config() {
    echo "Creating PAM configuration..."
    cat > /etc/pam.d/sockd <<'EOL'
auth required pam_unix.so
account required pam_unix.so
EOL
}

# 创建systemd服务
create_service() {
    echo "Creating systemd service..."
    cat > /etc/systemd/system/sockd.service <<'EOL'
[Unit]
Description=Dante SOCKS daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/sockd -D -f /etc/sockd.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
}

# 添加用户
add_user() {
    username=$1
    password=$2
    echo "Adding user: $username"
    useradd $username >/dev/null 2>&1 || true
    echo "$username:$password" | chpasswd
    echo "User $username added with specified password"
}

# 删除用户
delete_user() {
    username=$1
    echo "Deleting user: $username"
    userdel $username >/dev/null 2>&1 && echo "User $username deleted" || echo "User $username not found"
}

# 列出用户
list_users() {
    echo "Current SOCKS5 users:"
    getent passwd | cut -d: -f1 | while read user; do
        if [ "$user" != "root" ] && [ "$user" != "nobody" ]; then
            echo "- $user"
        fi
    done
}

# 安装socks5命令到系统
install_command() {
    echo "Installing socks5 command..."
    cp "$0" "${INSTALL_DIR}/${SCRIPT_NAME}"
    chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
    echo "Command installed. You can now use 'socks5' instead of './socks5.sh'"
}

# 主安装函数
install_main() {
    install_dante
    create_config
    create_pam_config
    create_service
    install_command
    systemctl daemon-reload
    systemctl enable sockd
    systemctl start sockd
    
    # 添加默认用户
    add_user "proxyuser" "proxy123"
    
    echo ""
    echo "SOCKS5 proxy installed successfully!"
    echo "Listening on: 0.0.0.0:1080"
    echo "Default test user: proxyuser/proxy123"
    echo ""
    echo "Usage:"
    echo "  socks5 start       - Start service"
    echo "  socks5 stop        - Stop service"
    echo "  socks5 user add    - Add user (e.g. socks5 user add username password)"
    echo "  socks5 user del    - Delete user"
    echo "  socks5 user list   - List users"
}

# 卸载函数
uninstall_main() {
    systemctl stop sockd
    systemctl disable sockd
    rm -f /etc/systemd/system/sockd.service
    rm -f /etc/sockd.conf
    rm -f /etc/pam.d/sockd
    rm -f /usr/sbin/sockd
    rm -f "${INSTALL_DIR}/${SCRIPT_NAME}"
    systemctl daemon-reload
    echo "SOCKS5 proxy and all related files have been removed"
}

case "$1" in
    "install")
        install_main
        ;;
    "uninstall")
        uninstall_main
        ;;
    "user")
        case "$2" in
            "add")
                if [ -z "$3" ] || [ -z "$4" ]; then
                    echo "Usage: socks5 user add USERNAME PASSWORD"
                    exit 1
                fi
                add_user "$3" "$4"
                systemctl restart sockd
                ;;
            "del")
                if [ -z "$3" ]; then
                    echo "Usage: socks5 user del USERNAME"
                    exit 1
                fi
                delete_user "$3"
                systemctl restart sockd
                ;;
            "list")
                list_users
                ;;
            *)
                echo "Usage: socks5 user {add|del|list} [username] [password]"
                exit 1
                ;;
        esac
        ;;
    "start")
        systemctl start sockd
        ;;
    "stop")
        systemctl stop sockd
        ;;
    "restart")
        systemctl restart sockd
        ;;
    "status")
        systemctl status sockd
        ;;
    *)
        echo "Usage: socks5 {install|uninstall|user|start|stop|restart|status}"
        echo "  install      - Install SOCKS5 proxy"
        echo "  uninstall    - Remove SOCKS5 proxy"
        echo "  user add     - Add a new user (e.g. socks5 user add username password)"
        echo "  user del     - Delete a user"
        echo "  user list    - List all users"
        echo "  start        - Start service"
        echo "  stop         - Stop service"
        echo "  restart      - Restart service"
        echo "  status       - Check service status"
        exit 1
        ;;
esac
