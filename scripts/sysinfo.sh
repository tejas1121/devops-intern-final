#!/usr/bin/env bash
# sysinfo.sh - report the host environment: user, host, date, disk, memory, Docker.
# Usage: scripts/sysinfo.sh
set -euo pipefail

section() {
    printf '\n== %s ==\n' "$1"
}

if [[ $# -gt 0 ]]; then
    echo "Usage: $0 (takes no arguments)" >&2
    exit 2
fi

section "User"
echo "User:          $(id -un)"
echo "Effective UID: $(id -u)"

section "Host"
echo "Hostname:       $(uname -n)"
echo "Kernel release: $(uname -sr)"

section "Date (ISO-8601)"
date +"%Y-%m-%dT%H:%M:%S%z"

section "Disk usage"
df -h /

section "Memory usage"
if command -v free >/dev/null 2>&1; then
    free -h
else
    grep -E '^(MemTotal|MemFree|MemAvailable):' /proc/meminfo
fi

section "Docker daemon"
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker: not installed"
elif docker info >/dev/null 2>&1; then
    echo "Docker: running (server version $(docker info --format '{{.ServerVersion}}'))"
else
    echo "Docker: installed, but the daemon is not reachable"
fi
