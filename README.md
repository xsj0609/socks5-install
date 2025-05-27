# 使用方法：

# 一键安装（首次运行）：
yum install -y jq<br>
wget https://raw.githubusercontent.com/xsj0609/socks5-install/main/socks5-v2ray.sh<br>
mv -f socks5-v2ray.sh socks5.sh<br>
chmod +x socks5.sh<br>
./socks5.sh install

# 安装或卸载
./socks5.sh install|uninstall<br>

# 用户管理
./socks5.sh user add <username> <password><br>
./socks5.sh user del <username><br>
./socks5.sh user list

# 服务管理
./socks5.sh start|stop|restart|status

# 更新和信息
./socks5.sh update
./socks5.sh info



