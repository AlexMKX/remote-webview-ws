#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"

get_opt() {
  local key="$1" default="$2"
  if [ -f "$OPTIONS_FILE" ]; then
    jq -r --arg k "$key" --arg d "$default" '.[$k] // $d' "$OPTIONS_FILE"
  else
    echo "$default"
  fi
}

TILE_SIZE="$(get_opt tile_size 32)"
FULL_FRAME_TILE_COUNT="$(get_opt full_frame_tile_count 4)"
FULL_FRAME_AREA_THRESHOLD="$(get_opt full_frame_area_threshold 0.5)"
FULL_FRAME_EVERY="$(get_opt full_frame_every 50)"
EVERY_NTH_FRAME="$(get_opt every_nth_frame 1)"
MIN_FRAME_INTERVAL_MS="$(get_opt min_frame_interval_ms 80)"
JPEG_QUALITY="$(get_opt jpeg_quality 85)"
MAX_BYTES_PER_MESSAGE="$(get_opt max_bytes_per_message 61440)"
WS_PORT="$(get_opt ws_port 8081)"
DEBUG_PORT="$(get_opt debug_port 9221)"
HEALTH_PORT="$(get_opt health_port 18080)"
PREFERS_REDUCED_MOTION="$(get_opt prefers_reduced_motion false)"
INJECT_JS_URL="$(get_opt inject_js_url "")"
INJECT_JS_ALLOW_HTTP="$(get_opt inject_js_allow_http false)"
BROWSER_LOCALE="$(get_opt browser_locale "en-US")"
MAX_DEVICE_SCALE_FACTOR="$(get_opt max_device_scale_factor 1)"
export TILE_SIZE FULL_FRAME_TILE_COUNT FULL_FRAME_AREA_THRESHOLD FULL_FRAME_EVERY EVERY_NTH_FRAME
export MIN_FRAME_INTERVAL_MS JPEG_QUALITY MAX_BYTES_PER_MESSAGE WS_PORT DEBUG_PORT HEALTH_PORT
export PREFERS_REDUCED_MOTION INJECT_JS_URL INJECT_JS_ALLOW_HTTP BROWSER_LOCALE MAX_DEVICE_SCALE_FACTOR

USER_DATA_DIR_OPT="$(get_opt user_data_dir "/pw-data")"
if [ "$USER_DATA_DIR_OPT" = "/pw-data" ]; then
  mkdir -p /data/pw-data
  # if not already a symlink, make /pw-data -> /data/pw-data
  if [ ! -L /pw-data ]; then
    rm -rf /pw-data 2>/dev/null || true
    ln -s /data/pw-data /pw-data
  fi
  export USER_DATA_DIR="/pw-data"
else
  mkdir -p "$USER_DATA_DIR_OPT"
  export USER_DATA_DIR="$USER_DATA_DIR_OPT"
fi

EXPOSE_DEBUG_PROXY="$(get_opt expose_debug_proxy false)"
if [ "$EXPOSE_DEBUG_PROXY" = "true" ]; then
  DEBUG_PROXY_PORT="$(get_opt debug_proxy_port 9222)"
  echo "[remote-webview] Starting debug proxy on :${DEBUG_PROXY_PORT} -> 127.0.0.1:${DEBUG_PORT}"
  socat -d -d "TCP-LISTEN:${DEBUG_PROXY_PORT},fork,reuseaddr,keepalive" "TCP:127.0.0.1:${DEBUG_PORT}" &
fi

die() {
  echo "[remote-webview] ERROR: $*" >&2
  exit 1
}

# Optional HA auto-login: the server seeds ha_auth_token into the browser
# localStorage on the origins of ha_url only. With no token set, nothing changes.
HA_AUTH_TOKEN="$(get_opt ha_auth_token "")"
HA_URL="$(get_opt ha_url "")"
if [ -n "$HA_AUTH_TOKEN" ] && [ -z "$HA_URL" ]; then
  # Auto-detect via the Supervisor (bounded timeout): join the configured
  # internal and external URLs; either or both may be missing. unique also
  # drops a duplicate when internal_url === external_url.
  if ! HA_CONFIG="$(curl -fsS --max-time 5 \
      -H "Authorization: Bearer ${SUPERVISOR_TOKEN:-}" \
      http://supervisor/core/api/config)"; then
    die "cannot read the Home Assistant configuration from the Supervisor - set the ha_url option"
  fi
  HA_URL="$(jq -r '[.internal_url, .external_url] | map(select(. != null)) | unique | join(",")' <<<"$HA_CONFIG")"
  [ -n "$HA_URL" ] || die "Home Assistant has neither internal_url nor external_url set - set the ha_url option"
fi
export HA_AUTH_TOKEN HA_URL

command -v node >/dev/null
test -f dist/index.js

exec node dist/index.js
