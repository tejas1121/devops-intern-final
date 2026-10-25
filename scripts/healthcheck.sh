#!/usr/bin/env bash
# healthcheck.sh - verify the running application answers with HTTP 200.
# Usage: scripts/healthcheck.sh [URL]    (default: http://localhost:8080)
# Exit codes: 0 = healthy, 1 = unhealthy response, 2 = usage / missing dependency.
set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [URL]" >&2
    exit 2
fi

url="${1:-http://localhost:8080}"

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required but not installed" >&2
    exit 2
fi

# curl prints 000 as the status when it cannot connect; '|| true' keeps set -e from
# aborting so we can report a clear diagnostic instead.
status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 "$url" || true)"

if [[ "$status" == "200" ]]; then
    echo "OK: $url returned HTTP 200"
    exit 0
fi

echo "FAIL: $url returned HTTP ${status:-000} (expected 200)" >&2
exit 1
