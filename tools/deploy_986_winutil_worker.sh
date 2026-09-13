#!/usr/bin/env bash
set -euo pipefail

PI="abeyy@192.168.1.98"
REMOTE_DIR="/home/abeyy/.cache/986-winutil-bootstrap-deploy-$(date +%s)-$$"
LOCAL_DIR="infra/cloudflare/986-winutil-bootstrap"

[[ -f "$LOCAL_DIR/wrangler.jsonc" ]]
[[ -f "$LOCAL_DIR/src/index.js" ]]

ssh -o BatchMode=yes -o ConnectTimeout=8 "$PI" "mkdir -p '$REMOTE_DIR'"
scp -q -r -o BatchMode=yes -o ConnectTimeout=8 "$LOCAL_DIR/." "$PI:$REMOTE_DIR/"

ssh -o BatchMode=yes -o ConnectTimeout=8 "$PI" bash -s -- "$REMOTE_DIR" <<'REMOTE'
set -euo pipefail
D="$1"
cleanup(){ rm -rf "$D"; }
trap cleanup EXIT

source "$HOME/.local/lib/986-cloudflare/common.sh"
[[ -r "$CF986_DEPLOY_TOKEN_FILE" ]]
export CLOUDFLARE_API_TOKEN="$(tr -d '\r\n' < "$CF986_DEPLOY_TOKEN_FILE")"

verify="$(curl -fsS https://api.cloudflare.com/client/v4/user/tokens/verify -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")"
printf '%s' "$verify" | jq -e '.success == true and .result.status == "active"' >/dev/null
unset verify

echo "CLOUDFLARE_DEPLOY_AUTH=PASS"
cd "$D"
"$CF986_WRANGLER" deploy --config wrangler.jsonc
REMOTE

echo "WORKER_DEPLOY_COMMAND_PASS"
