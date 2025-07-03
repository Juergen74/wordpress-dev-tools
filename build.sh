#!/bin/bash

set -e

PACKAGE_NAME="wordpress-dev-tools"
VERSION="1.0.0"
BUILD_DIR="./${PACKAGE_NAME}"
INSTALL_DIR="${BUILD_DIR}/opt/wordpress-tools"
DEBIAN_DIR="${BUILD_DIR}/DEBIAN"
OUTPUT="${PACKAGE_NAME}.deb"

echo "🧹 Cleaning old builds..."
rm -rf "$BUILD_DIR" "$OUTPUT"

echo "📁 Creating folder structure..."
mkdir -p "$INSTALL_DIR" "$DEBIAN_DIR"

echo "📦 Copying scripts..."
cp create-LAMP.sh add_project.sh remove_project.sh list_projects.sh setup-gui-tools.sh DISCLAIMER.txt LICENSE.txt wordpress_dev_readme.md "$INSTALL_DIR"

echo "📝 Writing control file..."
cat > "${DEBIAN_DIR}/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: web
Priority: optional
Architecture: all
Depends:
Maintainer: Jonny <info@layart.org>
Description: Local WordPress dev stack with LAMP, MailHog, mkcert, Xdebug.
 Installs all tools and scripts for rapid WordPress development.
EOF

echo "📋 Writing postinst..."
cat > "${DEBIAN_DIR}/postinst" <<'EOF'
#!/bin/bash

echo "✅ wordpress-dev-tools successfully installed!"

echo
echo "🎉 To complete your local development setup, run:"
echo "   /opt/wordpress-tools/create-LAMP.sh"
echo
echo "📁 Available tools:"
echo "   /opt/wordpress-tools/add_project.sh           → Create new WordPress site"
echo "   /opt/wordpress-tools/remove_project.sh        → Remove WordPress site"
echo "   /opt/wordpress-tools/list_projects.sh         → List all WordPress sites"
echo "   /opt/wordpress-tools/setup-gui-tools.sh       → (optional) Install GUI tools (Brave, Chrome, Firefox, VS Code, gnome-sushi) with dev bookmarks"
echo

exit 0
EOF

chmod +x "${DEBIAN_DIR}/postinst"

echo "🚀 Building .deb package..."
dpkg-deb --build "$BUILD_DIR"

echo
echo "✅ Done! Created: $OUTPUT"

echo
echo "🔧 To install it:"
echo "   sudo dpkg -i $OUTPUT"
echo
echo "📂 Then run:"
echo "   /opt/wordpress-tools/create-LAMP.sh"
echo




