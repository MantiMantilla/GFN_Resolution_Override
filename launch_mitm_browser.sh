#!/bin/bash

# Configuration
MITMPROXY_PORT=8080
PROXY_PAC_FILE="./find_proxy.pac"
MITM_SCRIPT="./resolution-interceptor.py"
CERT_INSTALLER_SCRIPT="./install_mitm_certs.sh"

# --- 1. Certificate Check and Installation ---
echo "Checking and installing mitmproxy certificates..."
if [ ! -f ~/.mitmproxy/mitmproxy-ca.pem ]; then
    echo "mitmproxy certificate not found. Generating a new one..."
    # Running mitmproxy once forces it to generate the default certs
    mitmproxy --version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: mitmproxy command not found or failed to generate certificates."
        exit 1
    fi
fi

# Attempt to install system/Chromium-specific certificates
# The actual installation logic is complex and separated into a helper script
if [ -f "$CERT_INSTALLER_SCRIPT" ]; then
    bash "$CERT_INSTALLER_SCRIPT"
else
    echo "Warning: Certificate installation helper script ($CERT_INSTALLER_SCRIPT) not found. Skipping auto-install."
    echo "Ensure 'mitmproxy-ca-cert.pem' is installed in your system's trust store or Chromium's NSS database."
fi

# --- 2. Base64 Encode the Proxy PAC File ---
if [ ! -f "$PROXY_PAC_FILE" ]; then
    echo "Error: Proxy PAC file not found at $PROXY_PAC_FILE"
    exit 1
fi

PAC_B64=$(base64 -w0 "$PROXY_PAC_FILE")
PROXY_PAC_URL="data:application/x-javascript-config;base64,$PAC_B64"

# --- 3. Launch mitmproxy in the Background ---
echo "Starting mitmproxy server..."
# Use 'exec' to ensure the output is redirected cleanly
mitmproxy -p $MITMPROXY_PORT -s "$MITM_SCRIPT" &
MITM_PID=$!
echo "mitmproxy started with PID: $MITM_PID"

# A brief pause to ensure the proxy server is listening before the browser connects
sleep 2

# --- 4. Launch Chromium and Monitor ---
echo "Launching Chromium browser..."
chromium-browser \
    --enable-features=VaapiVideoDecodeLinuxGL \
    --ozone-platform=wayland \
    --proxy-pac-url="$PROXY_PAC_URL" \
CHROMIUM_EXIT_CODE=$?

# --- 5. Cleanup (Shutdown mitmproxy) ---
echo "Chromium closed (Exit Code: $CHROMIUM_EXIT_CODE). Shutting down mitmproxy (PID: $MITM_PID)..."
kill $MITM_PID

# Wait a moment for the process to terminate gracefully
wait $MITM_PID 2>/dev/null

echo "Cleanup complete."
exit $CHROMIUM_EXIT_CODE
