#!/bin/sh

set -eu

profile="/nix/var/nix/profiles/system"

# Keep only the newest generation to avoid filling tiny EFI partitions.
old_generations="$({
	sudo nix-env --list-generations -p "$profile" \
		| awk '/^[[:space:]]*[0-9]+/ { print $1 }' \
		| head -n -1
} || true)"

if [ -n "$old_generations" ]; then
	# shellcheck disable=SC2086
	sudo nix-env --delete-generations $old_generations -p "$profile"
fi

# Collect garbage without --delete-old, so kept generations remain.
sudo nix-collect-garbage

# Remove stale temporary EFI files left by failed systemd-boot copies.
sudo sh -c 'rm -f /boot/EFI/nixos/*.tmp'

sudo nixos-rebuild boot --flake .#laptop