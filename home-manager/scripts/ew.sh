#!/usr/bin/env bash

set -euo pipefail

mapfile -t containers < <(podman ps \
  --filter ancestor=localhost/wrap \
  --format '{{.ID}} {{.Names}} ({{.Image}})')

if ((${#containers[@]} == 0)); then
  printf 'No running localhost/wrap containers found.\n' >&2
  exit 1
fi

selection=$(printf '%s\n' "${containers[@]}" | fzf --prompt='wrap> ' --height=40% --reverse) || exit
container_id=${selection%% *}

exec podman exec -it "$container_id" /bin/bash