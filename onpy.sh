#!/bin/bash
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${PURPLE}"
cat << "EOF"
             ___  _ __  _ __  _   _
            / _ \| '_ \| '_ \| | | |
           | (_) | | | | |_) | |_| |
            \___/|_| |_| .__/ \__, |
                       |_|    |___/
                    
          Onpy - Auto PyInstaller to .deb
EOF
echo -e "${CYAN}      Developed by Lasith Ruwantha Amarawasha${NC}\n"

# Check PyInstaller
if ! command -v pyinstaller &> /dev/null; then
    echo -e "${RED}[X] PyInstaller missing – installing...${NC}"
    sudo apt update && sudo apt install -y pyinstaller
fi

# Inputs tika
echo -e "${YELLOW}Python script (e.g. hello.py):${NC}"
read -p "   > " SCRIPT
[[ -f "$SCRIPT" ]] || { echo -e "${RED}[X] File not found!${NC}"; exit 1; }

NAME=$(basename "$SCRIPT" .py)
VERSION="1.0"
#=====================
MACHINE=$(uname -m)
case "$MACHINE" in
    aarch64|arm64) ARCH64="aarch64"; ARCH32="armhf" ;;
    armv8l|armv7l|armv6l) ARCH64="aarch64"; ARCH32="armhf" ;;
    *) echo -e "${RED}[X] Unsupported arch: $MACHINE${NC}"; exit 1 ;;
esac

# === APP TYPE ===
echo -e "${YELLOW}\nSelect App Type:${NC}"
echo -e "   [01] Terminal App"
echo -e "   [02] GUI App"
echo -e "   [03] Auto Detect (from code)${NC}"
read -p "   > " choice

GUI_MODE=""
TERMINAL="true"
ICON_FLAG=""
case "$choice" in
    1|01) 
        echo -e "${GREEN}[OK] Building as Terminal App${NC}"
        GUI_MODE="--console"
        TERMINAL="true"
        ;;
    2|02) 
        echo -e "${GREEN}[OK] Building as GUI App${NC}"
        GUI_MODE="--windowed"
        TERMINAL="false"
        ;;
    3|03)
        echo -e "${YELLOW}[*] Auto-detecting GUI libraries...${NC}"
        if grep -qiE "(tkinter|PyQt|PySide|kivy|wx|gi\.repository\.Gtk)" "$SCRIPT"; then
            echo -e "${GREEN}[OK] GUI library found → GUI Mode${NC}"
            GUI_MODE="--windowed"
            TERMINAL="false"
        else
            echo -e "${BLUE}[i] No GUI library → Terminal Mode${NC}"
            GUI_MODE="--console"
            TERMINAL="true"
        fi
        ;;
    *) echo -e "${RED}[X] Invalid choice!${NC}"; exit 1 ;;
esac

# Optional icon
if [[ -f "icon.png" ]]; then
    echo -e "${GREEN}[OK] Icon found: icon.png${NC}"
    ICON_FLAG="--icon=icon.png"
else
    echo -e "${BLUE}[i] No icon.png found (optional)${NC}"
fi

# Build  PyInstaller
#Don't kill 
trap '' SIGINT SIGTERM SIGHUP  # Ctrl+C, Ctrl+Z, kill -15 blocked
trap 'echo -e "\n\n\033[0;31m[X] FATAL: Script terminated by system!\033[0m"; exit 1' SIGQUIT
#=================================
echo -e "${GREEN}[OK] Building $NAME ($([[ $TERMINAL == false ]] && echo "GUI" || echo "Terminal"))...${NC}"
pyinstaller --onefile $GUI_MODE $ICON_FLAG --name "$NAME" "$SCRIPT" > /dev/null 2>&1
[[ -f "dist/$NAME" ]] || { echo -e "${RED}[X] PyInstaller failed!${NC}"; exit 1; }

mkdir -p Onpy/64 Onpy/32

# Build .deb package
build_deb() {
    local arch=$1; local dir=$2; local deb=$3
    rm -rf "$dir"
    mkdir -p "$dir/DEBIAN" "$dir/usr/local/bin" "$dir/usr/share/applications" "$dir/usr/share/pixmaps"

    cp "dist/$NAME" "$dir/usr/local/bin/$NAME"
    chmod 755 "$dir/usr/local/bin/$NAME"

    # Copy icon if exists
    [[ -f "icon.png" ]] && cp "icon.png" "$dir/usr/share/pixmaps/$NAME.png"

    # Control files createing
    cat > "$dir/DEBIAN/control" <<EOF
Package: $NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $arch
Maintainer: Lasith Ruwantha Amarawasha <lasith@example.com>
Description: $([[ $TERMINAL == false ]] && echo "GUI" || echo "Terminal") app from $SCRIPT
 Built with Onpy - Cyber Ninjas Studio.
EOF

    # .desktop file
    cat > "$dir/usr/share/applications/$NAME.desktop" <<EOF
[Desktop Entry]
Name=$NAME
Exec=/usr/local/bin/$NAME
Type=Application
Terminal=$TERMINAL
Categories=Utility;Application;
$( [[ -f "icon.png" ]] && echo "Icon=$NAME" )
EOF

    # Permissions
    find "$dir" -type d -exec chmod 755 {} \;
    find "$dir" -type f -exec chmod 644 {} \;
    chmod 755 "$dir/DEBIAN/control" "$dir/usr/local/bin/$NAME"

    # Build .deb
    dpkg-deb --build --root-owner-group "$dir" "$deb" > /dev/null
}

# Build both 64-bit and 32-bit
echo -e "${YELLOW}Building 64-bit ($ARCH64) package...${NC}"
build_deb "$ARCH64" "deb64" "Onpy/64/${NAME}_${VERSION}_${ARCH64}.deb"

echo -e "${YELLOW}Building 32-bit ($ARCH32) package...${NC}"
build_deb "$ARCH32" "deb32" "Onpy/32/${NAME}_${VERSION}_${ARCH32}.deb"

# Cleanup
echo -e "${YELLOW}Cleaning temporary files...${NC}"
rm -rf build dist deb64 deb32 *.spec __pycache__ 2>/dev/null || true

# Final Output
echo -e "\n${GREEN}DONE! Packages created:${NC}"
echo -e "   ${CYAN}64-bit: Onpy/64/${NAME}_${VERSION}_${ARCH64}.deb${NC}"
echo -e "   ${CYAN}32-bit: Onpy/32/${NAME}_${VERSION}_${ARCH32}.deb${NC}\n"

echo -e "${BLUE}Install (choose correct arch):${NC}"
echo -e "   ${YELLOW}sudo dpkg -i Onpy/64/${NAME}_${VERSION}_${ARCH64}.deb${NC}"
echo -e "   ${YELLOW}sudo dpkg -i Onpy/32/${NAME}_${VERSION}_${ARCH32}.deb${NC}\n"

if [[ $TERMINAL == false ]]; then
    echo -e "${GREEN}GUI App: Click from Applications Menu or run: ${YELLOW}$NAME${NC}"
else
    echo -e "${GREEN}Terminal App: Run in terminal: ${YELLOW}$NAME${NC}"
fi

echo -e "\n${PURPLE}Onpy By ${RED}𝘾𝙔𝘽𝙀𝙍 𝙉𝙄𝙅𝘼𝙎 𝙎𝙏𝙐𝘿𝙄𝙊${NC}"