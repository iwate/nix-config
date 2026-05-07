#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE=${1:-"$PWD/logs/sysmon.log"}
OUTPUT_FILE=$(readlink -m "$OUTPUT_FILE")
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

mkdir -p "$OUTPUT_DIR"

if command -v journalctl >/dev/null 2>&1; then
  # Sysmon events are typically tagged as sysmon in journald/syslog.
  sudo journalctl -t sysmon --no-pager -o short-iso > "$OUTPUT_FILE"
else
  if [[ ! -f /var/log/syslog ]]; then
    echo "journalctl and /var/log/syslog are unavailable on this host." >&2
    exit 1
  fi
  sudo grep "sysmon" /var/log/syslog > "$OUTPUT_FILE"
fi

echo "Exported Sysmon log to: $OUTPUT_FILE"
