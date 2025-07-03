#!/bin/bash
#
# ---------------------------------------------------------------------
# Script: remove_project.sh
# Description: Removes a local WordPress development project with:
#   - Apache virtual host (HTTP + HTTPS)
#   - SSL certificates
#   - MariaDB database
#   - Directory structure in /var/www/domain.local/wordpress
#
# Usage:
#   ./remove_project.sh domain.local
#
# Example:
#   ./remove_project.sh mysite.local
#
# Result:
#   - Project will be completely removed from local environment
#
# Prerequisites:
#   - Project was created using add_project.sh
# ---------------------------------------------------------------------

DOMAIN=$1
PROJECT_DIR="/var/www/$DOMAIN/wordpress"
PROJECT_FOLDER="/var/www/$DOMAIN"
CERT_DIR="/var/www/certs"
VHOST_FILE="/etc/apache2/sites-available/$DOMAIN.conf"
DB_NAME="wp_${DOMAIN//./_}"

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Usage: $0 domain.local${NC}"
    exit 1
fi

# Ensure the project directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo -e "${RED}Project not found: $PROJECT_DIR${NC}"
    exit 1
fi

# Disable Apache site
echo -e "${GREEN}Disabling Apache virtual host...${NC}"
sudo a2dissite "$DOMAIN.conf"

# Remove SSL certificates
echo -e "${GREEN}Removing SSL certificates...${NC}"
sudo rm -f "$CERT_DIR/$DOMAIN.pem" "$CERT_DIR/$DOMAIN-key.pem"

# Remove Apache virtual host config
echo -e "${GREEN}Removing Apache virtual host configuration...${NC}"
sudo rm -f "$VHOST_FILE"

# Remove from /etc/hosts
echo -e "${GREEN}Removing domain from /etc/hosts...${NC}"
sudo sed -i "/$DOMAIN/d" /etc/hosts

# Drop MariaDB database
echo -e "${GREEN}Dropping MariaDB database...${NC}"
sudo mariadb -u root -proot <<MYSQL
DROP DATABASE IF EXISTS \`$DB_NAME\`;
MYSQL

# Remove project directory
echo -e "${GREEN}Removing WordPress directory...${NC}"
sudo rm -rf "$PROJECT_DIR"

# Remove empty parent folder
if [[ -d "$PROJECT_FOLDER" && ! "$(ls -A "$PROJECT_FOLDER")" ]]; then
    echo -e "${GREEN}Removing empty directory: $PROJECT_FOLDER${NC}"
    sudo rmdir "$PROJECT_FOLDER"
fi

# Reload Apache
echo -e "${GREEN}Reloading Apache...${NC}"
sudo systemctl reload apache2

echo -e "${GREEN}✅ Project $DOMAIN removed successfully!${NC}"
