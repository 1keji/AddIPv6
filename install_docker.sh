#!/bin/bash

# 一键安装Docker和Docker Compose脚本
# 适用于Ubuntu 20.04及以上版本

set -e

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户或使用sudo运行此脚本。"
  exit 1
fi

echo "更新APT包索引..."
apt-get update -y

echo "安装必要的依赖包..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "添加Docker的官方GPG密钥..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "设置Docker的APT仓库..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "再次更新APT包索引..."
apt-get update -y

echo "安装最新版本的Docker Engine、CLI和容器运行时..."
apt-get install -y docker-ce docker-ce-cli containerd.io

echo "启动并启用Docker服务..."
systemctl start docker
systemctl enable docker

echo "验证Docker是否安装成功..."
docker --version

echo "安装Docker Compose..."

# 获取最新的Docker Compose版本号
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f4)

# 下载Docker Compose二进制文件
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 赋予执行权限
chmod +x /usr/local/bin/docker-compose

# 创建软链接
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "验证Docker Compose是否安装成功..."
docker-compose --version

echo "将当前用户添加到docker用户组（以便无需sudo运行Docker命令）..."
read -p "请输入要添加到docker组的用户名（默认为当前用户）： " USERNAME
USERNAME=${USERNAME:-$SUDO_USER}

if id -nG "$USERNAME" | grep -qw "docker"; then
    echo "用户$USERNAME已经在docker组中。"
else
    usermod -aG docker "$USERNAME"
    echo "用户$USERNAME已添加到docker组。"
    echo "请注销并重新登录以使更改生效。"
fi

echo "Docker和Docker Compose安装完成！"
