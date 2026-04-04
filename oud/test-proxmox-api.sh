#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./test-proxmox-api.sh <token_secret>
# Optional env vars:
#   PVE_HOST=10.24.38.2
#   PVE_USER=ansible@pam
#   PVE_TOKEN_ID=ansible-token

PVE_HOST="${PVE_HOST:-10.24.38.2}"
PVE_USER="${PVE_USER:-ansible@pam}"
PVE_TOKEN_ID="${PVE_TOKEN_ID:-ansible-token}"

if [[ "${1:-}" == "" ]]; then
  echo "Usage: $0 <token_secret>"
  exit 2
fi

TOKEN_SECRET="$1"

echo "Testing Proxmox API at https://${PVE_HOST}:8006"
echo "User: ${PVE_USER}  Token ID: ${PVE_TOKEN_ID}"
echo

BODY_FILE="$(mktemp)"
HTTP_CODE="$(curl -kS \
  -o "${BODY_FILE}" \
  -w "%{http_code}" \
  -H "Authorization: PVEAPIToken=${PVE_USER}!${PVE_TOKEN_ID}=${TOKEN_SECRET}" \
  "https://${PVE_HOST}:8006/api2/json/nodes" || true)"

echo "HTTP: ${HTTP_CODE}"
echo "Response:"
cat "${BODY_FILE}"
echo
rm -f "${BODY_FILE}"

case "${HTTP_CODE}" in
  200) echo "OK: Token auth works." ;;
  401) echo "FAIL: Unauthorized (wrong user/token id/token secret, or token disabled)." ;;
  403) echo "FAIL: Auth OK but insufficient ACL permissions." ;;
  000) echo "FAIL: Connection/TLS problem (host unreachable, DNS, firewall, cert handshake)." ;;
  *)   echo "FAIL: Unexpected HTTP status ${HTTP_CODE}." ;;
esac
