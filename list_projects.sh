#!/bin/bash
# ---------------------------------------------------------------------
# Script: list_projects.sh
# Description: Scans /var/www for WordPress projects and checks:
#   - wp-config.php presence
#   - SSL certificate presence (via mkcert)
#   - Database existence in MariaDB
# ---------------------------------------------------------------------

BASE_DIR="/var/www"
CERT_DIR="$BASE_DIR/certs"
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

printf "\n📁 Scanning WordPress projects in $BASE_DIR...\n"
printf "\n%-20s %-17s %-17s %-10s\n" "Domain" "WordPress Config" "SSL Certificate" "Database"
echo "$(printf '%0.s-' {1..70})"

for domain_path in "$BASE_DIR"/*; do
    [[ -d "$domain_path/wordpress" ]] || continue

    DOMAIN=$(basename "$domain_path")
    WP_DIR="$domain_path/wordpress"
    CONFIG="$WP_DIR/wp-config.php"
    CERT="$CERT_DIR/$DOMAIN.pem"
    DB_NAME="wp_${DOMAIN//./_}"

    [[ -f "$CONFIG" ]] && WP_STATUS="✔ Yes" || WP_STATUS="✘ No"
    [[ -f "$CERT" ]] && CERT_STATUS="✔ Yes" || CERT_STATUS="✘ No"

    DB_EXISTS=$(mariadb -u root -proot -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | grep "$DB_NAME")
    [[ -n "$DB_EXISTS" ]] && DB_STATUS="✔ Exists" || DB_STATUS="✘ Missing"

    printf "%-20s %-17s %-17s %-10s\n" "$DOMAIN" "$WP_STATUS" "$CERT_STATUS" "$DB_STATUS"
done
