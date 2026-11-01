#!/usr/bin/env bash
set -euo pipefail

/var/ossec/bin/wazuh-control start || true
tail -F /var/ossec/logs/ossec.log &
exec sleep infinity
