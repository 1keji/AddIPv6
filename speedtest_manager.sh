#!/bin/bash

# Speedtest CLI Installation Script
# 本测速脚本使用的是Speedtest官方测速程序。如果之前安装过官方旧版或者非官方版本，请先选2卸载之前的版本。

echo "========================="
echo " Speedtest CLI 管理工具 "
echo "========================="
echo "请选择一个操作:"
echo "1. 安装 Speedtest CLI"
echo "2. 移除旧版本和非官方版本"
echo "3. 卸载 Speedtest CLI"
echo "4. 运行 Speedtest 测速"
echo "0. 退出"

echo -n "请输入你的选择: "
read choice

case "$choice" in
  1)
    echo "正在安装 Speedtest CLI..."
    # 安装 curl
    sudo apt-get install -y curl
    # 下载并执行官方安装脚本
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    # 安装 Speedtest CLI
    sudo apt-get install -y speedtest
    echo "Speedtest CLI 安装完成。"
    ;;
  2)
    echo "正在移除旧版本和非官方版本..."
    # 删除旧的 speedtest 软件源列表文件
    sudo rm -f /etc/apt/sources.list.d/speedtest.list
    # 更新软件包列表
    sudo apt-get update
    # 移除旧版本 speedtest
    sudo apt-get remove -y speedtest
    # 移除非官方版本 speedtest-cli
    sudo apt-get remove -y speedtest-cli
    echo "旧版本和非官方版本已移除。"
    ;;
  3)
    echo "正在卸载 Speedtest CLI..."
    # 卸载 Speedtest CLI
    sudo apt-get remove -y speedtest
    echo "Speedtest CLI 已卸载。"
    ;;
  4)
    echo "正在运行 Speedtest 测速..."
    # 运行 Speedtest 测速
    speedtest
    ;;
  0)
    echo "退出脚本。"
    exit 0
    ;;
  *)
    echo "无效选择，请重新运行脚本并选择正确的选项。"
    ;;
esac
