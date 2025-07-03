#!/bin/bash
# ---------------------------------------------------------------------
# Script: add_project.sh
# Description: Sets up a local WordPress development project under /var/www/
# Usage:
#   ./add_project.sh [domain.local]
# If no domain is provided, prompts interactively
# ---------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  echo -e "${RED}❌ Do NOT run this script as root or with sudo.${NC}"
  echo -e "${YELLOW}   Just run it normally — the script will use sudo where needed.${NC}"
  exit 1
fi

# Prompt for domain if not provided
if [[ -z "$1" ]]; then
  while true; do
    read -rp "Enter domain (e.g., site.local): " DOMAIN
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
      break
    else
      echo -e "${RED}Invalid domain. Use only letters, numbers, dots, and dashes.${NC}"
    fi
  done
else
  DOMAIN="$1"
  if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo -e "${RED}Invalid domain. Use only letters, numbers, dots, and dashes.${NC}"
    exit 1
  fi
fi

DB_NAME="wp_${DOMAIN//./_}"
DB_USER="root"
DB_PASS="root"

BASE_DIR="/var/www"
PROJECT_DIR="$BASE_DIR/$DOMAIN/wordpress"
CERT_DIR="$BASE_DIR/certs"
VHOST_FILE="/etc/apache2/sites-available/$DOMAIN.conf"

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Usage: $0 domain.local${NC}"
    exit 1
fi

if [[ -d "$PROJECT_DIR" ]]; then
    echo -e "${GREEN}Project already exists: $PROJECT_DIR — skipping.${NC}"
    exit 0
fi

# Create folder structure
echo -e "${GREEN}Creating project directory...${NC}"
sudo mkdir -p "$PROJECT_DIR"
sudo chown -R "$USER:www-data" "$BASE_DIR/$DOMAIN"
sudo chmod -R 775 "$BASE_DIR/$DOMAIN"

# Download and extract WordPress
echo -e "${GREEN}Downloading WordPress...${NC}"
wget -q https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
tar -xzf /tmp/latest.tar.gz -C /tmp/
sudo mv /tmp/wordpress/* "$PROJECT_DIR/"
rm -rf /tmp/latest.tar.gz /tmp/wordpress
sudo chown -R "$USER:www-data" "$PROJECT_DIR"

# Generate SSL with mkcert
echo -e "${GREEN}Generating SSL certificate for $DOMAIN...${NC}"
sudo mkdir -p "$CERT_DIR"
sudo chown "$USER:$USER" "$CERT_DIR"
cd "$CERT_DIR"
mkcert "$DOMAIN"
KEY="$CERT_DIR/$DOMAIN-key.pem"
CERT="$CERT_DIR/$DOMAIN.pem"

# Create Apache virtual host
echo -e "${GREEN}Creating Apache virtual host...${NC}"
sudo tee "$VHOST_FILE" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin webmaster@$DOMAIN
    ServerName $DOMAIN
    DocumentRoot $PROJECT_DIR

    SSLEngine on
    SSLCertificateFile $CERT
    SSLCertificateKeyFile $KEY

    <Directory $PROJECT_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

# Enable site and modules
echo -e "${GREEN}Enabling site and Apache modules...${NC}"
sudo a2enmod rewrite ssl
sudo a2ensite "$DOMAIN.conf"

# Add to /etc/hosts
if ! grep -q "$DOMAIN" /etc/hosts; then
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
fi

# Create MariaDB database
echo -e "${GREEN}Creating MariaDB database...${NC}"
sudo mariadb -u root -proot <<MYSQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
MYSQL

# Configure wp-config.php
echo -e "${GREEN}Configuring wp-config.php...${NC}"
sudo cp "$PROJECT_DIR/wp-config-sample.php" "$PROJECT_DIR/wp-config.php"
sudo sed -i "s/database_name_here/$DB_NAME/" "$PROJECT_DIR/wp-config.php"
sudo sed -i "s/username_here/$DB_USER/" "$PROJECT_DIR/wp-config.php"
sudo sed -i "s/password_here/$DB_PASS/" "$PROJECT_DIR/wp-config.php"
sudo sed -i "/<?php/a define('FS_METHOD', 'direct');" "$PROJECT_DIR/wp-config.php"

# Add WordPress salts
echo -e "${GREEN}Adding WordPress salts...${NC}"
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
sudo awk -v r="$SALTS" '
    BEGIN { split(r, lines, "\n") }
    /put your unique phrase here/ {
        if (!done) {
            for (i = 1; i <= length(lines); i++) print lines[i]
            done = 1
        }
        next
    }
    { print }
' "$PROJECT_DIR/wp-config.php" | sudo tee "$PROJECT_DIR/wp-config.php.tmp" > /dev/null
sudo mv "$PROJECT_DIR/wp-config.php.tmp" "$PROJECT_DIR/wp-config.php"
sudo chown "$USER:www-data" "$PROJECT_DIR/wp-config.php"

# Ensure proper permissions for WordPress
echo -e "${GREEN}Fixing file permissions...${NC}"
sudo chown -R "$USER:www-data" "$PROJECT_DIR"
sudo find "$PROJECT_DIR" -type d -exec chmod 775 {} \;
sudo find "$PROJECT_DIR" -type f -exec chmod 664 {} \;

# Reload Apache and install mkcert CA
echo -e "${GREEN}Reloading Apache and installing mkcert root CA...${NC}"
sudo systemctl reload apache2
mkcert -install

echo -e "${YELLOW}💡 Note: For mkcert HTTPS to work properly, use browsers installed via .deb packages (e.g. Firefox or Brave). Browsers installed via Snap may not trust the local certificates.${NC}"
echo
echo -e "${GREEN}✅ Done! Visit: https://$DOMAIN to finish WordPress setup.${NC}"
echo
