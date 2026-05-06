#!/bin/sh

nix flake update nixpkgs nixpkgs-unstable

if git diff flake.lock | grep -q .; then
  notify-send -u critical -i software-update-available "システム更新" "新しいアップデートが利用可能です。"
fi
