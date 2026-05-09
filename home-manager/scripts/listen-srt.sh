#!/usr/bin/env bash

set -euo pipefail

PORT="${1:-5000}"
VIDEO_DEVICE="${2:-/dev/video10}"
LATENCY_MS="${SRT_LATENCY_MS:-50}"
FFMPEG_LOGLEVEL="${FFMPEG_LOGLEVEL:-warning}"

usage() {
	cat <<EOF
Usage:
	$(basename "$0") [port] [video_device]

Examples:
	$(basename "$0")
	$(basename "$0") 5000 /dev/video10

Environment variables:
	SRT_LATENCY_MS  SRT latency in milliseconds (default: 50)
	FFMPEG_LOGLEVEL ffmpeg loglevel (default: warning)

Notes:
	- This script expects a v4l2loopback virtual camera device.
	- Example setup:
			sudo modprobe v4l2loopback video_nr=10 card_label="SRT Virtual Cam" exclusive_caps=1
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
	echo "Error: ffmpeg is not installed." >&2
	exit 1
fi

if [[ ! -e "$VIDEO_DEVICE" ]]; then
	echo "Error: video device '$VIDEO_DEVICE' does not exist." >&2
	echo "Hint: load v4l2loopback first, for example:" >&2
	echo "  sudo modprobe v4l2loopback video_nr=10 card_label=\"SRT Virtual Cam\" exclusive_caps=1" >&2
	exit 1
fi

if [[ ! -w "$VIDEO_DEVICE" ]]; then
	echo "Error: video device '$VIDEO_DEVICE' is not writable by current user." >&2
	echo "Hint: run with proper permissions or adjust udev/group settings." >&2
	exit 1
fi

SRT_URL="srt://0.0.0.0:${PORT}?mode=listener&latency=${LATENCY_MS}&transtype=live"

echo "Listening for SRT on udp/${PORT}..."
echo "Input : ${SRT_URL}"
echo "Output: ${VIDEO_DEVICE} (v4l2loopback)"

exec ffmpeg \
	-loglevel "$FFMPEG_LOGLEVEL" \
	-fflags nobuffer+discardcorrupt \
    -flags low_delay \
	-probesize 32 \
	-analyzeduration 0 \
    -ec 1 \
	-hwaccel vaapi \
	-f mpegts \
	-i "$SRT_URL" \
	-an \
	-vcodec rawvideo \
	-pix_fmt yuv420p \
	-f v4l2 \
	-r 24 \
	"$VIDEO_DEVICE"
