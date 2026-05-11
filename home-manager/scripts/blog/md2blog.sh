#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <markdown-file>" >&2
  exit 1
fi

input_file="$1"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
input_dir="$(cd -- "$(dirname -- "$input_file")" && pwd)"
tmp_dir="${TMPDIR:-/tmp}"

deno run \
  -E=NO_COLOR,FORCE_COLOR,TERM \
  -R="$input_file,$input_dir/attachments,$tmp_dir" \
  -W="/home/iwate/works/blog,$tmp_dir" \
  "$script_dir/md2blog.ts" \
  "$input_file"
