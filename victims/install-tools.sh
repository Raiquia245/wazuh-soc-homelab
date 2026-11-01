#!/usr/bin/env bash
set -euo pipefail

echo "=== Install tools Phase 4A ==="
sudo apt-get update
sudo apt-get install -y \
  nmap hydra sqlmap nikto ffuf gobuster whatweb dirb \
  curl jq pipx

pipx ensurepath >/dev/null 2>&1 || true
pipx install impacket 2>/dev/null || true
pipx install netexec 2>/dev/null || true

echo
echo "=== Versi ==="
for t in nmap hydra sqlmap nikto ffuf gobuster whatweb; do
  printf "%-10s " "$t"
  command -v "$t" >/dev/null 2>&1 && "$t" --version 2>&1 | head -1 || echo "tidak ditemukan"
done
echo
echo "Impacket/netexec tersedia via pipx. Jika belum, buka terminal baru atau jalankan: pipx ensurepath"
echo "Metasploit (on-demand): docker run --rm -it metasploitframework/metasploit-framework"
