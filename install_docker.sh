#!/bin/bash

# 更新系统
sudo apt update

# 安装依赖包
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# 添加 Docker 官方的 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker 官方 APT 源
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新 APT 包索引
sudo apt update

# 安装 Docker 引擎
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 启动 Docker 服务并设置开机自启
sudo systemctl start docker
sudo systemctl enable docker

# 验证 Docker 是否成功安装
sudo docker --version

# 安装 Docker Compose
DOCKER_COMPOSE_VERSION="1.29.2"  # 可根据需要修改版本号
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 授予 Docker Compose 执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证 Docker Compose 是否成功安装
docker-compose --version

echo "Docker 和 Docker Compose 安装成功！"
