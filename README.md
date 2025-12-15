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
| `launch_mitm_browser.sh` | The main executable script to set up, run, and clean up the environment. |
| `install_mitm_certs.sh` | Helper script for system/Chromium certificate installation. |
| `resolution-interceptor.py` | The `mitmproxy` script containing the modification logic. |
| `find_proxy.pac` | The Proxy Auto-Configuration script, which directs only NVIDIA traffic to the proxy. |

-----

## 💻 Setup and Execution

### 1\. Get the scripts

Ensure you have saved the four required files.

```bash
git clone https://github.com/MantiMantilla/GFN_Resolution_Override
```

### 2\. Make the Scripts Executable

```bash
chmod +x launch_mitm_browser.sh install_mitm_certs.sh
```

### 3\. Run the Launcher

Execute the main script. It will handle the entire process:

1.  Generate/check for `mitmproxy` certificates.
2.  Attempt to install the certificates system-wide and into the Chromium/NSS database (requires `sudo` for system installation).
3.  Launch `mitmproxy` in the background.
4.  Launch `chromium-browser`, configured to use the PAC file to proxy NVIDIA traffic.


```bash
./launch_mitm_browser.sh
```

### 4\. Close the Session

When you close the launched `chromium-browser` instance, the `launch_mitm_browser.sh` script will automatically detect the closure and **shut down the background `mitmproxy` server**.

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
