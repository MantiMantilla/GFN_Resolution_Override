function FindProxyForURL(url, host) {

  if (host.includes("nvidiagrid.net")) {
    return "PROXY 127.0.0.1:8080";
  }

  return "DIRECT";
}
