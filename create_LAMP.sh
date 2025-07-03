#!/bin/bash
# ---------------------------------------------------------------------
# Script: create-LAMP.sh
# Description: Installs LAMP stack with WordPress support, phpMyAdmin,
#              MailHog, mkcert, and Xdebug.
# Target: Ubuntu (Debian-based)
# ---------------------------------------------------------------------

set -e

if [ "$(id -u)" -eq 0 ]; then
  echo -e "${RED}❌ Do NOT run this script as root or with sudo.${NC}"
  echo -e "${YELLOW}   Just run it normally — the script will use sudo where needed.${NC}"
  exit 1
fi

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

if ! lsof /var/lib/dpkg/lock-frontend &>/dev/null; then
  echo -e "${GREEN}🔧 Updating system packages...${NC}"
  sudo apt update && sudo apt upgrade -y
else
  echo -e "${YELLOW}⚠️ Skipping apt update/upgrade because dpkg lock is active (likely during .deb install).${NC}"
fi

# ---------------------------------------------------------------------
# Install LAMP Stack Components
# ---------------------------------------------------------------------
echo -e "${GREEN}📦 Installing Apache, MariaDB, PHP, and modules...${NC}"
sudo apt install -y apache2 mariadb-server \
  php php-mysql php-curl php-gd php-mbstring php-xml php-zip \
  php-soap php-intl php-bcmath php-cli php-common php-dev \
  php-imagick php-xdebug wget unzip curl

PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# ---------------------------------------------------------------------
# Prepare /var/www
# ---------------------------------------------------------------------
echo -e "${GREEN}📁 Preparing /var/www...${NC}"
sudo mkdir -p /var/www
sudo chown -R "$USER:www-data" /var/www
sudo chmod -R 775 /var/www

# ---------------------------------------------------------------------
# Install phpMyAdmin non-interactively
# ---------------------------------------------------------------------
echo -e "${GREEN}🛠 Installing phpMyAdmin...${NC}"
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password root" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password root" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password root" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
sudo apt install -y phpmyadmin

# ---------------------------------------------------------------------
# Secure MariaDB root
# ---------------------------------------------------------------------
echo -e "${GREEN}🔐 Checking MariaDB root password...${NC}"
if mariadb -u root -proot -e "SELECT 1;" &>/dev/null; then
  echo -e "${GREEN}✅ MariaDB root password already set.${NC}"
else
  echo -e "${YELLOW}Setting MariaDB root password to 'root'...${NC}"
  sudo mariadb -u root <<MYSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';
FLUSH PRIVILEGES;
MYSQL
fi

sudo systemctl restart apache2
sudo systemctl restart mariadb

# ---------------------------------------------------------------------
# Apache Modules
# ---------------------------------------------------------------------
echo -e "${GREEN}☑️ Enabling Apache modules...${NC}"
sudo a2enmod rewrite ssl

# ---------------------------------------------------------------------
# MailHog & mhsendmail
# ---------------------------------------------------------------------
if ! command -v MailHog &>/dev/null; then
  echo -e "${GREEN}🐶 Installing MailHog and mhsendmail...${NC}"
  wget -qO ~/MailHog https://github.com/mailhog/MailHog/releases/download/v1.0.1/MailHog_linux_amd64
  chmod +x ~/MailHog && sudo mv ~/MailHog /usr/local/bin/

  wget -qO ~/mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64
  chmod +x ~/mhsendmail && sudo mv ~/mhsendmail /usr/local/bin/

  echo "sendmail_path = /usr/local/bin/mhsendmail" | sudo tee /etc/php/$PHP_VERSION/mods-available/mhsendmail.ini
  sudo phpenmod mhsendmail

  sudo tee /etc/systemd/system/mailhog.service > /dev/null <<EOF
[Unit]
Description=MailHog Service
After=network.target

[Service]
ExecStart=/usr/local/bin/MailHog
Restart=always
User=$USER
Group=www-data

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable --now mailhog
else
  echo -e "${YELLOW}MailHog already installed — skipping.${NC}"
fi

# ---------------------------------------------------------------------
# Configure Xdebug
# ---------------------------------------------------------------------
echo -e "${GREEN}🧪 Configuring Xdebug...${NC}"
XDEBUG_INI="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"
sudo tee "$XDEBUG_INI" > /dev/null <<EOF
zend_extension=xdebug.so
xdebug.mode=develop,debug
xdebug.start_with_request=yes
xdebug.client_host=127.0.0.1
xdebug.client_port=9003
EOF

# ---------------------------------------------------------------------
# Install mkcert
# ---------------------------------------------------------------------
echo -e "${GREEN}🔒 Installing mkcert...${NC}"
if command -v mkcert >/dev/null 2>&1; then
  echo -e "${GREEN}✅ mkcert already installed.${NC}"
else
  sudo apt install -y libnss3-tools
  URL="https://dl.filippo.io/mkcert/latest?for=linux/amd64"
  OUTPUT="mkcert"
  if curl --fail -Lo "$OUTPUT" "$URL"; then
    if [ -s "$OUTPUT" ] && file "$OUTPUT" | grep -q "ELF"; then
      chmod +x "$OUTPUT"
      sudo mv mkcert /usr/local/bin/mkcert
      echo -e "${GREEN}✅ mkcert installed.${NC}"
    else
      echo -e "${RED}❌ Error: mkcert file is not a valid binary.${NC}"
      exit 1
    fi
  else
    echo -e "${RED}❌ Error: curl - mkcert download failed.${NC}"
    exit 1
  fi
fi

mkcert -install

# ---------------------------------------------------------------------
# Apache: Enable .htaccess override
# ---------------------------------------------------------------------
echo -e "${GREEN}🔐 Enabling .htaccess overrides in Apache...${NC}"
sudo sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
sudo systemctl reload apache2

# ---------------------------------------------------------------------
# Group Permissions
# ---------------------------------------------------------------------
echo -e "${GREEN}👥 Ensuring user is in www-data group...${NC}"
if ! id -nG "$USER" | grep -qw "www-data"; then
  sudo usermod -aG www-data "$USER"
  echo -e "${YELLOW}➕ User added to www-data group.${NC}"
  echo -e "${RED}⚠️ Please log out and back in, or run: newgrp www-data${NC}"
else
  echo -e "${GREEN}✅ User already in www-data group.${NC}"
fi

# ---------------------------------------------------------------------
# Create info.php file in /var/www/html/info.php
# ---------------------------------------------------------------------
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php > /dev/null

# ---------------------------------------------------------------------
# Done — with a nice boxed banner
# ---------------------------------------------------------------------
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 LAMP environment is ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🌐 Services:${NC}"
echo -e "   🧱 Apache default → ${YELLOW}http://localhost${NC}"
echo -e "   🧪 PHP info       → ${YELLOW}http://localhost/info.php${NC}"
echo -e "   🛠 phpMyAdmin     → ${YELLOW}http://localhost/phpmyadmin${NC} ${NC}(login: ${GREEN}root/root${NC})"
echo -e "   📬 MailHog        → ${YELLOW}http://localhost:8025${NC}"
echo -e ""
echo -e "${GREEN}⚙️  To create your first WordPress site:${NC}"
echo -e "   ${YELLOW}/opt/wordpress-tools/add_project.sh${NC}"
echo -e ""
echo -e "${GREEN}✨ Happy coding, Jonny! ✨${NC}"
echo -e "${GREEN}========================================${NC}"
