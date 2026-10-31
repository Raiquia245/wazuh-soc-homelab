#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Jalankan dengan: sudo bash $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-${USER}}"

echo "=== Fase 1: Docker Engine native di WSL ==="
apt-get update
apt-get install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
CODENAME="${VERSION_CODENAME:-jammy}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! service docker start 2>/dev/null; then
  echo "service docker gagal, mencoba dockerd langsung..."
  nohup dockerd >/var/log/dockerd.log 2>&1 &
  sleep 3
fi

for _ in $(seq 1 15); do
  if docker info >/dev/null 2>&1; then break; fi
  sleep 1
done

sysctl -w vm.max_map_count=262144
if ! grep -q '^vm.max_map_count' /etc/sysctl.conf 2>/dev/null; then
  echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
fi

usermod -aG docker "$TARGET_USER"

echo
docker --version
docker compose version
docker info --format 'Docker OK | driver={{.Driver}} | data-root={{.DockerRootDir}}' || true

echo
echo "=== Fase 1 selesai ==="
echo "Tutup dan buka ulang terminal WSL supaya grup docker aktif."
echo "Verifikasi: docker run --rm hello-world"
echo "Berikutnya: bash /mnt/d/Portofolio/CyberSecurity/home-lab/phase2-wazuh.sh"
