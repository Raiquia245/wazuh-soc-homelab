#!/usr/bin/env bash
set -euo pipefail

API='https://127.0.0.1:55000'
IDX='https://127.0.0.1:9200'
: "${WAZUH_API_PASSWORD:?Set WAZUH_API_PASSWORD}"
: "${WAZUH_ADMIN_PASSWORD:?Set WAZUH_ADMIN_PASSWORD}"
API_USER="${WAZUH_API_USER:-wazuh-wui}"
IDX_USER="${WAZUH_ADMIN_USER:-admin}"

TOKEN=$(curl -ks -u "${API_USER}:${WAZUH_API_PASSWORD}" -X POST "${API}/security/user/authenticate?raw=true")

echo "=== Agents ==="
curl -ks -H "Authorization: Bearer ${TOKEN}" \
  "${API}/agents?select=id,name,status,lastKeepAlive,version&pretty=true"

echo
echo "=== Indeks alert ==="
curl -ks -u "${IDX_USER}:${WAZUH_ADMIN_PASSWORD}" "${IDX}/_cat/indices/wazuh-alerts-*?v&h=health,status,index,docs.count" || true

echo
echo "=== 5 alert terbaru ==="
curl -ks -u "${IDX_USER}:${WAZUH_ADMIN_PASSWORD}" \
  "${IDX}/wazuh-alerts-*/_search?size=5&sort=@timestamp:desc&pretty=true" \
  | head -120 || true

echo
echo "=== Service Windows ==="
powershell.exe -NoProfile -Command "Get-Service Sysmon64,WazuhSvc -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType -AutoSize" 2>/dev/null | tr -d '\r'
