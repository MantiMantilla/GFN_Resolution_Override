import json
import re
from mitmproxy import http

url_pattern = re.compile(r"^.*\.nvidiagrid.net/v2/session")
user_agent_pattern = re.compile(r"(Mozilla\/[\d\.]+) \(.+?\)")

def request(flow: http.HTTPFlow) -> None:
    # Check if the request matches the regex pattern
    if url_pattern.match(flow.request.pretty_url):

        flow.request.headers['nv-device-os'] = 'WINDOWS'
        flow.request.headers['sec-ch-ua-platform'] = '"WINDOWS"'
        flow.request.headers['sec-ch-ua-platform-version'] = '14.0.0'

        if "user-agent" in flow.request.headers:
            flow.request.headers["user-agent"] = user_agent_pattern.sub(
                    r'\1 (Windows NT 10.0; Win64; x64)',
                    flow.request.headers["user-agent"])

        if flow.request.headers.get("content-type") == "application/json":
            try:
                body = json.loads(flow.request.content)
                if body.get("sessionRequestData", {}).get("clientRequestMonitorSettings", None) is not None:
                    body["sessionRequestData"]["clientRequestMonitorSettings"] = [
                        {
                            "heightInPixels": 1440,
                            "framesPerSecond": 120,
                            "widthInPixels": 2560
                        }
                    ]
                flow.request.content = json.dumps(body).encode("utf-8")
            except json.JSONDecodeError:
                pass

