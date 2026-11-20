#!/usr/bin/env bash
#
# Send a file to Telegram with a bot.
#
#   TELEGRAM_BOT_TOKEN  bot token (required)
#   TELEGRAM_CHAT_ID    target chat/channel id (required)
#   TELEGRAM_TOPIC_ID   forum topic id (optional)
#
# usage: telegram.sh <file> [caption]

set -euo pipefail

FILE=${1:?usage: telegram.sh <file> [caption]}

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
	echo "TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID not set, skipping Telegram upload"
	exit 0
fi

# Bot API upload limit
size=$(stat -c %s "$FILE")
if [ "$size" -gt $((50 * 1024 * 1024)) ]; then
	echo "error: $FILE is larger than 50 MB, Telegram bots cannot send it" >&2
	exit 1
fi

KERNEL_DIR=$(cd "$(dirname "$0")/../.." && pwd)
VERSION=$(cat "${DIST:-$KERNEL_DIR/out/dist}/version.txt" 2>/dev/null || true)
SHA256=$(sha256sum "$FILE" | cut -d' ' -f1)

if [ -n "${2:-}" ]; then
	CAPTION=$2
else
	CAPTION="<b>SouthWest-NG</b> for tulip / whyred
<b>Kernel:</b> <code>${VERSION:-unknown}</code>
<b>BakaSU:</b> <code>${BAKASU_REV:-unknown}</code> + SUSFS
<b>Commit:</b> <code>${GITHUB_SHA:0:12}</code> (${GITHUB_REF_NAME:-local})
<b>SHA256:</b> <code>${SHA256}</code>"
	if [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_RUN_ID:-}" ]; then
		CAPTION+="
<a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}\">Build log</a>"
	fi
fi

args=(--form-string "chat_id=$TELEGRAM_CHAT_ID"
	--form-string "parse_mode=HTML"
	--form-string "caption=$CAPTION"
	-F "document=@$FILE")
[ -n "${TELEGRAM_TOPIC_ID:-}" ] && args+=(--form-string "message_thread_id=$TELEGRAM_TOPIC_ID")

resp=$(curl -sS --retry 3 "${args[@]}" \
	"https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument")

if ! grep -q '"ok":true' <<<"$resp"; then
	echo "error: Telegram upload failed: $resp" >&2
	exit 1
fi
echo "Sent $FILE to Telegram"
