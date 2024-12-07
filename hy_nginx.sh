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

  # 创建网站根目录
  WEB_ROOT="/var/www/$DOMAIN/html"
  echo "创建网站根目录 $WEB_ROOT ..."
  mkdir -p "$WEB_ROOT"
  chown -R www-data:www-data /var/www/"$DOMAIN"
  chmod -R 755 /var/www/"$DOMAIN"

  # 创建默认的 index.html
  echo "创建默认的 index.html..."
  cat > "$WEB_ROOT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $DOMAIN!</title>
</head>
<body>
    <h1>成功部署 Nginx！</h1>
    <p>您的域名 <strong>$DOMAIN</strong> 已经成功配置并启用了 TLS。</p>
</body>
</html>
EOF

  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
  ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

  echo "配置 Nginx 服务器块..."
  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.html index.htm index.nginx-debian.html;

    location / {
        try_files \$uri \$uri/ =404;
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
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

  if [ $? -ne 0 ]; then
      echo "Certbot 申请证书失败。请检查域名的 DNS 设置是否正确。"
      exit 1
  fi

  echo "设置自动续期..."
  systemctl enable certbot.timer
  systemctl start certbot.timer

  echo "Nginx 配置和 TLS 证书申请完成！"
  echo "你的网站现在可以通过 https://$DOMAIN 访问。"
}

# 定义添加配置函数
add_config() {
  read -p "请输入要添加的域名（例如 example.com 或 sub.example.com）： " DOMAIN
  read -p "请输入用于 TLS 证书的邮箱地址： " EMAIL

  # 创建网站根目录
  WEB_ROOT="/var/www/$DOMAIN/html"
  echo "创建网站根目录 $WEB_ROOT ..."
  mkdir -p "$WEB_ROOT"
  chown -R www-data:www-data /var/www/"$DOMAIN"
  chmod -R 755 /var/www/"$DOMAIN"

  # 创建默认的 index.html
  echo "创建默认的 index.html..."
  cat > "$WEB_ROOT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $DOMAIN!</title>
</head>
<body>
    <h1>成功部署 Nginx！</h1>
    <p>您的域名 <strong>$DOMAIN</strong> 已经成功配置并启用了 TLS。</p>
</body>
</html>
EOF

  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
  ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

  if [ -f "$CONFIG_PATH" ]; then
    echo "配置文件 $DOMAIN 已存在。"
    return
  fi

  echo "配置 Nginx 服务器块..."
  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.html index.htm index.nginx-debian.html;

    location / {
        try_files \$uri \$uri/ =404;
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
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

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

  read -p "是否需要更改域名？ (y/n): " change_domain
  if [[ "$change_domain" =~ ^[Yy]$ ]]; then
    read -p "请输入新的域名： " NEW_DOMAIN
  else
    NEW_DOMAIN="$DOMAIN"
  fi

  read -p "是否需要更改 TLS 证书的邮箱地址？ (y/n): " change_email
  if [[ "$change_email" =~ ^[Yy]$ ]]; then
    read -p "请输入新的邮箱地址： " NEW_EMAIL
  else
    NEW_EMAIL=""
  fi

  # 如果域名有变化，处理文件和目录
  if [ "$NEW_DOMAIN" != "$DOMAIN" ]; then
    echo "更改域名为 $NEW_DOMAIN ..."

    # 重命名网站根目录
    OLD_WEB_ROOT="/var/www/$DOMAIN/html"
    NEW_WEB_ROOT="/var/www/$NEW_DOMAIN/html"
    mv "$OLD_WEB_ROOT" "$NEW_WEB_ROOT"
    mkdir -p "$NEW_WEB_ROOT"
    chown -R www-data:www-data /var/www/"$NEW_DOMAIN"
    chmod -R 755 /var/www/"$NEW_DOMAIN"

    # 更新 index.html 中的域名
    sed -i "s/$DOMAIN/$NEW_DOMAIN/g" "$NEW_WEB_ROOT/index.html"

    # 更新配置文件
    sed -i "s/server_name $DOMAIN;/server_name $NEW_DOMAIN;/g" "$CONFIG_PATH"

    # 重命名配置文件
    mv "$CONFIG_PATH" "/etc/nginx/sites-available/$NEW_DOMAIN"
    rm "/etc/nginx/sites-enabled/$DOMAIN"
    ln -s "/etc/nginx/sites-available/$NEW_DOMAIN" "/etc/nginx/sites-enabled/$NEW_DOMAIN"

    DOMAIN="$NEW_DOMAIN"
  fi

  # 如果需要更改邮箱地址
  if [ "$change_email" =~ ^[Yy]$ ]; then
    EMAIL="$NEW_EMAIL"
  else
    EMAIL=""
  fi

  echo "测试 Nginx 配置..."
  nginx -t

  if [ $? -ne 0 ]; then
      echo "Nginx 配置测试失败，请检查配置文件。"
      exit 1
  fi

  echo "重新加载 Nginx..."
  systemctl reload nginx

  echo "重新申请 Let's Encrypt TLS 证书..."
  if [ -n "$EMAIL" ]; then
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
  else
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --redirect
  fi

  if [ $? -ne 0 ]; then
      echo "Certbot 申请证书失败。请检查域名的 DNS 设置是否正确。"
      exit 1
  fi

  echo "配置修改完成！你的网站现在可以通过 https://$DOMAIN 访问。"
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

  echo "删除 Nginx 配置文件和网站根目录..."
  rm -rf /etc/nginx/sites-available/
  rm -rf /etc/nginx/sites-enabled/
  rm -rf /var/www/

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
  echo "1. 安装 Nginx 及配置网站和 TLS"
  echo "2. 添加新的网站配置"
  echo "3. 修改现有的网站配置"
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
