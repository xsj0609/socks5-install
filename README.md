使用方法：

一键安装（首次运行）：

wget https://raw.githubusercontent.com/xsj0609/socks5-install/main/socks5.sh -O /tmp/socks5.sh

bash /tmp/socks5.sh install

添加用户：
socks5 user add admin 123456

启动服务：
socks5 start

功能说明：
自动编译安装 Dante SOCKS5 服务
支持用户认证管理
完整的服务生命周期管理（启动/停止/状态查看）
支持脚本自我更新
自动配置防火墙规则（如果使用 UFW）
系统服务集成（systemd）

注意事项：
默认监听端口为 1080（可在配置文件中修改）
用户密码使用 SHA-256crypt 加密存储
服务安装后会自动设置开机启动
每次用户变更后会自动重启服务
支持主流的 Ubuntu 版本（18.04+）

安装完成后即可通过 socks5 命令进行全功能管理，代理服务器地址为 服务器IP:1080，支持用户名密码认证。
