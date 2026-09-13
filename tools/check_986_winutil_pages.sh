#!/usr/bin/env bash
set -euo pipefail

PI="abeyy@192.168.1.98"
ssh -o BatchMode=yes -o ConnectTimeout=8 "$PI" bash -s <<'REMOTE'
set -euo pipefail
source "$HOME/.local/lib/986-cloudflare/common.sh"
[[ -r "$CF986_DEPLOY_TOKEN_FILE" ]]
export CLOUDFLARE_API_TOKEN="$(tr -d '\r\n' < "$CF986_DEPLOY_TOKEN_FILE")"
verify="$(curl -fsS https://api.cloudflare.com/client/v4/user/tokens/verify -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")"
printf '%s' "$verify" | jq -e '.success == true and .result.status == "active"' >/dev/null
unset verify

projects="$($CF986_WRANGLER pages project list --json)"
printf '%s' "$projects" | jq -e 'type=="array" or (type=="object" and (.result|type)=="array")' >/dev/null
echo "PAGES_WRITE_LIST_ACCESS=PASS"
if printf '%s' "$projects" | jq -e 'if type=="array" then any(.[]; ((.name // .["Project Name"] // "") == "986-winutil-bootstrap")) else any(.result[]; ((.name // .["Project Name"] // "") == "986-winutil-bootstrap")) end' >/dev/null; then
  echo "PAGES_PROJECT_EXISTS=1"
else
  echo "PAGES_PROJECT_EXISTS=0"
fi
REMOTE
