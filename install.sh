#!/bin/sh
set -e
# install.sh
# Installs dependencies (when possible), installs mitmproxy certs, makes helper scripts executable,
# and creates a desktop launcher that runs `launch_mitm_browser.sh`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_SCRIPT="$SCRIPT_DIR/launch_mitm_browser.sh"
CERT_INSTALLER="$SCRIPT_DIR/install_mitm_certs.sh"
DESKTOP_FILE_NAME="gfn-mitm-chromium.desktop"
DESKTOP_FILE_DIR="$HOME/.local/share/applications"
DESKTOP_FILE_PATH="$DESKTOP_FILE_DIR/$DESKTOP_FILE_NAME"

echo "== GFN Resolution Override installer =="

echo "Detecting package manager..."
PM=""
if command -v apt-get >/dev/null 2>&1; then
    PM=apt
elif command -v dnf >/dev/null 2>&1; then
    PM=dnf
elif command -v pacman >/dev/null 2>&1; then
    PM=pacman
elif command -v zypper >/dev/null 2>&1; then
    PM=zypper
else
    PM=unknown
fi

echo "Package manager: $PM"

case "$PM" in
    apt)
        echo "Installing packages with apt (may ask for sudo)..."
        sudo apt-get update
        sudo apt-get install -y mitmproxy chromium-browser libnss3-tools ca-certificates || true
        ;;
    dnf)
        echo "Installing packages with dnf (may ask for sudo)..."
        sudo dnf install -y mitmproxy chromium libnss3-tools ca-certificates || true
        ;;
    pacman)
        echo "Installing packages with pacman (may ask for sudo)..."
        sudo pacman -Sy --noconfirm mitmproxy chromium nss || true
        ;;
    zypper)
        echo "Installing packages with zypper (may ask for sudo)..."
        sudo zypper install -y mitmproxy chromium libnss3-tools ca-certificates || true
        ;;
    *)
        echo "No supported package manager found. Please ensure the following are installed:"
        echo "  - mitmproxy"
        echo "  - chromium"
        echo "  - libnss3-tools (for certutil)"
        echo "Proceeding without automated package installation."
        ;;
esac

echo "Ensuring helper scripts are executable..."
if [ -f "$LAUNCH_SCRIPT" ]; then
    chmod +x "$LAUNCH_SCRIPT" || true
else
    echo "Warning: $LAUNCH_SCRIPT not found in repo." >&2
fi

if [ -f "$CERT_INSTALLER" ]; then
    chmod +x "$CERT_INSTALLER" || true
else
    echo "Warning: $CERT_INSTALLER not found in repo." >&2
fi

echo "Generating mitmproxy certificate if missing..."
if [ ! -f "$HOME/.mitmproxy/mitmproxy-ca.pem" ]; then
    if command -v mitmdump >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/kill_mitmproxy.py" ]; then
        echo "Running mitmdump briefly to generate default certs..."
        mitmdump --no-server -s "$SCRIPT_DIR/kill_mitmproxy.py" >/dev/null 2>&1 || true
    else
        echo "mitmdump not available or kill script missing; skip automatic certificate generation." >&2
    fi
fi

echo "Installing mitmproxy certificates with helper script (may ask for sudo)..."
if [ -x "$CERT_INSTALLER" ]; then
    bash "$CERT_INSTALLER" || true
else
    echo "Certificate installer missing or not executable; skipping." >&2
fi

TEMPLATE_PATH="$SCRIPT_DIR/gfn-mitm-chromium.desktop"
ABS_LAUNCH="${LAUNCH_SCRIPT}"

echo "Installing desktop launcher to $DESKTOP_FILE_PATH"
if [ -f "$TEMPLATE_PATH" ]; then
    mkdir -p "$DESKTOP_FILE_DIR"
    # Replace placeholder with absolute path to launcher
    sed "s|__LAUNCHER_PATH__|$ABS_LAUNCH|g" "$TEMPLATE_PATH" > "$DESKTOP_FILE_PATH"
    chmod +x "$DESKTOP_FILE_PATH" || true
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_FILE_DIR" >/dev/null 2>&1 || true
    fi
else
    echo "Desktop template $TEMPLATE_PATH not found; skipping desktop launcher installation."
    echo "Create the template at $TEMPLATE_PATH (with Exec=__LAUNCHER_PATH__) and re-run this installer to install the desktop entry."
fi

echo "Installation complete."
echo "You can launch from your desktop menu: 'GeForce Now (mitmproxy)'."
echo "Or run: $ABS_LAUNCH"

exit 0
