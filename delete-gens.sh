#!/bin/sh

set -eu

profile="/nix/var/nix/profiles/system"

# Keep newest 3 generations and delete older ones.
old_generations="$({
	sudo nix-env --list-generations -p "$profile" \
		| awk '/^[[:space:]]*[0-9]+/ { print $1 }' \
		| head -n -3
} || true)"

if [ -n "$old_generations" ]; then
	# shellcheck disable=SC2086
	sudo nix-env --delete-generations $old_generations -p "$profile"
fi

# Collect garbage without --delete-old, so kept generations remain.
sudo nix-collect-garbage
sudo nixos-rebuild boot --flake .#laptop