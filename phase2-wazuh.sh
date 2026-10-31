#!/usr/bin/env bash
set -euo pipefail

WAZUH_TAG="v4.14.9"
LAB_DIR="${HOME}/wazuh-lab"
REPO_DIR="${LAB_DIR}/wazuh-docker"

command -v docker >/dev/null 2>&1 || { echo "Docker belum terpasang. Jalankan phase1-docker.sh dulu."; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker daemon belum jalan. Jalankan: sudo service docker start"; exit 1; }

echo "=== Fase 2: Wazuh single-node (${WAZUH_TAG}) ==="
mkdir -p "$LAB_DIR"

if [[ -d "$REPO_DIR/.git" ]]; then
  git -C "$REPO_DIR" fetch --depth 1 origin "refs/tags/${WAZUH_TAG}:refs/tags/${WAZUH_TAG}" || true
  git -C "$REPO_DIR" checkout -f "$WAZUH_TAG"
else
  git clone --depth 1 --branch "$WAZUH_TAG" https://github.com/wazuh/wazuh-docker.git "$REPO_DIR"
fi

cd "$REPO_DIR/single-node"

python3 - <<'PY'
from pathlib import Path
p = Path('docker-compose.yml')
s = p.read_text()
pairs = {
    '      - "9200:9200"': '      - "127.0.0.1:9200:9200"',
    '      - "55000:55000"': '      - "127.0.0.1:55000:55000"',
}
for old, new in pairs.items():
    if old in s:
        s = s.replace(old, new)
    elif new not in s:
        raise SystemExit(f"pola tidak ditemukan: {old}")
p.write_text(s)
print("OK: port 9200 dan 55000 dibatasi ke 127.0.0.1 (dashboard & agent tetap terbuka di NAT WSL).")
PY

if [[ $(sysctl -n vm.max_map_count) -lt 262144 ]]; then
  sudo sysctl -w vm.max_map_count=262144 >/dev/null
fi

mkdir -p config/wazuh_indexer_ssl_certs

echo "Membuat certificate indexer..."
docker compose -f generate-indexer-certs.yml run --rm generator

echo "Menjalankan stack (pull image 3-4 GB, sabar)..."
docker compose up -d

echo "Menunggu dashboard siap..."
ready=0
for i in $(seq 1 60); do
  code=$(curl -ks -o /dev/null -w '%{http_code}' https://127.0.0.1/status 2>/dev/null || true)
  if [[ "$code" == "200" || "$code" == "302" || "$code" == "401" ]]; then
    echo "Dashboard siap (HTTP ${code})."
    ready=1
    break
  fi
  sleep 5
done
if [[ $ready -eq 0 ]]; then
  echo "Dashboard belum siap setelah 5 menit. Cek: docker compose logs -f wazuh.dashboard"
fi

cat > "${LAB_DIR}/up.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sudo sysctl -w vm.max_map_count=262144 >/dev/null
sudo service docker start >/dev/null 2>&1 || true
docker info >/dev/null 2>&1 || { echo "Docker gagal start"; exit 1; }
cd "$(dirname "$0")/wazuh-docker/single-node"
docker compose up -d
docker compose ps
EOF
chmod +x "${LAB_DIR}/up.sh"

echo
docker compose ps
echo
echo "=== Fase 2 selesai ==="
echo "Dashboard  : https://localhost   (gunakan kredensial compose; segera ganti default)"
echo "API        : https://127.0.0.1:55000"
echo "Agent      : 1514/tcp, enrollment 1515/tcp"
echo "Manager IP : 127.0.0.1 (localhostForwarding) atau $(hostname -I | awk '{print $1}')"
echo "Start ulang: bash ${LAB_DIR}/up.sh"
echo "RAM cek    : docker stats --no-stream"
