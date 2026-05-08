#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

notify_update() {
  local title="システム更新"
  local message="新しいアップデートが利用可能です。"

  if command -v notify-send >/dev/null 2>&1; then
    if notify-send -u critical -i software-update-available "$title" "$message"; then
      return 0
    fi
    echo "[check-updates] Desktop notification delivery failed." >&2
  fi

  if command -v systemd-cat >/dev/null 2>&1; then
    printf '%s\n' "$message" | systemd-cat -t check-updates -p warning
  elif command -v logger >/dev/null 2>&1; then
    logger -t check-updates "$message"
  fi
}

cd "$REPO_DIR"
nix flake update nixpkgs

if git diff --quiet -- flake.lock; then
  exit 0
fi

notify_update
