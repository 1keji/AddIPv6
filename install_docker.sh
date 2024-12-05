#!/bin/bash

# Docker 和 Docker Compose 管理脚本
# 提供安装、卸载、查询状态和退出选项
# 适用于 Ubuntu 和 Debian 系统

set -e

# 函数：显示菜单
show_menu() {
    echo "=========================================="
    echo "     Docker 和 Docker Compose 管理脚本      "
    echo "=========================================="
    echo "1. 安装 Docker 和 Docker Compose"
    echo "2. 卸载 Docker 和 Docker Compose"
    echo "3. 查询安装情况和运行状态"
    echo "4. 退出脚本"
    echo "=========================================="
}

# 函数：检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        # 将 ID 和 ID_LIKE 转换为小写
        ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        ID_LIKE=$(echo "$ID_LIKE" | tr '[:upper:]' '[:lower:]')
        # 优先使用 ID 来检测
        case "$ID" in
            ubuntu)
                OS="ubuntu"
                ;;
            debian)
                OS="debian"
                ;;
            *)
                # 如果 ID 不是 ubuntu 或 debian，尝试使用 ID_LIKE
                if echo "$ID_LIKE" | grep -qw 'ubuntu'; then
                    OS="ubuntu"
                elif echo "$ID_LIKE" | grep -qw 'debian'; then
                    OS="debian"
                else
                    OS=""
                fi
                ;;
        esac
        VERSION_CODENAME=$(echo "$VERSION_CODENAME" | tr '[:upper:]' '[:lower:]')
    else
        echo "无法检测操作系统。"
        exit 1
    fi

    # 打印检测到的操作系统和版本代号（用于调试）
    echo "检测到的操作系统: $OS"
    echo "版本代号: $VERSION_CODENAME"
}

# 函数：添加 Docker 仓库
add_docker_repo() {
    echo "添加 Docker 的官方 GPG 密钥..."
    curl -fsSL https://download.docker.com/linux/${OS}/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 删除旧的 Docker 仓库配置
    echo "删除旧的 Docker 仓库配置..."
    rm -f /etc/apt/sources.list.d/docker.list

    echo "设置 Docker 的 APT 仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${OS} \
      ${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# 函数：安装 Docker 和 Docker Compose
install_docker() {
    echo "开始安装 Docker 和 Docker Compose..."

    # 更新 APT 包索引
    echo "更新 APT 包索引..."
    apt-get update -y

    # 安装必要的依赖包
    echo "安装必要的依赖包..."
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # 添加 Docker 的官方 GPG 密钥和 APT 仓库
    add_docker_repo

    # 再次更新 APT 包索引
    echo "再次更新 APT 包索引..."
    apt-get update -y

    # 安装最新版本的 Docker Engine、CLI 和容器运行时
    echo "安装最新版本的 Docker Engine、CLI 和 容器运行时..."
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # 启动并启用 Docker 服务
    echo "启动并启用 Docker 服务..."
    systemctl start docker
    systemctl enable docker

    # 验证 Docker 是否安装成功
    echo "验证 Docker 是否安装成功..."
    docker --version

    # 安装 Docker Compose
    echo "安装 Docker Compose..."

    # 获取最新的 Docker Compose 版本号
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f4)

    # 下载 Docker Compose 二进制文件
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # 赋予执行权限
    chmod +x /usr/local/bin/docker-compose

    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    # 验证 Docker Compose 是否安装成功
    echo "验证 Docker Compose 是否安装成功..."
    docker-compose --version

    echo "Docker 和 Docker Compose 安装完成！"
}

# 函数：检查 Docker 仓库是否存在
check_docker_repo() {
    REPO_URL="https://download.docker.com/linux/${OS}/dists/${VERSION_CODENAME}/stable/"
    echo "正在检查 Docker 仓库是否存在： $REPO_URL"

    if ! curl --head --silent --fail "$REPO_URL" >/dev/null; then
        echo "错误： Docker 仓库不存在或不可访问。请检查操作系统类型和版本代号。"
        echo "请确保 Docker 支持您的操作系统版本。"
        exit 1
    fi
}

# 检测是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 用户或使用 sudo 运行此脚本。"
    exit 1
fi

# 检测操作系统
detect_os

# 验证是否支持当前操作系统
if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo "当前操作系统不受支持。本脚本仅支持 Ubuntu 和 Debian。"
    exit 1
fi

# 检查 Docker 仓库是否存在
check_docker_repo

# 主循环
while true; do
    show_menu
    read -p "请输入你的选择 [1-4]: " choice
    case $choice in
        1)
            install_docker
            ;;
        4)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择，请输入1-4 之间的数字。"
            ;;
    esac
    echo ""
done
