# Laporan Proyek Home Lab SIEM & SOC

**Proyek:** Virtual Home Lab + Wazuh SIEM di Laptop Pribadi  
**Penulis:** Valdez Bentiraz  
**Tanggal:** 26 Oktober 2026  
**Status:** Fase 0–3 selesai; Fase 4–6 direncanakan  
**Lingkungan:** Acer Nitro AN515-52, Windows 11, WSL2 Ubuntu 22.04, Docker, Wazuh 4.14.9

---

## 1. Ringkasan Eksekutif

Proyek ini membangun lab keamanan defensif mandiri di satu laptop tanpa perangkat tambahan. Tujuannya bukan sekadar memasang SIEM, tetapi mempraktikkan siklus kerja SOC: mengumpulkan telemetri endpoint, memvalidasi deteksi, menganalisis alert, membedakan false positive dari insiden, dan mendokumentasikan proses.

Hasil utama:

- Wazuh 4.14.9 berjalan sebagai single-node stack (manager, indexer, dashboard) di Docker dalam WSL2.
- Windows 11 host dimonitor sebagai endpoint pertama menggunakan Sysmon dan Wazuh agent 001.
- Telemetri yang tervalidasi: Security 4625 (failed logon), Security 4688 (process creation), Sysmon Event ID 1, PowerShell 4104, dan FIM rule 550.
- Alert volume dianalisis: mayoritas adalah level rendah dari process creation, SCA compliance, dan error service Windows. Satu alert level 15 terbukti false positive.
- Kendala nyata (disk C:, RAM 16 GB, Docker/WSL quirks) diselesaikan dan didokumentasikan sebagai bagian dari pembelajaran.

---

## 2. Tujuan

1. Membangun SIEM Wazuh yang berjalan stabil di laptop pribadi.
2. Mengirim telemetri Windows yang relevan untuk deteksi ke Wazuh.
3. Memvalidasi bahwa event keamanan benar-benar masuk dan memicu rule.
4. Menganalisis alert volume dan false positive.
5. Menyusun workflow triage yang dapat dijelaskan saat interview SOC Analyst.
6. Menyiapkan fondasi untuk latihan serangan–deteksi (purple team) dan ESP32 wireless lab.

## 3. Scope dan Etika

- Semua pengujian dilakukan pada laptop, VM/WSL, container, dan AP milik sendiri.
- Tidak ada scanning atau serangan ke jaringan, domain, atau perangkat pihak lain.
- Lab berjalan lokal; dashboard/API tidak diekspos ke internet.
- Kredensial default tidak dimasukkan ke dokumen portofolio dan harus dirotasi sebelum ada eksposur.
- Pengujian brute force pada akun Windows nyata dibatasi untuk menghindari lockout; target latihan utama adalah container Linux.

---

## 4. Arsitektur

```text
+---------------------------------------------------------------+
| Windows 11 Host (16 GB)                                       |
|                                                               |
|  [Victim #1] Sysmon64 + Wazuh Agent 001                       |
|      |  Security / System / Sysmon / PowerShell / FIM         |
|      |  TCP 1514                                              |
|  [Browser] https://localhost/app/login                        |
|      |                                                        |
+------|--------------------------------------------------------+
       | WSL2 localhost forwarding
+------|--------------------------------------------------------+
| WSL2 Ubuntu 22.04 (6 GB, 4 vCPU)                              |
|                                                               |
|  Docker Engine                                                |
|   +-- wazuh.manager   (1514, 1515, 514/udp, 55000)            |
|   +-- wazuh.indexer   (9200, localhost)                       |
|   +-- wazuh.dashboard (443 -> 5601)                           |
|                                                               |
|  [Fase 4] victim containers: DVWA / Juice Shop / Ubuntu       |
|  [Fase 4] attack tools di Ubuntu (bukan Kali terpisah)        |
|  [Fase 6] bridge MQTT/syslog untuk ESP32                      |
+---------------------------------------------------------------+
```

Catatan jaringan:

- WSL memakai NAT. Port dashboard 443 dipublikasikan di WSL, tetapi tidak otomatis terbuka ke LAN.
- Windows dapat mengakses dashboard dan port agent melalui `localhost` (localhost forwarding).
- Indexer 9200 dan API 55000 dibatasi ke `127.0.0.1`.
- Enrollment agent memakai port 1515 tanpa password pada lab ini.

---

## 5. Inventaris Hardware dan Software

| Komponen | Detail |
|---|---|
| Host | Acer Nitro AN515-52 |
| CPU | Intel Core i5-8300H, 4 core / 8 thread |
| GPU | NVIDIA GeForce GTX 1050 (mobile) 4 GB + Intel UHD Graphics 630 |
| RAM | 16 GB (2 × 8 GB DDR4-2666), 2 slot, maksimal 32 GB |
| Storage | C: 476 GB (sisa ±35 GB), D: 931 GB (sisa ±232 GB) |
| OS | Windows 11 Home Single Language, build 26200 |
| WSL | WSL 3.0.3.0, Ubuntu 22.04.5 LTS, kernel 6.18.54.1 |
| WSL config | 6 GB RAM, 4 vCPU, swap 4 GB di D:, `autoMemoryReclaim=gradual` |
| Docker | Engine 29.9.2, Compose v5.6.1 |
| SIEM | Wazuh 4.14.9 (manager, indexer, dashboard) |
| Endpoint telemetry | Sysmon64 + config SwiftOnSecurity; Wazuh agent 4.14.9 |
| Agent | ID 001, nama `LAB-WIN`, status `active` |
| Dashboard | `https://localhost/app/login` |
| API | `https://127.0.0.1:55000` |
| Indexer | `https://127.0.0.1:9200` |

---

## 6. Ringkasan Implementasi per Fase

| Fase | Aktivitas | Status |
|---|---|---|
| 0 | Pindah VHDX WSL ke D:, tuning RAM/CPU/swap | Selesai |
| 1 | Install Docker Engine native + Compose | Selesai |
| 2 | Deploy Wazuh single-node 4.14.9 | Selesai |
| 3 | Sysmon + Wazuh agent + audit policy + validasi event | Selesai |
| 4 | Victim container + tools serangan + Linux victim/auditd | Belum |
| 5 | Siklus attack → detect → triage → tuning | Belum |
| 6 | ESP32 wireless attacker/sensor + bridge log | Belum |
| 7 | Hardening kredensial, backup, retensi, portfolio final | Sebagian |

---

## 7. Detail Implementasi

### 7.1 Fase 0 — Storage dan Resource WSL

Masalah awal:

- C: hanya sisa 18,8 GB (97% terpakai), sementara `ext4.vhdx` Ubuntu berukuran 28 GB di C:.
- WSL default hanya mendapat 7,7 GB RAM, di bawah rekomendasi Wazuh single-node (8 GB).
- Karena sistem tidak punya `/dev/kvm`, lab difokuskan pada WSL + Docker, bukan VM penuh.

Tindakan:

- `wsl --shutdown`, lalu `wsl --manage Ubuntu --move D:\WSL\Ubuntu`.
- Mengaktifkan sparse VHD.
- Membuat `C:\Users\analyst\.wslconfig`:

```ini
[wsl2]
memory=6GB
processors=4
swap=4GB
swapFile=D:\\WSL\\swap.vhdx
localhostForwarding=true

[experimental]
sparseVhd=true
autoMemoryReclaim=gradual
```

- Swap dipindahkan ke D: agar C: tidak terisi lagi.

Hasil:

- C: bebas dari ±19 GB menjadi ±46 GB.
- WSL berjalan dengan 6 GB dan 4 vCPU; 3,4 GB terpakai saat Wazuh aktif.
- `autoMemoryReclaim=gradual` membantu mengembalikan page cache ke Windows saat idle.

Catatan trade-off:

- 6 GB berada di bawah angka resmi Wazuh (8 GB), tetapi beban terukur hanya ±3,4 GB. Jika muncul OOM/restart container, naikkan ke 7–8 GB.

### 7.2 Fase 1 — Docker Engine

- Install Docker Engine resmi dan Compose plugin di Ubuntu WSL.
- Menghapus sisa konfigurasi Docker Desktop pada `~/.docker/config.json` yang menyebabkan error `docker-credential-desktop.exe` (backup dibuat).
- Menetapkan `vm.max_map_count=262144` agar Wazuh indexer dapat berjalan.
- Docker data root berada di ext4 WSL (secara fisik di D: setelah VHDX dipindah).

Validasi:

- `docker run --rm hello-world` berhasil.
- `docker info` menunjukkan Engine 29.9.2 dan data root `/var/lib/docker`.

### 7.3 Fase 2 — Wazuh Single-Node

- Clone `wazuh-docker` tag `v4.14.9`, jalankan stack single-node.
- Certificate dibuat dengan `generate-indexer-certs.yml`.
- Port dashboard 443, agent 1514/1515, API 55000, indexer 9200.
- API dan indexer dibatasi ke `127.0.0.1`; dashboard mengikuti NAT WSL.

Kendala dan perbaikan:

1. **Certificate kosong** — Docker membuat folder `config/wazuh_indexer_ssl_certs` sebagai `root:root` mode `500` saat bind mount pertama. Perbaikan: buat folder sebelum generator, regenerasi certificate, lalu jalankan stack.
2. **Dashboard macet di migrasi `.kibana_1`** — request pertama timeout karena indexer masih lambat saat startup, menyisakan index setengah jadi. Perbaikan: hapus `.kibana_1`, restart dashboard; migrasi selesai ±14 detik.

Validasi:

- Dashboard `https://localhost/app/login` → HTTP 200.
- Cluster indexer `green`.
- Manager processes `running`.
- Agent 000 (manager) aktif.

### 7.4 Fase 3 — Windows Endpoint Telemetry

Komponen yang dipasang di Windows:

- **Sysmon64** dengan config SwiftOnSecurity.
- **Wazuh agent 4.14.9** dengan manager `127.0.0.1`.
- Konfigurasi agent:
  - Event channel: Security, System, Application, Sysmon/Operational, PowerShell/Operational, TaskScheduler/Operational, Defender/Operational, TerminalServices, WinRM, WMI-Activity, SMBClient.
  - FIM: Startup folder, System32\Tasks, drivers\etc, Desktop, Downloads, registry Run/RunOnce.
  - SCA, rootcheck, syscollector.
- Audit policy:
  - Process Creation + command line.
  - Logon success/failure.
  - PowerShell Script Block Logging (4104).

Kendala:

- Agent 001 sempat `never_connected` setelah enrollment; ini transien sebelum koneksi pertama. Setelah keepalive pertama, status menjadi `active`.
- `Stop-Service SplunkForwarder` sempat timeout 120 detik (event 7011), tetapi service akhirnya berhenti dan StartMode menjadi `Manual`.

Validasi deteksi:

| Uji | Event / Rule | Hasil |
|---|---|---|
| Failed logon `net use \\127.0.0.1\IPC$ /user:fake wrongpass` | Security 4625 → rule 60122 | Berhasil |
| Process creation (notepad/cmd) | Sysmon ID 1 → rule 92031/92032 | Berhasil |
| Process creation audit | Security 4688 → rule 67027 | Berhasil |
| PowerShell activity | 4104 → rule 91815/91816 | Berhasil |
| FIM perubahan task Windows | Rule 550 (`C:\Windows\System32\Tasks\...`) | Berhasil |
| FIM file singkat di Startup | Rule 550 | Tidak tertangkap pada uji singkat; FIM terbukti bekerja lewat Tasks |

---

## 8. Analisis Volume Alert (Bukan Triage Menyeluruh)

Snapshot 26 Oktober 2026 ±12:42 WIB:

- Agent 001: ±2.167 alert.
- Agent 000 (manager): 219 alert.
- Total kira-kira 2.400 alert, mayoritas level rendah.

**Klarifikasi penting:** angka ini adalah **volume alert yang diindeks**, bukan jumlah alert yang sudah ditriase. Triage yang benar-benar dilakukan hanya pada sampel representatif: 4625/60122, 92213, 92058, FIM 550, dan 61102/61107 NVIDIA. Alert level rendah lainnya belum ditriase satu per satu.

Distribusi level (snapshot):

| Level | Kategori | Jumlah |
|---:|---|---:|
| 3 | Low | ±1.343 |
| 4 | Medium-low | ±122 |
| 5 | Medium | ±316 |
| 7 | Medium | ±353 |
| 9 | High | ±23 |
| 10 | High | ±24 |
| 12 | Critical | 1 |
| 15 | Critical | 9 |

Top rule:

| Rule | Jumlah | Sumber / Arti |
|---|---:|---|
| 67027 | 944 | Security 4688 process creation |
| 19007 | 347 | SCA CIS Windows 11 (compliance) |
| 61102 | 168 | Windows System error events |
| 61107 | 146 | Windows System error events |
| 19008 | 126 | SCA CIS Windows 11 (compliance) |
| 92032 | 114 | Sysmon process-related rule |
| 92031 | 64 | Sysmon discovery activity |
| 92052 | 60 | Sysmon rule |
| 92036 | 58 | Sysmon `net.exe` dari cmd |
| 61110 | 24 | Multiple System error events (NVIDIA noise) |
| 92213 | 9 | Executable dropped in malware folder |

Interpretasi:

1. **Alert ≠ insiden.** Sebagian besar adalah telemetri normal yang cocok dengan rule level rendah.
2. **Duplikasi process creation.** 4688 (67027) dan Sysmon (92031/92032) sama-sama mencatat proses. Ini menambah volume.
3. **SCA bukan insiden.** 19007/19008 adalah temuan compliance CIS, bukan serangan.
4. **Crash loop service NVIDIA.** 61102/61107/61110 berasal dari `NvContainerLocalSystem` yang crash berulang. Log `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log` menunjukkan plugin wajib `NvPluginWatchdog` gagal inisialisasi dan container keluar dengan exit code `14109`. Windows Service Control Manager mencatat event 7031 (service terminated unexpectedly) dan 7023 (service terminated with error), lalu melakukan recovery restart. Ini masalah operasional/driver (driver 546.01 pada Windows build 26200), bukan serangan. Pada snapshot awal ada 518 alert NVIDIA (258 rule 61102, 224 rule 61107, 36 rule 61110); karena crash loop berlanjut, jumlahnya meningkat menjadi **9.991** pada snapshot berikutnya. Log plugin juga menunjukkan dependency `MessageBus.dll` gagal dan beberapa plugin (`_NvMdnsPlugin.dll`, `_NvStreamControl.dll`, `_IdentityPlugin.dll`) error 126, disertai `NvPluginWatchdog` gagal inisialisasi. Recovery program yang dijalankan Windows adalah `C:\Windows\NvContainerRecovery.bat`; file ini sudah diverifikasi legitimate (hanya registry recovery + `net start`, ACL normal, SHA256 `10102167...CA76`), bukan persistence. Log recovery juga menunjukkan `net start` gagal dengan error 14109. **Perbaikan:** driver di-update ke **582.78**; `NvContainerLocalSystem` sekarang `Running`; tidak ada event 7031/7023 atau alert NVIDIA baru sejak boot 29 Oktober 10:01. Ribuan alert lama tetap ada sebagai histori.
5. **False positive level 15.** Rule 92213 menandai `__PSScriptPolicyTest_*.ps1` di `AppData\Local\Temp` yang dibuat `powershell.exe`. File ini adalah uji internal PowerShell saat memeriksa execution policy, bukan malware. Pada snapshot 29 Oktober, rule 92213 mencapai 457 alert: 407 dari Visual Studio Setup Service (`BackgroundDownload.exe`), 41 dari PowerShell policy test, sisanya updater Opera GX/BingSvc/installer. Ini menunjukkan rule 92213 sangat broad dan perlu tuning berbasis parent process/target file, bukan suppression global.
6. **Satu failed logon** dari uji `net use` memicu 60122; satu kegagalan belum tentu insiden, perlu konteks frekuensi dan sumber.

---

## 9. Workflow Alert Management

Wazuh 4.x tidak memiliki status per-alert atau case management native. Alert bersifat immutable. Karena itu, status triage harus dikelola di luar SIEM.

Alur yang direkomendasikan:

1. Filter antrean: `rule.level >= 7`, 24 jam terakhir.
2. Buang kategori non-insiden: SCA, error service yang diketahui, rule process creation level 3.
3. Deduplikasi berdasarkan rule + agent + user/source IP + time window.
4. Buat case di tracker eksternal dan simpan `_id` alert Wazuh.
5. Enrichment: parent process, hash, signer, user, path, reputasi, asset criticality.
6. Tentukan disposisi: True Positive, False Positive, Benign, Duplicate.
7. Eskalasi/tindakan atau tutup.
8. Tuning: suppression, threshold, frequency rule, atau perbaikan konfigurasi.

Detail triage dan contoh case ada di `06-LAB-JOURNAL.md` serta `triage-cases.csv`.

---

## 10. Kendala dan Resolusi

| # | Kendala | Dampak | Resolusi |
|---:|---|---|---|
| 1 | C: hampir penuh, VHDX di C: | Wazuh tidak muat | Pindah VHDX ke D:, sparse VHD |
| 2 | WSL hanya 7,7 GB | Di bawah rekomendasi Wazuh | Naikkan batas, lalu turunkan ke 6 GB setelah analisis |
| 3 | `docker-credential-desktop.exe` | Pull image gagal | Hapus `credsStore` dari `~/.docker/config.json` |
| 4 | Certificate Wazuh kosong | Stack tidak bisa start | Buat folder cert sebelum generator, regenerasi |
| 5 | Dashboard macet migrasi `.kibana_1` | Dashboard 503 | Hapus index setengah jadi, restart dashboard |
| 6 | Host 92–94% RAM | Ngelag | Matikan service/startup non-esensial, tutup Chrome, batasi WSL, autoMemoryReclaim |
| 7 | SplunkForwarder stop timeout | Proses stop lambat | Service tetap berhenti; StartMode Manual |
| 8 | Agent `never_connected` | Terlihat gagal | Transien; menjadi active setelah koneksi pertama |
| 9 | FIM file Startup tidak tertangkap | Uji FIM tampak gagal | FIM terbukti bekerja via rule 550 pada Tasks; uji file singkat perlu timing lebih baik |
| 10 | Wazuh API config query timeout | Investigasi FIM via API gagal | Retry saat manager tidak sibuk; gunakan log/alternative query |
| 11 | NVIDIA `NvContainerLocalSystem` crash loop | Ribuan alert noise; service restart berulang | **Resolved:** update driver ke 582.78; service Running; 0 alert baru sejak boot |

---

## 11. Keamanan dan Batasan

### Keamanan

- Dashboard/API/indexer hanya untuk localhost/NAT; tidak ada port forward ke internet.
- Indexer dan API dibatasi `127.0.0.1`.
- Kredensial default lab **tidak ditulis** di dokumen ini; rotasi belum dilakukan.
- Enrollment agent memakai `use_password=no`; port 1515 hanya dapat dijangkau lokal. Jika nanti memakai mirrored networking atau eksposur, aktifkan password enrollment.
- User indexer demo (`kibanaro`, `logstash`, `readall`, `snapshotrestore`) masih aktif dengan password default dan sebaiknya dinonaktifkan.
- Grup `docker` di WSL setara root; jangan menambahkan user yang tidak dipercaya.
- Agent key di `client.keys` adalah secret; jangan dipublikasikan.

### Batasan

- 16 GB RAM adalah batasan utama. 6 GB WSL adalah trade-off; jika Wazuh OOM, naikkan ke 7–8 GB.
- Tidak ada KVM, sehingga lab tidak memakai VM penuh.
- WSL2 bukan lingkungan identik dengan server produksi; perilaku jaringan dan I/O berbeda.
- Belum ada NIDS (Suricata/Zeek), belum ada Linux victim, belum ada ESP32.
- Alert volume masih tinggi; tuning baru sebagian.
- Dokumentasi belum menyertakan screenshot; lihat checklist evidence.

---

## 12. Roadmap

### Jangka pendek

1. Tuning alert:
   - Suppress 92213 untuk pola `__PSScriptPolicyTest_*`.
   - Filter 61110/NVIDIA dari antrean insiden.
   - Pisahkan SCA 19007/19008 ke dashboard compliance.
   - Putuskan 67027 vs Sysmon untuk mengurangi duplikasi.
2. Buat case tracker (CSV/Notion/Jira).
3. Validasi ulang FIM dengan file yang bertahan lebih lama.

### Fase 4 — Victim dan Attack Tools (4A in progress)

- **DVWA** berjalan di `127.0.0.1:8080` (HTTP 302 ke setup/login), container `lab-dvwa`.
- OWASP Juice Shop: compose siap, dijalankan bergantian karena RAM.
- Tools di Ubuntu: nmap, hydra, sqlmap, nikto, ffuf, gobuster, impacket, netexec.
- Metasploit dijalankan on-demand via container.
- Linux victim + SSH + auditd + Wazuh agent 002 masuk 4B.

### Fase 5 — Attack → Detect → Triage

- Nmap scan, failed login/brute force, web injection, persistence, credential access.
- Atomic Red Team untuk teknik ATT&CK yang repeatable.
- Validasi rule, triage, tuning, dan dokumentasi case.
- Dashboard MITRE ATT&CK dan metrik alert.

### Fase 6 — ESP32

- ESP32 attacker (deauth/evil portal) pada AP sendiri.
- ESP32 sensor promiscuous → MQTT/syslog → Wazuh custom rule.
- BLE HID/BadUSB untuk menguji visibilitas endpoint.
- IoT telemetry (DHT/MQTT) untuk demo IT/OT.

### Hardening

- Rotasi password admin, kibanaserver, wazuh-wui.
- Nonaktifkan user indexer demo.
- Aktifkan enrollment password jika port 1515 terekspos.
- Backup konfigurasi dan volume; retensi index 7–14 hari.
- Upgrade RAM ke 2×16 GB DDR4-2666.

---

## 13. Evidence yang Perlu Diambil untuk Portofolio

- Screenshot dashboard overview dan agent 001 `active`.
- Screenshot detail alert 4625 (rule 60122).
- Screenshot Sysmon Event ID 1 (rule 92031/92032).
- Screenshot PowerShell 4104.
- Screenshot FIM rule 550.
- Screenshot alert 92213 beserta analisis false positive.
- Screenshot MITRE ATT&CK dashboard.
- Screenshot `docker compose ps` dan `free -h`.
- Simpan file konfigurasi yang sudah disanitasi (tanpa password/key).

---

## 14. Referensi

- Wazuh Documentation — Docker deployment, agent configuration, rules.
- Microsoft Sysinternals — Sysmon.
- SwiftOnSecurity — sysmon-config.
- Microsoft — WSL configuration (`.wslconfig`), memory reclaim.
- MITRE ATT&CK — teknik dan taktik.
- OpenSearch — indexer, security plugin.

---

## 15. Ringkasan Pelajaran

Detail ada di [03-LESSONS-LEARNED.md](03-LESSONS-LEARNED.md). Inti:

- Kapasitas RAM dan disk harus direncanakan sebelum deploy SIEM.
- Memahami perbedaan event, alert, dan insiden adalah keterampilan inti SOC.
- Severity tinggi tetap harus divalidasi konteks.
- False positive harus menghasilkan tuning, bukan hanya ditutup.
- Alert management adalah kombinasi proses, ticketing, dan tuning—bukan hanya fitur SIEM.
- Dokumentasi dan bukti adalah bagian dari pekerjaan SOC, bukan tambahan.
