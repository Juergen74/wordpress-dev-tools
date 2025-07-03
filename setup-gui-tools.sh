#!/bin/bash

set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

confirm() {
  local prompt="$1"
  printf "${YELLOW}%s (Y/n): ${NC}" "$prompt"
  read -r choice
  case "$choice" in
    [Yy]*|"") return 0;;
    *) return 1;;
  esac
}

add_browser_bookmarks() {
  local browser_config="$1"
  local bookmarks_file="$2"
  echo -e "${GREEN}📑 Setting up bookmarks for $browser_config...${NC}"

  if [ -f "$bookmarks_file" ]; then
    echo -e "${YELLOW}⚠️ Bookmarks file already exists — not overwriting.${NC}"
  else
    mkdir -p "$(dirname "$bookmarks_file")"
    cat > "$bookmarks_file" <<EOF
{
  "checksum": "",
  "roots": {
    "bookmark_bar": {
      "children": [
        { "date_added": "13269505596000000", "id": "1", "name": "localhost", "type": "url", "url": "http://localhost" },
        { "date_added": "13269505596000001", "id": "2", "name": "phpinfo", "type": "url", "url": "http://localhost/info.php" },
        { "date_added": "13269505596000002", "id": "3", "name": "phpMyAdmin", "type": "url", "url": "http://localhost/phpmyadmin" },
        { "date_added": "13269505596000003", "id": "4", "name": "MailHog", "type": "url", "url": "http://localhost:8025" }
      ],
      "date_added": "13269505596000000",
      "date_modified": "0",
      "id": "1",
      "name": "Bookmarks Bar",
      "type": "folder"
    },
    "other": { "children": [], "type": "folder" },
    "synced": { "children": [], "type": "folder" }
  },
  "version": 1
}
EOF
    echo -e "${GREEN}✅ Bookmarks set for $browser_config. Restart $browser_config to see them.${NC}"
  fi
}

# ---------------------------------------------------------------------
# Update APT
# ---------------------------------------------------------------------
echo -e "${GREEN}🔧 Updating APT...${NC}"
sudo apt update

# ---------------------------------------------------------------------
# 1. gnome-sushi: Quick Look
# ---------------------------------------------------------------------
if confirm "📂 Install gnome-sushi for macOS-style Quick Look (preview files with Space)?"; then
  echo -e "${GREEN}Installing gnome-sushi...${NC}"
  sudo apt install -y gnome-sushi
else
  echo -e "${YELLOW}Skipping gnome-sushi.${NC}"
fi

# ---------------------------------------------------------------------
# 2. Visual Studio Code
# ---------------------------------------------------------------------
if confirm "🧠 Install Visual Studio Code (via official Microsoft .deb repo)?"; then
  echo -e "${GREEN}Installing VS Code...${NC}"
  if ! command -v code &>/dev/null; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
  else
    echo -e "${YELLOW}VS Code already installed or repo exists — skipping key/repo.${NC}"
  fi
  INSTALL_CODE=true
else
  echo -e "${YELLOW}Skipping VS Code.${NC}"
  INSTALL_CODE=false
fi

# ---------------------------------------------------------------------
# 3. Brave Browser
# ---------------------------------------------------------------------
if confirm "🌍 Install Brave Browser (via .deb repo, works with mkcert)?"; then
  echo -e "${GREEN}Installing Brave...${NC}"
  if ! command -v brave-browser &>/dev/null; then
    sudo apt install -y curl
    sudo mkdir -p /usr/share/keyrings
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
      https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
      | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  else
    echo -e "${YELLOW}Brave is already installed or repo exists — skipping key/repo.${NC}"
  fi
  INSTALL_BRAVE=true
else
  echo -e "${YELLOW}Skipping Brave Browser.${NC}"
  INSTALL_BRAVE=false
fi

# ---------------------------------------------------------------------
# 4. Google Chrome
# ---------------------------------------------------------------------
if confirm "🌍 Install Google Chrome (official .deb)?"; then
  echo -e "${GREEN}Installing Google Chrome...${NC}"
  wget -qO /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  INSTALL_CHROME=true
else
  echo -e "${YELLOW}Skipping Google Chrome.${NC}"
  INSTALL_CHROME=false
fi

# ---------------------------------------------------------------------
# 5. Firefox (non-Snap)
# ---------------------------------------------------------------------
if confirm "🦊 Install Firefox (via Mozilla Team PPA, not Snap)?"; then
  echo -e "${GREEN}Installing Firefox...${NC}"
  sudo add-apt-repository -y ppa:mozillateam/ppa
  sudo bash -c 'echo "Package: firefox\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001" > /etc/apt/preferences.d/mozilla-firefox'
  INSTALL_FIREFOX=true
else
  echo -e "${YELLOW}Skipping Firefox.${NC}"
  INSTALL_FIREFOX=false
fi

# ---------------------------------------------------------------------
# Final APT Install
# ---------------------------------------------------------------------
echo -e "${GREEN}📦 Installing selected packages...${NC}"
sudo apt update

$INSTALL_BRAVE && sudo apt install -y brave-browser && add_browser_bookmarks "Brave" "$HOME/.config/BraveSoftware/Brave-Browser/Default/Bookmarks" || true
$INSTALL_CODE && sudo apt install -y code || true
$INSTALL_CHROME && sudo apt install -y /tmp/google-chrome.deb && add_browser_bookmarks "Chrome" "$HOME/.config/google-chrome/Default/Bookmarks" || true
$INSTALL_FIREFOX && sudo apt install -y firefox || true

echo -e "${GREEN}✅ All selected tools installed!${NC}"
