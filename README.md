# 🚀 GFN Resolution Override

A proxy-based solution using `mitmproxy` to intercept and modify streaming session requests to NVIDIA's services, forcing a specific resolution and frame rate (1440p @ 120 FPS).

Based on the excellent work by [a9udn9u](https://github.com/a9udn9u). See [this thread](https://www.reddit.com/r/linux_gaming/comments/1fn973k/geforce_now_at_1440p_and_120_fps_in_linux_chrome/).

## ⚠️ Disclaimers

This tool modifies network requests to a third-party service. Use it at your own risk and ensure compliance with the service provider's terms.

This code was written with help from AI.

-----

## 🛠️ Prerequisites

  * **GeForce NOW Ultimate**
  * **`mitmproxy`**: The core proxy engine.

    ```bash
    pip install mitmproxy
    ```
  * **`chromium-browser`**: Only chromium-based browsers are supported by GeForce Now.
  * **Networking Tools**: `base64` and standard shell utilities (`kill`, `wait`, `sleep`).
  * **Certificate Tools**: `certutil` (for NSS database installation, usually in the `libnss3-tools` package on Debian/Ubuntu).

-----

## 📁 Project Structure

| Filename | Description |
| :--- | :--- |
| `install.sh` | Installer that attempts to install dependencies, generates and installs the mitmproxy CA, makes helpers executable, and installs the desktop launcher. |
| `launch_mitm_browser.sh` | Launcher script that starts `mitmdump`, opens Chromium pointed at the PAC file, and shuts down the proxy when Chromium exits. |
| `install_mitm_certs.sh` | Helper that generates the mitmproxy CA (if missing) and installs it system-wide and into Chromium's NSS database. |
| `gfn-mitm-chromium.desktop` | Desktop launcher template used by `install.sh` (installed to `~/.local/share/applications`). |
| `resolution-interceptor.py` | The `mitmproxy` script containing the modification logic. |
| `find_proxy.pac` | The Proxy Auto-Configuration script, which directs only NVIDIA traffic to the proxy. |
| `kill_mitmproxy.py` | Optional helper used during certificate generation to start and immediately stop mitmproxy cleanly. |

-----

## 💻 Setup and Execution

### 1. Clone the repository

If you haven't already, clone the repo:

```sh
git clone https://github.com/MantiMantilla/GFN_Resolution_Override
cd GFN_Resolution_Override
```

### 2. Run the installer

The repository includes an installer script that:

- attempts to install common dependencies when a supported package manager is detected (`mitmproxy`, `chromium`, `libnss3-tools` / `certutil`),
- generates the `mitmproxy` CA if missing,
- installs the CA into the system trust store and Chromium's NSS database,
- makes helper scripts executable, and
- installs a desktop launcher (`GeForce Now (mitmproxy)`) from the repository template.

Run the installer (you may be prompted for your password for package installation and system certificate steps):

```sh
chmod +x ./install.sh
./install.sh
```

If the desktop launcher is installed, you can launch from your desktop menu as **GeForce Now (mitmproxy)**. The installer places the desktop file at `~/.local/share/applications/gfn-mitm-chromium.desktop`.

### 3. Launch manually (optional)

If you prefer to run the launcher script directly (for example, during development), run:

```sh
./launch_mitm_browser.sh
```

Note: `launch_mitm_browser.sh` assumes the `mitmproxy` CA has already been generated and trusted (the installer performs this). It will start `mitmdump`, open Chromium pointed at the PAC URL, and shut down `mitmdump` when Chromium exits.

### 4. Closing

When the Chromium window launched by the script is closed, `launch_mitm_browser.sh` will cleanly stop the background `mitmdump` process it started.

-----

## 💡 How it Works

The project leverages a few key networking techniques .

### 1\. `find_proxy.pac` (Proxy Auto-Configuration)

This script is passed to Chromium using a data URI (`--proxy-pac-url`).

  * It inspects every network request initiated by the browser.
  * If the destination host is `*nvidiagrid.net*`, the request is routed to the local proxy server (`PROXY 127.0.0.1:8080`).
  * All other traffic goes `DIRECT`, preventing irrelevant sites from being intercepted.

### 2\. `mitmproxy` and Certificate Installation

Since the connection to NVIDIA is secure (HTTPS), `mitmproxy` acts as a **Man-in-the-Middle** (MITM) to decrypt the traffic.

  * The proxy dynamically generates a fake certificate for the NVIDIA domain.
  * For this to work without certificate errors, the root **`mitmproxy` CA certificate** must be trusted by the browser (Chromium).
  * The `install_mitm_certs.sh` script attempts to install this CA certificate into your system's trust store and the NSS database used by Chromium, allowing it to trust the connection.

### 3\. `resolution-interceptor.py` (The Core Logic)

This Python script executes for every intercepted request:

  * **URL Filter:** It targets requests to the session endpoint (`...nvidiagrid.net/v2/session`).
  * **Header Spoofing:** It overwrites several HTTP headers (`nv-device-os`, `sec-ch-ua-platform`, `user-agent`) to make the client appear as a **Windows 10/11** device. This is often necessary to unlock higher-tier settings on the server side.
  * **JSON Payload Modification:**
      * It checks if the request body is JSON.
      * It attempts to find the `sessionRequestData` structure.
      * It then **overwrites** the `clientRequestMonitorSettings` array to explicitly request **2560x1440 @ 120 FPS**.
      * The modified JSON is then sent to the NVIDIA server.

-----

## Troubleshooting

### Certificate Errors

If the Chromium instance still shows certificate warnings (e.g., "NET::ERR\_CERT\_AUTHORITY\_INVALID"):

  * The CA certificate was likely **not installed correctly** in the NSS database.
  * Ensure `certutil` is installed (`sudo apt install libnss3-tools`).
  * Manually navigate to the NVIDIA service website once, check the padlock icon for the error details, and try manually importing the `~/.mitmproxy/mitmproxy-ca-cert.pem` file into the browser's certificate manager.

### No Resolution Change

If the stream starts but the resolution is still low:

  * Check the `mitmproxy` console output (which will be visible in your terminal before Chromium launches) to ensure the script is running without errors.
  * Verify that the targeted JSON structure (`sessionRequestData.clientRequestMonitorSettings`) is actually present in the request body when you start a session. The API structure may have changed.
