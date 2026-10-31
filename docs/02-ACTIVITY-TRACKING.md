# Tracking Aktivitas Home Lab

**Proyek:** Wazuh SIEM + SOC Home Lab  
**Periode:** 25–26 Oktober 2026  
**Status:** Fase 0–3 selesai; Fase 4A in progress; 4B–6 pending

> Jurnal kronologis lengkap: [06-LAB-JOURNAL.md](06-LAB-JOURNAL.md). Setiap aksi teknis dicatat di sana.

---

## 1. Log Kronologis

| Tanggal | Fase | Aktivitas | Artefak / Perintah | Hasil | Status |
|---|---|---|---|---|---|
| 2026-10-25 | Inventaris | Cek OS, CPU, RAM, disk, Docker, virtualisasi, tool | `free -h`, `df -h`, `docker --version`, `/dev/kvm` | 16 GB RAM, C: 18,8 GB free, VHDX 28 GB di C:, Docker Desktop terpasang tapi mati | Selesai |
| 2026-10-25 | 0 | Pindah VHDX Ubuntu ke D: | `wsl --manage Ubuntu --move D:\WSL\Ubuntu` | VHDX di D:, C: bebas ±28 GB | Selesai |
| 2026-10-25 | 0 | Tuning WSL | `.wslconfig`: memory 10→8→6 GB, 4 vCPU, swap 4 GB di D:, autoMemoryReclaim | WSL 6 GB, 4 vCPU | Selesai |
| 2026-10-25 | 1 | Install Docker Engine + Compose | `phase1-docker.sh` | Docker 29.9.2, Compose 5.6.1 | Selesai |
| 2026-10-25 | 1 | Perbaiki error credential helper | Hapus `credsStore` dari `~/.docker/config.json` (backup) | `hello-world` berhasil | Selesai |
| 2026-10-25 | 1 | Set `vm.max_map_count` | `sysctl -w vm.max_map_count=262144` + persist | Nilai 262144 | Selesai |
| 2026-10-25 | 2 | Clone dan konfigurasi Wazuh | `phase2-wazuh.sh`, tag `v4.14.9` | Repo di `~/wazuh-lab/wazuh-docker` | Selesai |
| 2026-10-25 | 2 | Perbaiki certificate kosong | Buat `config/wazuh_indexer_ssl_certs`, regenerasi cert | 12 file cert lengkap | Selesai |
| 2026-10-25 | 2 | Perbaiki dashboard macet `.kibana_1` | Hapus index, restart dashboard | Migrasi selesai ±14 detik, dashboard HTTP 200 | Selesai |
| 2026-10-25 | 2 | Validasi stack | `docker compose ps`, cluster health, API | Manager/indexer/dashboard up, cluster `green`, agent 000 active | Selesai |
| 2026-10-26 | Resource | Analisis RAM host | Task Manager, `vmmemWSL`, `Get-Process` | Host 92–94%, vmmemWSL ±7,6 GB, baseline Windows tinggi | Selesai |
| 2026-10-26 | Resource | Matikan service/startup non-esensial | `Set-Service ... Manual`, `Stop-Service` | CCleaner, SQL, MySQL, PostgreSQL, Splunkd, SplunkForwarder stopped/Manual | Selesai |
| 2026-10-26 | Resource | Kurangi WSL ke 6 GB + auto reclaim | `.wslconfig` | WSL 5,8 Gi; host free ±2,1 GB | Selesai |
| 2026-10-26 | 3 | Buat script Sysmon + agent | `phase3-windows.ps1`, `phase3-ossec.conf`, `phase3-verify.sh` | Script valid secara sintaks | Selesai |
| 2026-10-26 | 3 | Install Sysmon + Wazuh agent | Jalankan `phase3-windows.ps1` (UAC) | Sysmon64 Running, WazuhSvc Running | Selesai |
| 2026-10-26 | 3 | Enrollment agent | Agent 001 `LAB-WIN` | Sempat `never_connected`, lalu `active` | Selesai |
| 2026-10-26 | 3 | Uji failed logon | `net use \\127.0.0.1\IPC$ /user:fake wrongpass` | Security 4625 → rule 60122 | Selesai |
| 2026-10-26 | 3 | Uji process creation | `notepad.exe`, `cmd`, PowerShell | Sysmon ID 1 → 92031/92032; 4688 → 67027 | Selesai |
| 2026-10-26 | 3 | Uji PowerShell 4104 | Script block logging | Rule 91815/91816 | Selesai |
| 2026-10-26 | 3 | Uji FIM | File di Startup; perubahan Tasks | Rule 550 pada Tasks; file Startup singkat tidak tertangkap | Sebagian |
| 2026-10-26 | Analisis | Analisis alert volume | Aggregasi indexer | ±2.167 alert agent 001, 219 manager; mayoritas level 3–7; **bukan triage menyeluruh** | Selesai |
| 2026-10-26 | Analisis | Analisis false positive | Detail alert 92213 | `__PSScriptPolicyTest_*.ps1` oleh PowerShell = FP | Selesai |
| 2026-10-26 | Analisis | Investigasi alert NVIDIA | Log `NvContainerLocalSystem.log`, Event 7031/7023, `Get-Service *Nv*` | `NvContainerLocalSystem` crash loop; `NvPluginWatchdog` gagal; exit 14109 | Selesai |
| 2026-10-27 | Analisis | Verifikasi recovery program NVIDIA | `sc qfailure`, isi `NvContainerRecovery.bat`, ACL, hash, recovery log | Program legitimate; `net start` gagal 14109; bukan persistence | Selesai |
| 2026-10-27 | Analisis | Audit instalasi NVIDIA | Registry uninstall, `Test-Path`, log NvContainer, count alert | Driver 546.01; GFE 3.28; plugin dependency error 126; alert NVIDIA 9.991 | Selesai |
| 2026-10-27 | Inventaris | Verifikasi model GPU | `Win32_VideoController`, `nvidia-smi --query-gpu` | NVIDIA GTX 1050 4 GB mobile, bukan 1050 Ti; Intel UHD 630 | Selesai |
| 2026-10-29 | Fix | Update driver NVIDIA | Install driver 582.78 | Service Running; 0 event 7031/7023 dalam 2 jam; 0 alert baru sejak boot | Selesai |
| 2026-10-29 | Tuning | Terapkan `lab_tuning.xml` | Rules 100211–100212; 100210 dihapus saat hardening | Test 92213 PowerShell: 59 → 60 (tetap terlihat); dashboard 200; agent active | Selesai |
| 2026-10-30 | 4A | Menjalankan DVWA | `docker compose --profile dvwa up -d` | `lab-dvwa` Up, `127.0.0.1:8080`, HTTP 302 | Selesai |
| 2026-10-30 | 4B | Build Linux victim + Wazuh agent | `linux-victim/docker-compose.yml`, `Dockerfile` | `lab-linux-victim` Up, SSH 2222, agent **003 active** | Selesai |
| 2026-10-30 | 4B | Uji SSH + auth log | `hydra -l labuser -p wrongpass ssh://127.0.0.1:2222` | auth.log tercatat; alert PAM 5503 | Selesai |
| 2026-10-26 | Dokumentasi | Report, tracking, lessons, template triage, perbandingan SIEM | Folder `docs/` | Dokumen dibuat | Selesai |

---

## 2. Checklist

### Selesai

- [x] Inventaris hardware/software.
- [x] Pindah VHDX WSL ke D: dan aktifkan sparse VHD.
- [x] Tuning RAM/CPU/swap WSL.
- [x] Install Docker Engine + Compose.
- [x] Perbaiki sisa konfigurasi Docker Desktop.
- [x] Deploy Wazuh 4.14.9 single-node.
- [x] Perbaiki certificate generation.
- [x] Perbaiki migrasi dashboard `.kibana_1`.
- [x] Dashboard, API, indexer tervalidasi.
- [x] Agent 000 dan 001 active.
- [x] Sysmon64 + SwiftOnSecurity config.
- [x] Wazuh agent 4.14.9 + custom `ossec.conf`.
- [x] Audit Process Creation + command line.
- [x] Audit Logon success/failure.
- [x] PowerShell Script Block Logging.
- [x] Validasi 4625, 4688, Sysmon ID 1, 4104, FIM 550.
- [x] Analisis alert volume dan false positive.
- [x] Dokumentasi report/tracking/lessons/triage.

### Sedang berjalan / perlu dilengkapi

- [x] Tuning awal 92213/92058 dengan rule sempit; 92213 PowerShell tetap terlihat.
- [x] Fase 4A: DVWA container berjalan di `127.0.0.1:8080`.
- [ ] Fase 4A: install tools serangan di Ubuntu.
- [ ] Fase 4A: Juice Shop.
- [x] Fase 4B: Linux victim container + SSH + rsyslog + Wazuh agent 003 active.
- [ ] Fase 4B: auditd (tidak didukung di container WSL; perlu distro/host terpisah).
- [ ] Filter/cleanup alert NVIDIA lama setelah screenshot.
- [ ] Pisahkan SCA 19007/19008 ke compliance dashboard.
- [ ] Putuskan suppress 67027 (duplikat 4688 vs Sysmon).
- [ ] Validasi FIM dengan file yang bertahan lebih lama.
- [ ] Buat case tracker aktif (CSV → Notion/Jira).
- [ ] Screenshot evidence untuk portofolio.
- [ ] Rotasi kredensial default.
- [ ] Nonaktifkan user indexer demo.
- [ ] Backup konfigurasi dan volume.

### Belum dimulai

- [ ] Fase 4B: Linux victim/auditd (lanjutan).
- [ ] Fase 5: attack → detect → triage → tuning.
- [ ] Fase 6: ESP32 attacker/sensor + MQTT/syslog bridge.
- [ ] NIDS Suricata/Zeek (opsional).
- [ ] Upgrade RAM 2×16 GB.

---

## 3. Open Issues

| # | Isu | Dampak | Rencana |
|---:|---|---|---|
| 1 | FIM file singkat di Startup tidak tertangkap | Uji FIM tampak gagal | FIM terbukti via Tasks; uji ulang dengan file bertahan >1 menit |
| 2 | Wazuh API config query timeout | Tidak bisa ambil config efektif agent | Retry saat manager idle; cek `api.log` |
| 3 | 6 GB WSL di bawah rekomendasi resmi | Risiko OOM saat beban naik | Monitor `docker stats`; naikkan ke 7–8 GB jika perlu |
| 4 | Alert volume tinggi | Alert fatigue | Tuning rule, dashboard filter, case tracker |
| 5 | Kredensial default | Risiko jika diekspos | Rotasi + nonaktifkan demo user + enrollment password |
| 6 | Host free ±2,1 GB | Masih mepet | Tutup aplikasi berat; pertimbangkan upgrade 32 GB |
| 7 | Belum ada backup | Risiko kehilangan konfigurasi | Export WSL + backup compose/volume |
| 8 | NVIDIA `NvContainerLocalSystem` crash loop | Ribuan alert lama; 0 alert baru sejak fix | **Resolved:** driver 582.78; service Running; alert lama bisa difilter/dibersihkan setelah screenshot |

---

## 4. Perubahan Konfigurasi Penting

| Item | Sebelum | Sesudah | Alasan |
|---|---|---|---|
| Lokasi VHDX | C: (`Packages\...\LocalState`) | D:\WSL\Ubuntu | C: penuh |
| WSL memory | 7,7 GB (default) | 6 GB | Host 16 GB, Wazuh aktual ±3,4 GB |
| WSL CPU | 8 thread | 4 vCPU | Sisakan resource Windows |
| Swap | Default di C: | 4 GB di D: | C: penuh |
| Auto reclaim | Tidak ada | `autoMemoryReclaim=gradual` | Kembalikan cache ke Windows |
| Docker | Docker Desktop (mati) | Docker Engine native | Lebih ringan, data di ext4 |
| Agent manager | — | `127.0.0.1:1514` | Localhost forwarding WSL |
| Enrollment | — | `1515`, tanpa password | Lab lokal |
| Audit | Default | Process Creation + Logon + Script Block | Telemetri deteksi |
| Sysmon config | — | SwiftOnSecurity | Process/file/network telemetry |

---

## 5. Command Reference

### Operasional lab

```bash
# Start Wazuh lengkap
bash ~/wazuh-lab/up.sh

# Start tanpa dashboard (hemat RAM)
bash ~/wazuh-lab/up.sh --no-dashboard

# Stop container
bash ~/wazuh-lab/down.sh

# Status
cd ~/wazuh-lab/wazuh-docker/single-node
docker compose ps
docker stats --no-stream
```

### Verifikasi agent dan alert

```bash
bash /mnt/d/Portofolio/CyberSecurity/home-lab/phase3-verify.sh
```

### Windows

```powershell
Get-Service Sysmon64,WazuhSvc
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 30
Get-WinEvent -LogName Microsoft-Windows-Sysmon/Operational -MaxEvents 5
```

### Indexer query

```bash
# 10 alert terbaru agent 001
curl -ks -u admin:'<ADMIN_PASSWORD>' \
  'https://127.0.0.1:9200/wazuh-alerts-*/_search?q=agent.id:001&size=10&sort=@timestamp:desc' | jq

# Failed logon
curl -ks -u admin:'<ADMIN_PASSWORD>' \
  'https://127.0.0.1:9200/wazuh-alerts-*/_search?q=agent.id:001%20AND%20data.win.system.eventID:4625&size=5' | jq
```

### Wazuh API

```bash
TOKEN=$(curl -ks -u wazuh-wui:'<PASSWORD>' \
  -X POST 'https://127.0.0.1:55000/security/user/authenticate?raw=true')
curl -ks -H "Authorization: Bearer $TOKEN" \
  'https://127.0.0.1:55000/agents?select=id,name,status&pretty=true'
```

---

## 6. Path dan Artefak

| Path | Isi |
|---|---|
| `D:\Portofolio\CyberSecurity\home-lab\` | Script fase 0–3 |
| `D:\Portofolio\CyberSecurity\home-lab\docs\` | Dokumentasi portofolio |
| `~/wazuh-lab/wazuh-docker\` | Repo Wazuh dan compose |
| `~/wazuh-lab/up.sh`, `down.sh` | Operasional |
| `D:\lab-tools\` | Installer Sysmon, Wazuh MSI, config, log |
| `D:\lab-tools\phase3-install.log` | Log instalasi endpoint |
| `C:\Program Files (x86)\ossec-agent\` | Agent, config, log, client.keys |
| `D:\WSL\Ubuntu\ext4.vhdx` | Disk Ubuntu |
| `D:\WSL\swap.vhdx` | Swap WSL |

---

## 7. Next Actions

Prioritas tinggi:

1. Perbaiki crash loop NVIDIA (`NvContainerLocalSystem`) — update/clean install driver.
2. Tuning false positive 92213 dan noise 61110/NVIDIA setelah root cause dipahami.
3. Buat case tracker dan isi contoh case.
4. Ambil screenshot evidence.
5. Mulai Fase 4: DVWA/Juice Shop + tools.

Prioritas menengah:

5. Linux victim + auditd + agent.
6. Suricata/Zeek (opsional).
7. Hardening kredensial.
8. Backup.

Prioritas jangka panjang:

9. Serangan terarah + purple team loop.
10. ESP32 attacker/sensor.
11. Upgrade RAM 32 GB.
