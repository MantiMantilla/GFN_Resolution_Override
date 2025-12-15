#!/bin/bash
# install_mitm_certs.sh

#!/bin/bash
# install_mitm_certs.sh
# Ensure mitmproxy CA exists (generate if needed) and install it system-wide and into NSS.

# Where the script lives (used to find helper kill script if present)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Potential certificate file locations (mitmproxy historically uses one of these names)
CERT1="$HOME/.mitmproxy/mitmproxy-ca.pem"
CERT2="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
CERT_PATH=""
SYS_CERT_DIR="/etc/pki/ca-trust/source/anchors/"
SYS_INSTALLED="false"
SYS_CERT_INSTALLED_PATH=""

# If neither cert exists, try to generate them by running mitmdump briefly.
if [ -f "$CERT1" ]; then
	CERT_PATH="$CERT1"
elif [ -f "$CERT2" ]; then
	CERT_PATH="$CERT2"
else
	echo "mitmproxy certificate not found. Attempting to generate by running mitmdump briefly..."
	if command -v mitmdump >/dev/null 2>&1; then
		if [ -f "$SCRIPT_DIR/kill_mitmproxy.py" ]; then
			mitmdump --no-server -s "$SCRIPT_DIR/kill_mitmproxy.py" >/dev/null 2>&1 || true
		else
			# Start mitmdump in background, wait briefly, then kill it to avoid leaving it running
			mitmdump --no-server >/dev/null 2>&1 &
			MD_PID=$!
			sleep 1
			kill "$MD_PID" >/dev/null 2>&1 || true
			wait "$MD_PID" 2>/dev/null || true
		fi
		# Give mitmproxy a moment to write certs
		sleep 1
		if [ -f "$CERT1" ]; then
			CERT_PATH="$CERT1"
		elif [ -f "$CERT2" ]; then
			CERT_PATH="$CERT2"
		fi
	else
		echo "mitmdump not available; cannot auto-generate mitmproxy certificates."
	fi
fi

if [ -z "$CERT_PATH" ]; then
	echo "Error: mitmproxy certificate not found. Cannot install."
	exit 1
fi

echo "Installing certificate from $CERT_PATH..."

# 1. System-wide Installation
# Prefer Fedora-style `update-ca-trust`, fall back to Debian/Ubuntu `update-ca-certificates`.
if command -v update-ca-trust >/dev/null 2>&1; then
	echo "Attempting system-wide installation using update-ca-trust (requires sudo)..."
	sudo cp "$CERT_PATH" "$SYS_CERT_DIR"
	sudo update-ca-trust
	SYS_INSTALLED="true"
	SYS_CERT_INSTALLED_PATH="$SYS_CERT_DIR/$(basename "$CERT_PATH")"
	echo "System-wide installation finished (update-ca-trust)."
elif command -v update-ca-certificates >/dev/null 2>&1; then
	echo "Attempting system-wide installation using update-ca-certificates (Debian/Ubuntu; requires sudo)..."
	sudo cp "$CERT_PATH" "/usr/local/share/ca-certificates/mitmproxy-ca.crt"
	sudo update-ca-certificates
	SYS_INSTALLED="true"
	SYS_CERT_INSTALLED_PATH="/usr/local/share/ca-certificates/mitmproxy-ca.crt"
	echo "System-wide installation finished (update-ca-certificates)."
else
	echo "No supported system CA update command found (skipping system-wide install)."
fi

# 2. Chromium/NSS Database Installation
# Chromium uses the NSS database for its certificate store.
# This assumes the default profile path and requires 'certutil'.
# Bypassed if already installed system-wide.

NSS_DB_PATH=~/.pki/nssdb
if [ ! -d "$NSS_DB_PATH" ]; then
    echo "NSS database not found at $NSS_DB_PATH. Creating directory..."
    mkdir -p "$NSS_DB_PATH"
fi
# If system-wide install did not run (or failed), attempt to add cert to Chromium's NSS DB
if [ "$SYS_INSTALLED" != "true" ]; then
	if command -v certutil &> /dev/null; then
	    echo "Attempting to install into NSS database at $NSS_DB_PATH..."
	    # C: Trust for authenticating SSL clients
	    # T: Trust for authenticating SSL servers
	    # P: Trust for signing code
	    certutil -A -n "mitmproxy CA" -t "CT,," -i "$CERT_PATH" -d "sql:$NSS_DB_PATH"
	    if [ $? -eq 0 ]; then
		echo "Certificate successfully added to NSS database."
	    else
		echo "Warning: 'certutil' failed to add certificate (it may already be present)."
	    fi
	else
	    echo "Skipping NSS database install: 'certutil' not found. Install 'libnss3-tools'."
	fi

