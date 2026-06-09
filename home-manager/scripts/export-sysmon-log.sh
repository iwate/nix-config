#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE=${1:-"$PWD/logs/sysmon.log"}
STATE_FILE=${2:-""}
UNTIL_TIME=${3:-""}

OUTPUT_FILE=$(readlink -m "$OUTPUT_FILE")
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

mkdir -p "$OUTPUT_DIR"

explain_unwritable_path() {
  local path="$1"
  local owner="unknown"

  if command -v stat >/dev/null 2>&1; then
    owner=$(stat -c '%U:%G (%u:%g)' "$path" 2>/dev/null || echo "unknown")
  fi

  echo "Path is not writable as the current user: $path" >&2
  echo "Current user: $(id -un):$(id -gn); path owner: $owner" >&2
  echo "If this was created by sudo earlier, fix it with: sudo chown -R $(id -un):$(id -gn) '$path'" >&2
}

if [[ -e "$OUTPUT_FILE" ]]; then
  if [[ ! -w "$OUTPUT_FILE" ]]; then
    explain_unwritable_path "$OUTPUT_FILE"
    exit 1
  fi
elif [[ ! -w "$OUTPUT_DIR" ]]; then
  explain_unwritable_path "$OUTPUT_DIR"
  exit 1
fi

if [[ -n "$STATE_FILE" ]]; then
  STATE_FILE=$(readlink -m "$STATE_FILE")
  STATE_DIR=$(dirname "$STATE_FILE")
  mkdir -p "$STATE_DIR"

  if [[ -e "$STATE_FILE" ]]; then
    if [[ ! -w "$STATE_FILE" ]]; then
      explain_unwritable_path "$STATE_FILE"
      exit 1
    fi
  elif [[ ! -w "$STATE_DIR" ]]; then
    explain_unwritable_path "$STATE_DIR"
    exit 1
  fi
fi

SINCE_TIME=""
if [[ -n "$STATE_FILE" && -s "$STATE_FILE" ]]; then
  SINCE_TIME=$(head -n 1 "$STATE_FILE" | tr -d '\r')
fi

if command -v journalctl >/dev/null 2>&1; then
  # Sysmon events are typically tagged as sysmon in journald/syslog.
  JOURNAL_ARGS=( -t sysmon --no-pager -o short-iso )
  if [[ -n "$SINCE_TIME" ]]; then
    JOURNAL_ARGS+=( --since "$SINCE_TIME" )
  fi
  if [[ -n "$UNTIL_TIME" ]]; then
    JOURNAL_ARGS+=( --until "$UNTIL_TIME" )
  fi

  if ! journalctl "${JOURNAL_ARGS[@]}" > "$OUTPUT_FILE"; then
    echo "Failed to read Sysmon events from journalctl as current user." >&2
    echo "Grant journal read access (for example via wheel/systemd-journal) or adjust service user." >&2
    exit 1
  fi
else
  if [[ ! -f /var/log/syslog ]]; then
    echo "journalctl and /var/log/syslog are unavailable on this host." >&2
    exit 1
  fi
  if ! grep "sysmon" /var/log/syslog > "$OUTPUT_FILE"; then
    echo "Failed to read /var/log/syslog as current user." >&2
    exit 1
  fi
fi

echo "Exported Sysmon log to: $OUTPUT_FILE"
if [[ -n "$SINCE_TIME" ]]; then
  echo "Export range starts from: $SINCE_TIME"
fi
if [[ -n "$UNTIL_TIME" ]]; then
  echo "Export range ends at: $UNTIL_TIME"
fi
