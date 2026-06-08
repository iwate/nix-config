#!/usr/bin/env bash
set -euo pipefail

if ! command -v podman >/dev/null 2>&1; then
  echo "podman command not found. Enable podman or install it first." >&2
  exit 1
fi

if [[ $# -lt 2 ]]; then
  cat <<'USAGE' >&2
Usage:
  run-zircolite-podman.sh <events_file_or_dir> <ruleset_file_or_dir> [output_json]

Examples:
  run-zircolite-podman.sh ./logs/sysmon.log ./sigma/linux
  run-zircolite-podman.sh ./logs ./sigma/rules.yml ./output/detected_events.json
USAGE
  exit 1
fi

EVENTS_PATH=$(readlink -f "$1")
RULESET_PATH=$(readlink -f "$2")
OUTPUT_FILE=${3:-"$PWD/zircolite-output/detected_events.json"}
OUTPUT_FILE=$(readlink -m "$OUTPUT_FILE")

if [[ ! -e "$EVENTS_PATH" ]]; then
  echo "events path not found: $EVENTS_PATH" >&2
  exit 1
fi

if [[ ! -e "$RULESET_PATH" ]]; then
  echo "ruleset path not found: $RULESET_PATH" >&2
  exit 1
fi

EVENTS_DIR=$(dirname "$EVENTS_PATH")
RULESET_DIR=$(dirname "$RULESET_PATH")
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
OUTPUT_NAME=$(basename "$OUTPUT_FILE")

mkdir -p "$OUTPUT_DIR"

podman run --rm --tty \
  -v "$EVENTS_DIR:/case/events:ro" \
  -v "$RULESET_DIR:/case/rules:ro" \
  -v "$OUTPUT_DIR:/case/output:Z,U" \
  docker.io/wagga40/zircolite:latest \
  --events "/case/events/$(basename "$EVENTS_PATH")" \
  --ruleset "/case/rules/$(basename "$RULESET_PATH")" \
  --sysmon4linux \
  --outfile "/case/output/$OUTPUT_NAME"

echo "Detection result: $OUTPUT_FILE"
