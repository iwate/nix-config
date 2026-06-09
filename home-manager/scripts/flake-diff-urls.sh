#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git -C "$(dirname "$(realpath "$0")")" rev-parse --show-toplevel)
LOCK_FILE="$REPO_ROOT/flake.lock"

PREV=$(git -C "$REPO_ROOT" show HEAD:flake.lock 2>/dev/null) || {
  echo "Could not get previous flake.lock from git HEAD" >&2
  exit 1
}
CURR=$(cat "$LOCK_FILE")

jq -rn \
  --argjson prev "$PREV" \
  --argjson curr "$CURR" \
  '
  $curr.nodes | to_entries[] |
  select(.value.locked.type == "github") |
  .key as $k |
  .value.locked as $cl |
  ($prev.nodes[$k].locked.rev // null) as $pr |
  select($pr != null and $pr != $cl.rev) |
  "https://github.com/\($cl.owner)/\($cl.repo)/compare/\($pr)...\($cl.rev)"
  '
