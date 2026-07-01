#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SCRIPT="$REPO_DIR/home-manager/scripts/export-sysmon-log.sh"
ZIRCOLITE_SCRIPT="$REPO_DIR/home-manager/scripts/run-zircolite-podman.sh"
RULESET_FILE="$REPO_DIR/security-rules/rules_linux.json"

AUDIT_DIR="$REPO_DIR/logs/audits"
EVENTS_FILE="$AUDIT_DIR/sysmon.log"
RESULT_FILE="$AUDIT_DIR/zircolite-detected-events.json"
LAST_RUN_FILE="$AUDIT_DIR/last-sysmon-audit.timestamp"

notify_critical() {
	local message="$1"
	if command -v notify-send >/dev/null 2>&1; then
		if ! notify-send -u critical "Security audit alert" "$message"; then
			echo "[check-audits] Desktop notification delivery failed." >&2
		fi
	fi
	if command -v systemd-cat >/dev/null 2>&1; then
		printf '%s\n' "$message" | systemd-cat -t check-audits -p err
	elif command -v logger >/dev/null 2>&1; then
		logger -t check-audits "$message"
	fi
	echo "[check-audits] $message" >&2
}

notify_normal() {
	local message="$1"
	if command -v notify-send >/dev/null 2>&1; then
		if ! notify-send -u normal "Security audit" "$message"; then
			echo "[check-audits] Desktop notification delivery failed." >&2
		fi
	fi
	if command -v systemd-cat >/dev/null 2>&1; then
		printf '%s\n' "$message" | systemd-cat -t check-audits -p info
	elif command -v logger >/dev/null 2>&1; then
		logger -t check-audits "$message"
	fi
}

require_file() {
	local path="$1"
	if [[ ! -f "$path" ]]; then
		notify_critical "Required file is missing: $path"
		exit 1
	fi
}

curl 'https://raw.githubusercontent.com/wagga40/Zircolite-Rules-v2/refs/heads/main/rules_linux_medium.json' \
	-o "$RULESET_FILE" \
	--silent --show-error --fail --location --max-time 30

mkdir -p "$AUDIT_DIR"

require_file "$EXPORT_SCRIPT"
require_file "$ZIRCOLITE_SCRIPT"
require_file "$RULESET_FILE"

RUN_STARTED_AT="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

if ! command -v jq >/dev/null 2>&1; then
	notify_critical "jq command is required but was not found in PATH."
	exit 1
fi

if ! "$EXPORT_SCRIPT" "$EVENTS_FILE" "$LAST_RUN_FILE" "$RUN_STARTED_AT"; then
	notify_critical "Failed to export Sysmon log. Check logs/audits ownership/permissions and journalctl access."
	exit 1
fi

if ! "$ZIRCOLITE_SCRIPT" "$EVENTS_FILE" "$RULESET_FILE" "$RESULT_FILE"; then
	notify_critical "Zircolite audit execution failed."
	exit 1
fi

if [[ ! -s "$RESULT_FILE" ]]; then
	notify_critical "Zircolite output file is missing or empty: $RESULT_FILE"
	exit 1
fi

DETECTION_COUNT="$({
	jq -r '
		. as $root |
		if type == "array" then
			length
		elif type == "object" then
			(
				[ $root.events?, $root.detections?, $root.matches?, $root.results?, $root.alerts? ]
				| map(select(type == "array") | length)
				| .[0]
			) // (
				[ $root[]? | select(type == "array") | length ] | add
			) // (if ($root | length) > 0 then 1 else 0 end)
		else
			0
		end
	' "$RESULT_FILE"
} || echo -1)"

if [[ "$DETECTION_COUNT" == "-1" ]]; then
	notify_critical "Could not parse Zircolite output JSON: $RESULT_FILE"
	exit 1
fi

# Persist the completed audit window boundary so next run skips already inspected events.
printf '%s\n' "$RUN_STARTED_AT" > "$LAST_RUN_FILE"

if [[ "$DETECTION_COUNT" -gt 0 ]]; then
	notify_critical "🚨 Detected $DETECTION_COUNT audit hit(s). See $RESULT_FILE"
	exit 2
fi

notify_normal "✅ No audit findings. Output: $RESULT_FILE"
echo "No audit findings. Output: $RESULT_FILE"

