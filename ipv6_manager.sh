#!/bin/bash

# Function to bind IPv6 on Debian
Debian_IPv6(){
    echo "正在为Debian系统配置IPv6..."

    iName=$(ip -6 addr | grep "^2: " | awk -F'[ :]' '{print $3}')
    if [ -z "$iName" ]; then
        echo "未能找到有效的网络接口。请检查网络接口名称。"
        exit 1
    fi

    echo "启用IPv6临时..."
    dhclient -6 "$iName"
    echo "网卡名称: $iName"

    # 备份当前interfaces文件
    cp /etc/network/interfaces /root/interfaces.backup.$(date +%F_%T)

    # 检查是否已配置过IPv6
    if grep -q "iface $iName inet6 dhcp" /etc/network/interfaces; then
        echo "IPv6已配置，无需重复配置。"
    else
        # 添加IPv6配置
        echo "iface $iName inet6 dhcp" >> /etc/network/interfaces
        echo "IPv6配置已添加到 /etc/network/interfaces"
    fi

    echo "即将重启系统以应用更改..."
    reboot
}

# Function to bind IPv6 on Ubuntu
Ubuntu_IPv6(){
    echo "正在为Ubuntu系统配置IPv6..."

    yamlName=$(find /etc/netplan/ -iname "*.yaml" | head -n 1)
    if [ -z "$yamlName" ]; then
        echo "未找到Netplan配置文件。"
        exit 1
    fi

    iName=$(ip -6 addr | grep "^2: " | awk -F'[ :]' '{print $3}')
    if [ -z "$iName" ]; then
        echo "未能找到有效的网络接口。请检查网络接口名称。"
        exit 1
    fi

    echo "启用IPv6临时..."
    dhclient -6 "$iName"

    MAC=$(ip link show "$iName" | grep "link/ether" | awk '{print $2}')
    IPv6=$(ip -6 addr show "$iName" | grep "inet6 .* global" | awk '{print $2}' | cut -d'/' -f1)

    if [[ ${#IPv6} -lt 5 ]]; then
        echo "无法获取有效的IPv6地址。"
        exit 1
    fi

    # 备份当前Netplan配置
    cp "$yamlName" /root/"$(basename "$yamlName")".backup.$(date +%F_%T)

    # 创建新的Netplan配置
    cat <<EOF >"$yamlName"
network:
   version: 2
   ethernets:
      $iName:
          dhcp4: true
          dhcp6: false
          match:
              macaddress: $MAC
          addresses:
              - $IPv6/64
          set-name: $iName
EOF

    echo "Netplan配置已更新到 $yamlName"
    netplan apply

    echo "等待2秒后测试IPv6连接..."
    sleep 2s
    ping6 -c 4 ipv6.google.com
}

# Function to check IPv6 status
Check_IPv6(){
    echo "正在检查IPv6状态..."
    ip -6 addr
}

# Function to display menu
Show_Menu(){
    echo "==============================="
    echo "      IPv6 管理脚本"
    echo "==============================="
    echo "1. 绑定IPv6"
    echo "2. 查询IPv6状态"
    echo "0. 退出"
    echo "==============================="
}

# 主程序
while true; do
    Show_Menu
    read -p "请输入您的选择 [1-3]: " choice
    case $choice in
        1)
            myOS=$(hostnamectl | grep "Operating System" | awk -F': ' '{print $2}')
            if [[ "$myOS" =~ "Ubuntu" ]]; then
                echo "检测到操作系统: Ubuntu"
                Ubuntu_IPv6
            elif [[ "$myOS" =~ "Debian" ]]; then
                echo "检测到操作系统: Debian"
                Debian_IPv6
            else
                echo "不支持的操作系统: $myOS"
            fi
            ;;
        2)
            Check_IPv6
            ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择，请输入1、2或0。"
            ;;
    esac
done
