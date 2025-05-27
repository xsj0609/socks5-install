#!/bin/bash

BIN_PATH="/usr/local/bin/socks5"
SERVICE_NAME="socks5"
CONF_PATH="/etc/sockd.conf"
PASSWD_PATH="/etc/sockd.passwd"
PAM_CONF_PATH="/etc/pam.d/sockd"
INSTALL_DIR="/usr/local/socks5_install"

install_socks5() {
    if [ "$(id -u)" != "0" ]; then
        echo "需要 root 权限运行安装"
        exit 1
    fi

    echo "安装依赖..."
    apt-get update
    apt-get install -y gcc make libpam0g-dev libpam-pwdfile whois

    echo "下载并编译 Dante..."
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    wget https://www.inet.no/dante/files/dante-1.4.3.tar.gz
    tar xvf dante-1.4.3.tar.gz
    cd dante-1.4.3
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
    make && make install

    echo "配置 Dante..."
    cat > $CONF_PATH <<EOF
internal: 0.0.0.0 port=1080
external: eth0
clientmethod: none
socksmethod: username
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
    command: bind connect udpassociate
    socksmethod: username
}
EOF

    echo "配置 PAM..."
    cat > $PAM_CONF_PATH <<EOF
auth required pam_pwdfile.so pwdfile=$PASSWD_PATH
account required pam_permit.so
EOF

    touch $PASSWD_PATH
    chmod 600 $PASSWD_PATH

    echo "创建 systemd 服务..."
    cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Dante SOCKS5 代理服务
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/sockd -f $CONF_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    systemctl start $SERVICE_NAME

    if command -v ufw &> /dev/null; then
        ufw allow 1080/tcp
        ufw reload
    fi
}

uninstall_socks5() {
    systemctl stop $SERVICE_NAME
    systemctl disable $SERVICE_NAME
    rm -f /etc/systemd/system/$SERVICE_NAME.service
    systemctl daemon-reload

    rm -rf $INSTALL_DIR
    rm -f $BIN_PATH $CONF_PATH $PASSWD_PATH $PAM_CONF_PATH
    rm -f /usr/sbin/sockd
}

user_add() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "用法: socks5 user add <用户名> <密码>"
        exit 1
    fi
    if ! grep -q "^$1:" $PASSWD_PATH; then
        local pwhash=$(mkpasswd -m sha-512crypt "$2")
        echo "$1:$pwhash" >> $PASSWD_PATH
        systemctl restart $SERVICE_NAME
        echo "用户 $1 添加成功"
    else
        echo "用户 $1 已存在"
    fi
}

user_del() {
    sed -i "/^$1:/d" $PASSWD_PATH
    systemctl restart $SERVICE_NAME
    echo "用户 $1 已删除"
}

user_list() {
    cut -d: -f1 $PASSWD_PATH
}

show_info() {
    echo "SOCKS5 代理状态: $(systemctl is-active $SERVICE_NAME)"
    echo "监听端口: 1080"
    echo "用户数量: $(wc -l < $PASSWD_PATH)"
}

case "$1" in
    "install")
        install_socks5
        cp -f $0 $BIN_PATH
        chmod +x $BIN_PATH
        echo "安装完成，使用命令: socks5 [command]"
        ;;
    "uninstall")
        uninstall_socks5
        echo "卸载完成"
        ;;
    "user")
        case "$2" in
            "add") user_add "$3" "$4" ;;
            "del") user_del "$3" ;;
            "list") user_list ;;
            *) echo "无效操作: user $2" ;;
        esac
        ;;
    "start"|"stop"|"restart"|"status")
        systemctl $1 $SERVICE_NAME
        ;;
    "update")
        wget -O $BIN_PATH https://raw.githubusercontent.com/qinghuas/socks5-install/master/socks5.sh
        chmod +x $BIN_PATH
        echo "脚本更新完成"
        ;;
    "info")
        show_info
        ;;
    *)
        echo "SOCKS5 代理管理命令"
        echo "用法: socks5 {install|uninstall|user|start|stop|restart|status|update|info}"
        echo "用户管理: socks5 user {add <user> <pass>|del <user>|list}"
        ;;
esac

if [ "$0" = "./socks5.sh" ] && [ "$1" != "install" ]; then
    echo "请先安装: bash socks5.sh install"
fi
