#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本。"
  exit 1
fi

# 定义安装函数
install_nginx() {
  echo "更新系统包..."
  apt update && apt upgrade -y

  echo "安装 Nginx、UFW 和 Certbot..."
  apt install -y nginx ufw certbot python3-certbot-nginx

  echo "确保 Nginx 配置目录存在..."
  mkdir -p /etc/nginx/sites-available
  mkdir -p /etc/nginx/sites-enabled

  echo "启动并启用 Nginx 服务..."
  systemctl start nginx
  systemctl enable nginx

  echo "配置防火墙允许 HTTP 和 HTTPS..."
  ufw allow 'Nginx Full'
  
  # 检查 UFW 是否已启用，若未启用则启用
  if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
  else
    echo "UFW 已经启用。"
  fi

  read -p "请输入你的邮箱地址（用于 Let's Encrypt 通知）： " EMAIL
  read -p "请输入你的域名（例如 example.com 或 sub.example.com）： " DOMAIN
  read -p "请输入反向代理的目标地址（例如 http://localhost:3000）： " TARGET

  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
  ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

  echo "配置 Nginx 反向代理..."
  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass $TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # 可选：设置 WebSocket 的超时时间
        proxy_read_timeout 86400;
    }
}
EOF

  echo "创建符号链接到 sites-enabled..."
  ln -s "$CONFIG_PATH" "$ENABLED_PATH"

  echo "测试 Nginx 配置..."
  nginx -t

  if [ $? -ne 0 ]; then
      echo "Nginx 配置测试失败，请检查配置文件。"
      rm "$ENABLED_PATH"
      exit 1
  fi

  echo "重新加载 Nginx..."
  systemctl reload nginx

  echo "申请 Let's Encrypt TLS 证书..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

  if [ $? -ne 0 ]; then
      echo "Certbot 申请证书失败。请检查域名的 DNS 设置是否正确。"
      exit 1
  fi

  echo "设置自动续期..."
  systemctl enable certbot.timer
  systemctl start certbot.timer

  echo "Nginx 反向代理和 TLS 证书配置完成！"
  echo "你的网站现在可以通过 https://$DOMAIN 访问。"
}

# 定义添加配置函数
add_config() {
  read -p "请输入要添加的域名（例如 example.com 或 sub.example.com）： " DOMAIN
  read -p "请输入反向代理的目标地址（例如 http://localhost:3000）： " TARGET
  read -p "请输入用于 TLS 证书的邮箱地址： " EMAIL

  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
  ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

  if [ -f "$CONFIG_PATH" ]; then
    echo "配置文件 $DOMAIN 已存在。"
    return
  fi

  echo "配置 Nginx 反向代理..."
  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass $TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # 可选：设置 WebSocket 的超时时间
        proxy_read_timeout 86400;
    }
}
EOF

  echo "创建符号链接到 sites-enabled..."
  ln -s "$CONFIG_PATH" "$ENABLED_PATH"

  echo "测试 Nginx 配置..."
  nginx -t

  if [ $? -ne 0 ]; then
      echo "Nginx 配置测试失败，请检查配置文件。"
      rm "$ENABLED_PATH"
      exit 1
  fi

  echo "重新加载 Nginx..."
  systemctl reload nginx

  echo "申请 Let's Encrypt TLS 证书..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

  if [ $? -ne 0 ]; then
      echo "Certbot 申请证书失败。请检查域名的 DNS 设置是否正确。"
      exit 1
  fi

  echo "配置添加完成！你的网站现在可以通过 https://$DOMAIN 访问。"
}

# 定义修改配置函数
modify_config() {
  echo "当前配置列表："
  ls /etc/nginx/sites-available/
  read -p "请输入要修改的域名（配置文件名）： " DOMAIN

  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"

  if [ ! -f "$CONFIG_PATH" ]; then
    echo "配置文件 $DOMAIN 不存在。"
    return
  fi

  read -p "请输入新的反向代理目标地址（例如 http://localhost:3000）： " NEW_TARGET

  # 询问是否需要更新 TLS 证书的邮箱地址
  while true; do
    read -p "是否需要更新 TLS 证书的邮箱地址？ (y/n): " update_email
    case $update_email in
      y|Y )
        UPDATE_EMAIL=true
        break
        ;;
      n|N )
        UPDATE_EMAIL=false
        break
        ;;
      * )
        echo "请输入 y 或 n。"
        ;;
    esac
  done

  if [ "$UPDATE_EMAIL" = true ]; then
    read -p "请输入新的邮箱地址： " NEW_EMAIL
  fi

  echo "更新 Nginx 配置..."
  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass $NEW_TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # 可选：设置 WebSocket 的超时时间
        proxy_read_timeout 86400;
    }
}
EOF

  echo "测试 Nginx 配置..."
  nginx -t

  if [ $? -ne 0 ]; then
      echo "Nginx 配置测试失败，请检查配置文件。"
      exit 1
  fi

  echo "重新加载 Nginx..."
  systemctl reload nginx

  echo "重新申请 Let's Encrypt TLS 证书..."
  if [ "$UPDATE_EMAIL" = true ]; then
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$NEW_EMAIL"
  else
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
  fi

  if [ $? -ne 0 ]; then
      echo "Certbot 申请证书失败。请检查域名的 DNS 设置是否正确。"
      exit 1
  fi

  if [ "$UPDATE_EMAIL" = true ]; then
    echo "更新 TLS 证书的邮箱地址..."
    certbot update_account --email "$NEW_EMAIL"

    if [ $? -ne 0 ]; then
        echo "Certbot 更新邮箱地址失败。"
        exit 1
    fi
  fi

  echo "配置修改完成！"
  echo "你的网站现在可以通过 https://$DOMAIN 访问。"
}

# 定义卸载函数
uninstall_nginx() {
  read -p "确定要卸载 Nginx 及所有配置吗？(y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "取消卸载。"
    return
  fi

  echo "停止并禁用 Nginx 服务..."
  systemctl stop nginx
  systemctl disable nginx

  echo "卸载 Nginx、UFW 和 Certbot..."
  apt remove --purge -y nginx ufw certbot python3-certbot-nginx

  echo "删除 Nginx 配置文件..."
  rm -rf /etc/nginx/sites-available/
  rm -rf /etc/nginx/sites-enabled/

  echo "移除防火墙规则..."
  ufw delete allow 'Nginx Full'

  echo "删除 Certbot 自动续期定时任务..."
  systemctl disable certbot.timer
  systemctl stop certbot.timer

  echo "Nginx 和相关配置已卸载。"
}

# 显示菜单
while true; do
  echo "======**一点科技**================"
  echo "      Nginx 管理脚本"
  echo "  博  客： https://1keji.net"
  echo "  YouTube：https://www.youtube.com/@1keji_net"
  echo "  GitHub： https://github.com/1keji"
  echo "==============================="
  echo "1. 安装 Nginx 及配置反向代理和 TLS"
  echo "2. 添加新的反向代理配置"
  echo "3. 修改现有的反向代理配置"
  echo "4. 卸载 Nginx 和所有配置"
  echo "0. 退出"
  echo "==============================="
  read -p "请选择一个选项 [0-4]: " choice

  case $choice in
    1)
      install_nginx
      ;;
    2)
      add_config
      ;;
    3)
      modify_config
      ;;
    4)
      uninstall_nginx
      ;;
    0)
      echo "退出脚本。"
      exit 0
      ;;
    *)
      echo "无效的选项，请重新选择。"
      ;;
  esac

  echo ""
done
