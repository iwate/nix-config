#!/bin/sh

sudo nix-env --delete-generations +10 -p /nix/var/nix/profiles/system
sudo nix-collect-garbage -d
sudo nixos-rebuild boot --flake .#laptop