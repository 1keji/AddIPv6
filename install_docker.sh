#!/bin/bash

# 一键安装Docker和Docker Compose脚本
# 适用于Ubuntu系统

set -e

echo "=== 开始Docker和Docker Compose的安装 ==="

# 更新系统包索引
echo "更新系统包索引..."
sudo apt-get update -y

# 卸载旧版本的Docker（如果存在）
echo "卸载旧版本的Docker（如果存在）..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# 安装必要的依赖包
echo "安装必要的依赖包..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 添加Docker的官方GPG密钥
echo "添加Docker的官方GPG密钥..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置Docker的稳定版仓库
echo "设置Docker的稳定版仓库..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 再次更新包索引
echo "再次更新包索引..."
sudo apt-get update -y

# 安装最新版本的Docker Engine、containerd
echo "安装Docker Engine和containerd..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# 启动并设置Docker开机自启
echo "启动Docker并设置开机自启..."
sudo systemctl start docker
sudo systemctl enable docker

# 验证Docker是否安装成功
echo "验证Docker是否安装成功..."
sudo docker run --rm hello-world

# 安装Docker Compose
echo "安装Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 授予可执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 创建符号链接（可选）
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 验证Docker Compose是否安装成功
echo "验证Docker Compose是否安装成功..."
docker-compose --version

# 添加当前用户到docker组（无需sudo运行docker命令）
echo "将当前用户添加到docker组..."
sudo usermod -aG docker $USER

echo "=== Docker和Docker Compose安装完成 ==="
echo "请重新登录以使用户组更改生效。"
