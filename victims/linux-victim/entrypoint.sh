#!/usr/bin/env bash
set -euo pipefail

: "${LAB_USER_PASSWORD:?LAB_USER_PASSWORD must be set}"
: "${LAB_ADMIN_PASSWORD:?LAB_ADMIN_PASSWORD must be set}"

if ! id labuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash labuser
    echo "labuser:${LAB_USER_PASSWORD}" | chpasswd
fi

if ! id admin >/dev/null 2>&1; then
    useradd -m -s /bin/bash admin
    echo "admin:${LAB_ADMIN_PASSWORD}" | chpasswd
    usermod -aG sudo admin
fi

ssh-keygen -A
mkdir -p /run/sshd /var/log
touch /var/log/auth.log /var/log/syslog
chown syslog:adm /var/log/auth.log /var/log/syslog 2>/dev/null || true

if command -v rsyslogd >/dev/null 2>&1; then
    /usr/sbin/rsyslogd || true
    sleep 1
fi

if command -v auditd >/dev/null 2>&1; then
    mkdir -p /var/log/audit
    /sbin/auditd || true
    auditctl -R /etc/audit/rules.d/lab.rules 2>/dev/null || true
fi

/var/ossec/bin/wazuh-control start || true

tail -F /var/ossec/logs/ossec.log &

exec /usr/sbin/sshd -D -e
