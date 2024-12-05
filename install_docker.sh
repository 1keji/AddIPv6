#!/bin/bash

# Docker和Docker Compose管理脚本
# 提供安装、卸载、查询状态和退出选项
# 适用于Ubuntu 20.04及以上版本

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

# 函数：安装 Docker 和 Docker Compose
install_docker() {
    echo "开始安装 Docker 和 Docker Compose..."

    # 更新APT包索引
    echo "更新APT包索引..."
    apt-get update -y

    # 安装必要的依赖包
    echo "安装必要的依赖包..."
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # 添加Docker的官方GPG密钥
    echo "添加Docker的官方GPG密钥..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 设置Docker的APT仓库
    echo "设置Docker的APT仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 再次更新APT包索引
    echo "再次更新APT包索引..."
    apt-get update -y

    # 安装最新版本的Docker Engine、CLI和容器运行时
    echo "安装最新版本的Docker Engine、CLI和容器运行时..."
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # 启动并启用Docker服务
    echo "启动并启用Docker服务..."
    systemctl start docker
    systemctl enable docker

    # 验证Docker是否安装成功
    echo "验证Docker是否安装成功..."
    docker --version

    # 安装Docker Compose
    echo "安装Docker Compose..."

    # 获取最新的Docker Compose版本号
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f4)

    # 下载Docker Compose二进制文件
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # 赋予执行权限
    chmod +x /usr/local/bin/docker-compose

    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    # 验证Docker Compose是否安装成功
    echo "验证Docker Compose是否安装成功..."
    docker-compose --version

    # 将当前用户添加到docker用户组（以便无需sudo运行Docker命令）
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

    echo "Docker 和 Docker Compose 安装完成！"
}

# 函数：卸载 Docker 和 Docker Compose
uninstall_docker() {
    echo "开始卸载 Docker 和 Docker Compose..."

    # 停止并禁用Docker服务
    echo "停止并禁用Docker服务..."
    systemctl stop docker
    systemctl disable docker

    # 卸载Docker Engine、CLI和容器运行时
    echo "卸载Docker Engine、CLI和容器运行时..."
    apt-get purge -y docker-ce docker-ce-cli containerd.io

    # 删除所有Docker数据
    echo "删除所有Docker数据..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd

    # 删除Docker Compose
    echo "删除Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose

    # 删除Docker的APT仓库
    echo "删除Docker的APT仓库..."
    rm -f /etc/apt/sources.list.d/docker.list

    # 删除Docker的GPG密钥
    echo "删除Docker的GPG密钥..."
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg

    # 更新APT包索引
    echo "更新APT包索引..."
    apt-get update -y

    # 从docker组中移除用户
    echo "从docker组中移除用户..."
    read -p "请输入要从docker组中移除的用户名（默认为当前用户）： " USERNAME
    USERNAME=${USERNAME:-$SUDO_USER}

    if id -nG "$USERNAME" | grep -qw "docker"; then
        gpasswd -d "$USERNAME" docker
        echo "用户$USERNAME已从docker组中移除。"
    else
        echo "用户$USERNAME不在docker组中。"
    fi

    echo "Docker 和 Docker Compose 已成功卸载！"
}

# 函数：查询安装情况和运行状态
check_status() {
    echo "查询Docker和Docker Compose的安装情况和运行状态..."

    # 检查Docker是否安装
    if command -v docker >/dev/null 2>&1; then
        echo "Docker 已安装，版本信息："
        docker --version
    else
        echo "Docker 未安装。"
    fi

    # 检查Docker服务状态
    if systemctl is-active --quiet docker; then
        echo "Docker服务正在运行。"
    else
        echo "Docker服务未运行。"
    fi

    echo ""

    # 检查Docker Compose是否安装
    if command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose 已安装，版本信息："
        docker-compose --version
    else
        echo "Docker Compose 未安装。"
    fi
}

# 函数：退出脚本
exit_script() {
    echo "退出脚本。"
    exit 0
}

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
    echo "请以root用户或使用sudo运行此脚本。"
    exit 1
fi

# 主循环
while true; do
    show_menu
    read -p "请输入你的选择 [1-4]: " choice
    case $choice in
        1)
            install_docker
            ;;
        2)
            uninstall_docker
            ;;
        3)
            check_status
            ;;
        4)
            exit_script
            ;;
        *)
            echo "无效的选择，请输入1-4之间的数字。"
            ;;
    esac
    echo ""
done
