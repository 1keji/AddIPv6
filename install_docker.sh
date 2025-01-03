#!/bin/bash

# Docker 和 Docker Compose 管理脚本
# 提供安装、卸载、查询状态和退出选项
# 适用于 Ubuntu 和 Debian 系统

set -e

# 函数：显示菜单
show_menu() {
    echo "===========**一点科技**==================="
    echo "Docker 和 Docker Compose 管理脚本"
    echo "  博  客： https://1keji.net"
    echo "  YouTube：https://www.youtube.com/@1keji_net"
    echo "  GitHub： https://github.com/1keji"
    echo "=========================================="
    echo "1. 安装 Docker 和 Docker Compose"
    echo "2. 卸载 Docker 和 Docker Compose"
    echo "3. 查询安装情况和运行状态"
    echo "0. 退出脚本"
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

# 函数：删除错误的 Docker 仓库配置
remove_incorrect_docker_repo() {
    echo "检查并删除错误的 Docker 仓库配置..."

    # 定义正确的仓库 URL
    CORRECT_REPO="https://download.docker.com/linux/${OS}"

    # 在 sources.list 中查找错误的 Docker 仓库配置
    if grep -E "download.docker.com/linux/(ubuntu|debian)" /etc/apt/sources.list | grep -v "${CORRECT_REPO}" >/dev/null 2>&1; then
        echo "在 /etc/apt/sources.list 中发现错误的 Docker 仓库配置，正在删除..."
        sed -i "/download.docker.com\/linux\/\(ubuntu\|debian\)/d" /etc/apt/sources.list
    fi

    # 在 sources.list.d 目录下查找并删除错误的 Docker 仓库配置文件
    for file in /etc/apt/sources.list.d/*.list; do
        if [ -f "$file" ]; then
            if grep -E "download.docker.com/linux/(ubuntu|debian)" "$file" | grep -v "${CORRECT_REPO}" >/dev/null 2>&1; then
                echo "发现错误的 Docker 仓库配置文件：$file，正在删除..."
                rm -f "$file"
            fi
        fi
    done
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

    # 检查并删除错误的 Docker 仓库配置
    remove_incorrect_docker_repo

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

    # 将当前用户添加到 docker 用户组（以便无需 sudo 运行 Docker 命令）
    echo "将当前用户添加到 docker 用户组（以便无需 sudo 运行 Docker 命令）..."

    # 获取所有系统用户
    USERS=$(cut -d: -f1 /etc/passwd | sort)

    # 判断是否通过 sudo 运行，获取默认用户名
    if [ -n "$SUDO_USER" ]; then
        DEFAULT_USER="$SUDO_USER"
    else
        DEFAULT_USER=""
    fi

    echo "现有用户列表："
    echo "$USERS"
    echo "如果您不需要添加用户到 docker 组，可以直接按回车键跳过。"

    read -p "请输入要添加到 docker 组的用户名（默认为当前用户）： " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USER}

    if [ -z "$USERNAME" ]; then
        echo "未指定用户，跳过添加到 docker 组。"
    else
        # 检查用户是否存在
        if id "$USERNAME" >/dev/null 2>&1; then
            if id -nG "$USERNAME" | grep -qw "docker"; then
                echo "用户 $USERNAME 已经在 docker 组中。"
            else
                usermod -aG docker "$USERNAME"
                echo "用户 $USERNAME 已添加到 docker 组。"
                echo "请注销并重新登录以使更改生效。"
            fi
        else
            echo "用户 $USERNAME 不存在，无法添加到 docker 组。"
        fi
    fi

    echo "Docker 和 Docker Compose 安装完成！"
}

# 函数：卸载 Docker 和 Docker Compose
uninstall_docker() {
    echo "开始卸载 Docker 和 Docker Compose..."

    # 停止并禁用 Docker 服务
    echo "停止并禁用 Docker 服务..."
    systemctl stop docker
    systemctl disable docker

    # 卸载 Docker Engine、CLI 和 容器运行时
    echo "卸载 Docker Engine、CLI 和 容器运行时..."
    apt-get purge -y docker-ce docker-ce-cli containerd.io

    # 删除所有 Docker 数据
    echo "删除所有 Docker 数据..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd

    # 删除 Docker Compose
    echo "删除 Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose

    # 删除 Docker 的 APT 仓库
    echo "删除 Docker 的 APT 仓库..."
    rm -f /etc/apt/sources.list.d/docker.list

    # 删除 Docker 的 GPG 密钥
    echo "删除 Docker 的 GPG 密钥..."
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg

    # 更新 APT 包索引
    echo "更新 APT 包索引..."
    apt-get update -y

    # 从 docker 组中移除用户
    echo "从 docker 组中移除用户..."

    # 获取所有系统用户
    USERS=$(cut -d: -f1 /etc/passwd | sort)

    # 判断是否通过 sudo 运行，获取默认用户名
    if [ -n "$SUDO_USER" ]; then
        DEFAULT_USER="$SUDO_USER"
    else
        DEFAULT_USER=""
    fi

    echo "现有用户列表："
    echo "$USERS"
    echo "如果您不需要移除用户，可以直接按回车键跳过。"

    read -p "请输入要从 docker 组中移除的用户名（默认为当前用户）： " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USER}

    if [ -z "$USERNAME" ]; then
        echo "未指定用户，跳过从 docker 组中移除。"
    else
        # 检查用户是否存在
        if id "$USERNAME" >/dev/null 2>&1; then
            if id -nG "$USERNAME" | grep -qw "docker"; then
                gpasswd -d "$USERNAME" docker
                echo "用户 $USERNAME 已从 docker 组中移除。"
            else
                echo "用户 $USERNAME 不在 docker 组中。"
            fi
        else
            echo "用户 $USERNAME 不存在，无法从 docker 组中移除。"
        fi
    fi

    echo "Docker 和 Docker Compose 已成功卸载！"
}

# 函数：查询安装情况和运行状态
check_status() {
    echo "查询 Docker 和 Docker Compose 的安装情况和运行状态..."

    # 检查 Docker 是否安装
    if command -v docker >/dev/null 2>&1; then
        echo "Docker 已安装，版本信息："
        docker --version
    else
        echo "Docker 未安装。"
    fi

    # 检查 Docker 服务状态
    if systemctl is-active --quiet docker; then
        echo "Docker 服务正在运行。"
    else
        echo "Docker 服务未运行。"
    fi

    echo ""

    # 检查 Docker Compose 是否安装
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

# 检查是否以 root 用户运行
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
REPO_URL="https://download.docker.com/linux/${OS}/dists/${VERSION_CODENAME}/stable/"
echo "正在检查 Docker 仓库是否存在： $REPO_URL"

if ! curl --head --silent --fail "$REPO_URL" >/dev/null; then
    echo "错误： Docker 仓库不存在或不可访问。请检查操作系统类型和版本代号。"
    echo "请确保 Docker 支持您的操作系统版本。"
    exit 1
fi

# 主循环
while true; do
    show_menu
    read -p "请输入你的选择 [0,1-3]: " choice
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
        0)
            exit_script
            ;;
        *)
            echo "无效的选择，请输入 0 或 1-3 之间的数字。"
            ;;
    esac
    echo ""
done
