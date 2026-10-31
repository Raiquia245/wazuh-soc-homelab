# Jurnal Laboratorium

Jurnal kronologis seluruh tindakan teknis pada home lab. Setiap entri mencatat waktu, aksi, perintah/artefak, hasil, dan status. Kredensial dan key tidak ditulis di sini.


> Catatan: beberapa file tutorial yang disebut di entri lama (`04`, `05`, `07`, `SCREENSHOT-GUIDE`, `phase4/README`) sudah dihapus. Referensi tersebut adalah riwayat, bukan file aktif.

## Kebijakan Pencatatan

- Setiap perubahan konfigurasi, instalasi, troubleshooting, dan pengujian dicatat.
- Format: tanggal/waktu, fase, aksi, perintah/artefak, hasil, status.
- Status: `Selesai`, `Sebagian`, `Pending`, `Gagal`.
- Setelah entri baru, ringkasan checklist di `02-ACTIVITY-TRACKING.md` diperbarui bila perlu.
- Screenshot/bukti disimpan di `docs/screenshots/` dan dirujuk di entri.

---

## 2026-10-26

### 12:42 WIB — Snapshot kondisi lab

- **Fase:** Dokumentasi / validasi
- **Aksi:** Mengambil snapshot kondisi WSL, Docker, Wazuh, agent, dan host.
- **Perintah/artefak:** `free -h`, `df -h`, `docker compose ps`, Wazuh API agents, indexer count.
- **Hasil:**
  - WSL 5,8 Gi; 3,4 Gi used; 2,3 Gi cache.
  - Tiga container Wazuh Up.
  - Agent 000 dan 001 `active`.
  - Agent 001: ±2.167 alert; manager: 219 alert.
  - Host free ±2,1 GB; Sysmon64 dan WazuhSvc Running.
- **Status:** Selesai
- **Tindak lanjut:** Analisis alert dan dokumentasi.

### 12:43 WIB — Membuat dokumentasi portofolio

- **Fase:** Dokumentasi
- **Aksi:** Membuat folder `docs/` dan dokumen report, tracking, lessons learned, triage template, perbandingan SIEM, serta CSV tracker.
- **Artefak:**
  - `docs/README.md`
  - `docs/01-PROJECT-REPORT.md`
  - `docs/02-ACTIVITY-TRACKING.md`
  - `docs/03-LESSONS-LEARNED.md`
  - `docs/04-ALERT-TRIAGE-TEMPLATE.md`
  - `docs/05-SIEM-ALERT-MANAGEMENT.md`
  - `docs/triage-cases.csv`
- **Hasil:** Dokumentasi dibuat; kredensial/key disanitasi dari dokumen.
- **Status:** Selesai

### 12:54 WIB — Panduan screenshot

- **Fase:** Dokumentasi / evidence
- **Aksi:** Membuat folder screenshot dan panduan pengambilan bukti.
- **Artefak:**
  - `docs/screenshots/` (dengan `.gitkeep`)
  - `docs/SCREENSHOT-GUIDE.md`
- **Hasil:** Query dashboard untuk 4625, Sysmon, FIM, 92213, dan daftar nama file bukti.
- **Status:** Selesai
- **Tindak lanjut:** Ambil screenshot aktual.

### 12:55 WIB — Investigasi alert NVIDIA

- **Fase:** Analisis alert / troubleshooting
- **Aksi:** Menelusuri penyebab alert NVIDIA dari Windows System log, Wazuh, dan log NVIDIA.
- **Perintah/artefak:**
  - Query Wazuh rule 61102/61107/61110.
  - `Get-Service *Nv*`
  - `Get-WinEvent` Service Control Manager.
  - `Get-CimInstance Win32_Service -Filter "Name='NvContainerLocalSystem'"`
  - `nvidia-smi`
  - `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log`
- **Hasil:**
  - `NvContainerLocalSystem` crash berulang.
  - Event 7031 dan 7023 dari Service Control Manager.
  - Log NVIDIA: `Transition to Initializing state for mandatory plugin NvPluginWatchdog failed`; container exit code **14109**.
  - Driver 546.01 (2023); Windows build 26200.
  - ±518 alert NVIDIA: 258 × 61102, 224 × 61107, 36 × 61110.
  - `NvContainerLocalSystem` Stopped/Automatic; `NVDisplay.ContainerLocalSystem` Running.
  - Tidak ada indikasi serangan; ini operational/driver issue.
- **Status:** Sebagian (root cause teridentifikasi; perbaikan belum dilakukan)
- **Tindak lanjut:** Perbaiki driver NVIDIA atau workaround service Manual; tuning hanya setelah root cause dipahami.

### 12:58 WIB — Kebijakan jurnal dan rencana perbaikan NVIDIA

- **Fase:** Dokumentasi / perencanaan
- **Aksi:** Menetapkan kebijakan pencatatan setiap aksi dan menyusun rencana perbaikan NVIDIA.
- **Hasil:** Jurnal ini dibuat; rencana perbaikan driver dicatat.
- **Status:** Selesai
- **Rencana perbaikan NVIDIA:**
  1. Backup: restore point, BitLocker recovery key (jika aktif), export WSL, backup docs.
  2. Unduh driver NVIDIA resmi terbaru yang masih mendukung GTX 1050 untuk Windows 11 64-bit.
  3. Coba update in-place dengan opsi clean install.
  4. Jika masih crash: DDU di Safe Mode, lalu install driver bersih.
  5. Verifikasi: service `NvContainerLocalSystem` Running, `nvidia-smi`, Event Viewer tidak ada 7031/7023, alert NVIDIA berhenti.
  6. Jika masih gagal: set service Manual sebagai workaround, kumpulkan log untuk analisis lanjutan.
- **Status:** Pending

---

## 2026-10-27

### 00:09 WIB — Verifikasi recovery program NVIDIA

- **Fase:** Analisis / troubleshooting
- **Aksi:** Memeriksa konfigurasi recovery service dan isi program yang dijalankan Windows.
- **Perintah/artefak:**
  - `sc.exe qfailure NvContainerLocalSystem`
  - `Get-Content C:\Windows\NvContainerRecovery.bat`
  - `Get-Acl C:\Windows\NvContainerRecovery.bat`
  - `Get-FileHash C:\Windows\NvContainerRecovery.bat -Algorithm SHA256`
  - `C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log`
- **Hasil:**
  - Failure actions: restart 6s, restart 8s, run process 10s.
  - Recovery command: `cmd.exe /C %windir%\NvContainerRecovery.bat NvContainerLocalSystem C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log`.
  - Isi batch hanya: set registry recovery, `net start %1`, rollback registry, logging. Tidak ada PowerShell, download, encoded command, atau binary mencurigakan.
  - ACL normal: SYSTEM/Administrators FullControl; Users ReadAndExecute.
  - SHA256: `10102167FEFF89EB1170C6AAA6BD5871446854AEF5CBF05BF82B2FB3A4E2CA76`.
  - Recovery log: `net start NvContainerLocalSystem` gagal dengan system error **14109**.
  - Kesimpulan: recovery program legitimate NVIDIA, bukan persistence. Root cause tetap crash pada `NvPluginWatchdog`.
- **Status:** Selesai (verifikasi); perbaikan driver masih pending
- **Tindak lanjut:** Update/clean install driver NVIDIA; jika masih gagal, set service Manual.

### 00:25 WIB — Audit instalasi NVIDIA dan dampak alert

- **Fase:** Analisis / troubleshooting
- **Aksi:** Memeriksa software NVIDIA terpasang, plugin NvContainer, dan jumlah alert.
- **Perintah/artefak:**
  - Registry uninstall keys untuk NVIDIA/GeForce.
  - `Test-Path` folder GFE/NVIDIA App/NvContainer.
  - `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log`.
  - Query jumlah alert rule 61102/61107/61110.
- **Hasil:**
  - Driver 546.01; GeForce Experience 3.28.0.412; NvContainer 1.40; Watchdog Plugin 1.40; ShadowPlay 3.28.
  - GFE ada di `C:\Program Files\NVIDIA Corporation\NVIDIA GeForce Experience`; NVIDIA App belum terpasang.
  - Log plugin: dependency `MessageBus.dll` gagal (registry value), `_NvMdnsPlugin.dll`, `_NvStreamControl.dll`, `_IdentityPlugin.dll` error 126, dan `NvPluginWatchdog` gagal inisialisasi; container exit 14109.
  - Alert NVIDIA meningkat menjadi **9.991** (rule 61102/61107/61110).
  - Kesimpulan: instalasi NvContainer/driver tidak konsisten atau tidak cocok dengan Windows build 26200; bukan malware.
- **Status:** Pending (perbaikan belum dilakukan)
- **Tindak lanjut:** Backup, set service Manual sementara, clean install driver terbaru yang mendukung GTX 1050; opsi NVIDIA App; fallback DDU.

### 00:35 WIB — Verifikasi model GPU

- **Fase:** Inventaris
- **Aksi:** Memastikan model GPU discrete vs integrated.
- **Perintah/artefak:**
  - `Get-CimInstance Win32_VideoController`
  - `nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader`
- **Hasil:**
  - NVIDIA GeForce **GTX 1050**, 4096 MiB, driver 546.01.
  - Intel UHD Graphics 630 (integrated).
  - PNPDeviceID NVIDIA: `PCI\VEN_10DE&DEV_1C8D...`.
  - Bukan GTX 1050 Ti.
- **Status:** Selesai
- **Tindak lanjut:** Gunakan driver untuk GTX 1050 (notebook), bukan 1050 Ti.

### 00:45 WIB — Membuat brief handoff NVIDIA

- **Fase:** Dokumentasi
- **Aksi:** Menyusun ringkasan masalah NVIDIA + bukti untuk second opinion ke AI/teknisi lain.
- **Artefak:** `docs/NVIDIA-ISSUE-BRIEF.md`
- **Hasil:** Brief berisi environment, gejala, event 7031/7023, log NvContainer, recovery config, bukti GPU, dampak Wazuh, analisis, dan pertanyaan spesifik.
- **Status:** Selesai
- **Tindak lanjut:** Gunakan brief saat konsultasi; catat hasilnya di jurnal.

### 00:55 WIB — Prosedur cleanup alert NVIDIA

- **Fase:** Dokumentasi / analisis
- **Aksi:** Menambahkan prosedur aman untuk menghapus alert NVIDIA dan memverifikasi setelah perbaikan driver.
- **Artefak:** `docs/NVIDIA-ISSUE-BRIEF.md` bagian 13.
- **Hasil:**
  - Baseline count dan export bukti sebelum hapus.
  - `_delete_by_query` untuk 61102/61107 dengan `param1` NVIDIA.
  - 61110 tidak dihapus massal karena frequency rule.
  - Verifikasi memakai `FIX_TIME` UTC dan query range.
- **Status:** Selesai (dokumentasi); belum ada alert yang dihapus
- **Tindak lanjut:** Jalankan cleanup hanya setelah screenshot/export dan setelah driver diperbaiki.

---

## 2026-10-29

### 12:10 WIB — Triage alert 92058 `sdbinst.exe`

- **Fase:** Analisis alert / triage
- **Aksi:** Memvalidasi alert Application Compatibility Database launched (Sysmon Event ID 1).
- **Perintah/artefak:**
  - `Get-AuthenticodeSignature C:\Windows\System32\sdbinst.exe`
  - `Get-CimInstance Win32_Service -Filter "Name='PcaSvc'"`
  - `Get-ChildItem C:\Windows\AppPatch -Recurse -Filter *.sdb`
  - Query Wazuh `data.win.eventdata.image:*sdbinst*`, count rule 92058.
- **Hasil:**
  - `sdbinst.exe` di `C:\Windows\System32`, signature **Valid** (Microsoft Windows).
  - Parent: `svchost.exe -k LocalSystemNetworkRestricted -p -s PcaSvc`; service PcaSvc Running.
  - Command line: `C:\WINDOWS\System32\sdbinst.exe -m -bg`; user SYSTEM.
  - Pola berulang tiap jam (contoh 04:01, 05:01 UTC); total 15 alert 92058.
  - File .sdb di AppPatch adalah database kompatibilitas Windows; tidak ada path custom mencurigakan pada command line.
  - Kesimpulan: benign PcaSvc background maintenance, bukan application shimming malicious.
- **Status:** Closed – Benign
- **Tindak lanjut:** Pertimbangkan suppression/lower level 92058 hanya untuk pola PcaSvc + `sdbinst.exe System32 -m -bg`; jangan suppress semua 92058.

### 12:45 WIB — Triage ulang 92213 dan analisis broad rule

- **Fase:** Analisis alert / tuning
- **Aksi:** Memvalidasi alert 92213 `__PSScriptPolicyTest_*.ps1` dan menghitung pola keseluruhan rule 92213.
- **Perintah/artefak:**
  - Query 92213 count dan agregasi `data.win.eventdata.image` / `targetFilename`.
  - `Test-Path` file temp, `Get-ExecutionPolicy -List`.
- **Hasil:**
  - File `__PSScriptPolicyTest_pva3nha2.u5d.ps1` sudah tidak ada (PowerShell menghapusnya).
  - Execution policy: CurrentUser RemoteSigned, LocalMachine Restricted.
  - Total 92213: **457**.
  - Sumber utama: **407** dari `Microsoft.VisualStudio.Setup.Service\BackgroundDownload.exe`; 41 dari `powershell.exe`; sisanya updater Opera GX, BingSvc, installer NVIDIA/Brave.
  - Semua pola yang diperiksa adalah installer/updater/self-test, bukan eksekusi payload berbahaya.
  - Kesimpulan: alert spesifik = false positive PowerShell policy test; rule 92213 broad dan noisy.
- **Status:** Closed – Benign (per event); tuning pending
- **Tindak lanjut:** Suppress/lower 92213 hanya untuk pola terverifikasi: `__PSScriptPolicyTest_*.ps1` dan Visual Studio Setup Service di Temp. Jangan suppress seluruh 92213.

### 13:00 WIB — Membuat panduan latihan analisis log

- **Fase:** Dokumentasi / pembelajaran
- **Aksi:** Menyusun panduan analisis log SOC + latihan 7 hari.
- **Artefak:** `docs/07-LOG-ANALYSIS-PRACTICE.md`
- **Hasil:** Metode 5 langkah, field penting, analisis process/auth/FIM/PowerShell, query, worksheet, latihan 7 hari, dan kesalahan umum.
- **Status:** Selesai
- **Tindak lanjut:** Gunakan untuk latihan harian; catat temuan ke `triage-cases.csv`.

### 13:15 WIB — Menambahkan field wajib tabel log

- **Fase:** Dokumentasi / pembelajaran
- **Aksi:** Menambahkan daftar kolom minimal dan kolom per use case ke panduan analisis log.
- **Artefak:** `docs/07-LOG-ANALYSIS-PRACTICE.md` bagian 3.1–3.3.
- **Hasil:**
  - 12 kolom default triage Windows.
  - Kolom tambahan untuk auth, process tree, FIM, network, PowerShell, Linux/auditd.
  - Cara menambah kolom di Threat Hunting/Discover dan tips query.
- **Status:** Selesai
- **Tindak lanjut:** Terapkan kolom di dashboard.

### 13:30 WIB — Verifikasi perbedaan `timestamp` dan `@timestamp`

- **Fase:** Analisis data / dokumentasi
- **Aksi:** Memeriksa mapping dan keberadaan kedua field waktu.
- **Perintah/artefak:**
  - `_mapping/field/@timestamp`, `_mapping/field/timestamp`
  - Count dokumen tanpa `@timestamp`/`timestamp`
  - Sample 3 alert terbaru
- **Hasil:**
  - Keduanya bertipe `date`.
  - Dokumen tanpa `@timestamp`: 0; tanpa `timestamp`: 0.
  - Nilai sama, hanya format: `...Z` vs `...+0000`.
  - Tanda `-` di dashboard adalah masalah render/tampilan, bukan data kosong.
- **Status:** Selesai
- **Tindak lanjut:** Gunakan `@timestamp` untuk time filter/sorting; `timestamp` untuk waktu event asli.

### 13:40 WIB — Menambahkan perbandingan field Windows vs Linux

- **Fase:** Dokumentasi / pembelajaran
- **Aksi:** Menambahkan tabel field umum, Windows-only, Linux/auditd, dan baseline 12 kolom Linux.
- **Artefak:** `docs/07-LOG-ANALYSIS-PRACTICE.md` bagian 3.5.
- **Hasil:**
  - Field umum: time, agent, rule, MITRE, location, decoder, syscheck.
  - Windows: `data.win.*`.
  - Linux: `data.audit.*`, `data.srcuser/dstuser`, `data.srcip`.
  - Baseline 12 kolom Linux disusun.
- **Status:** Selesai
- **Tindak lanjut:** Gunakan saat Fase 4 menambahkan Linux victim + auditd.

### 23:50 WIB — Verifikasi perbaikan NVIDIA

- **Fase:** Stabilization
- **Aksi:** Memverifikasi hasil update driver NVIDIA.
- **Perintah/artefak:**
  - `nvidia-smi --query-gpu=name,driver_version`
  - `Get-Service NvContainerLocalSystem,NVDisplay.ContainerLocalSystem`
  - `Get-WinEvent` Service Control Manager 2 jam terakhir.
  - Query Wazuh rule 61102/61107 dengan `param1=NVIDIA LocalSystem Container`.
- **Hasil:**
  - Driver: **582.78** (sebelumnya 546.01).
  - `NvContainerLocalSystem` **Running**; `NVDisplay.ContainerLocalSystem` Running.
  - Tidak ada event 7031/7023 dalam 2 jam terakhir.
  - 0 alert NVIDIA baru sejak boot 29 Oktober 10:01.
  - Ribuan alert lama tetap ada sebagai histori.
- **Status:** Resolved
- **Tindak lanjut:** Filter/cleanup alert lama setelah screenshot; monitor rekurensi.

### 23:55 WIB — Tuning dasar 92213 dan 92058

- **Fase:** Tuning
- **Aksi:** Menerapkan rule tuning sempit untuk noise yang sudah diverifikasi benign.
- **Artefak:**
  - `home-lab/wazuh-tuning-rules.xml`
  - `docs/08-TUNING.md`
  - Manager: `/var/ossec/etc/rules/lab_tuning.xml`
- **Rule:**
  - `100210` — suppress 92213 untuk `__PSScriptPolicyTest_*.ps1`.
  - `100211` — suppress 92213 untuk `BackgroundDownload.exe` (Visual Studio Setup Service).
  - `100212` — suppress 92058 untuk `sdbinst.exe` + parent PcaSvc + `-m -bg`.
- **Hasil:**
  - Manager restart sukses; dashboard HTTP 200; agent 000/001 active.
  - Test PowerShell policy: count 92213 `__PSScriptPolicyTest_*` tetap **59 → 59** (tidak ada alert baru).
  - Rule 100211/100212 termuat; belum ada event baru untuk diuji.
  - Catatan: manager log menampilkan warning startup `cp -ar multigroups`; service tetap normal.
- **Status:** Selesai
- **Tindak lanjut:** Monitor 24 jam; review jika ada pola benign baru.

### 23:58 WIB — Hardening tuning (anti-evasion)

- **Fase:** Tuning / security review
- **Aksi:** Mengaudit rule tuning agar tidak bisa dipakai attacker untuk lolos alert.
- **Perubahan:**
  - Hapus `100210` (suppress semua `__PSScriptPolicyTest_*.ps1`); nama file bisa ditiru attacker.
  - Persempit `100211` ke image path Visual Studio Setup Service **dan** target di `AppData\Local\Temp\`.
  - Persempit `100212` ke `System32\sdbinst.exe` + parent `PcaSvc` + `-m -bg`.
- **Hasil:**
  - Test 92213 PowerShell policy: **59 → 60** (alert kembali terlihat).
  - Rule 100211/100212 termuat; dashboard HTTP 200; agent active.
  - Kesimpulan: tidak ada suppression global untuk 92213/92058; pola di luar rule tetap alert.
- **Status:** Selesai
- **Tindak lanjut:** Monitor 24 jam; review jika ada pola benign baru.

---

## 2026-10-30

### 01:20 WIB — Phase 4A: DVWA berjalan

- **Fase:** 4A — Victim container
- **Aksi:** Menyiapkan compose victim dan menjalankan DVWA.
- **Artefak:**
  - `home-lab/phase4/docker-compose.victims.yml`
  - `home-lab/phase4/install-tools.sh`
  - `home-lab/phase4/README.md`
- **Hasil:**
  - Image `vulnerables/web-dvwa` (935 MB) berhasil di-pull.
  - Container `lab-dvwa` Up; port `127.0.0.1:8080->80`.
  - `http://localhost:8080` → HTTP 302 (redirect setup/login).
  - RAM WSL 3,1 Gi dari 5,8 Gi; masih ada ±2,5 Gi available.
  - Tools serangan belum di-install (butuh sudo).
- **Status:** Sebagian (4A target jalan; tools pending)
- **Tindak lanjut:** Jalankan `phase4/install-tools.sh`, setup DVWA, lalu scan awal.

### 01:40 WIB — Dokumentasi deteksi dan availability

- **Fase:** 4A / perencanaan 4B
- **Aksi:** Menjelaskan pipeline deteksi web/Linux, perilaku agent saat manager mati, dan opsi Linux victim.
- **Artefak:** `phase4/README.md` bagian "Deteksi Serangan & Availability".
- **Hasil:**
  - Wazuh + agent di WSL berhenti saat WSL shutdown.
  - Agent di host lain tetap buffer terbatas; bukan SIEM lokal.
  - Opsi victim: container WSL, distro WSL kedua, atau host terpisah.
  - Deteksi web butuh pengiriman log Apache/sidecar agent; deteksi Linux butuh agent + auth.log/auditd.
- **Status:** Selesai (dokumentasi); implementasi deteksi belum
- **Tindak lanjut:** Pilih arsitektur 4B dan mulai pipeline log.

### 01:45 WIB — Perbaiki path wordlist dirb

- **Fase:** 4A — tools
- **Aksi:** Memperbaiki path wordlist yang salah pada perintah ffuf/gobuster.
- **Hasil:**
  - Paket `dirb` terpasang.
  - Wordlist Ubuntu ada di `/usr/share/dirb/wordlists/common.txt`.
  - Path `/usr/share/wordlists/dirb/common.txt` adalah path Kali, tidak ada di Ubuntu.
  - Dokumentasi Phase 4A diperbarui.
- **Status:** Selesai
- **Tindak lanjut:** Jalankan ffuf/gobuster dengan path yang benar.

### 02:05 WIB — Phase 4B Linux victim + agent 003

- **Fase:** 4B — Linux victim
- **Aksi:** Build container Ubuntu victim, sshd, rsyslog, Wazuh agent; enroll ke manager.
- **Artefak:**
  - `phase4/linux-victim/Dockerfile`
  - `phase4/linux-victim/docker-compose.yml`
  - `phase4/linux-victim/ossec.conf`
  - `phase4/linux-victim/entrypoint.sh`
  - `phase4/linux-victim/lab.rules`
- **Hasil:**
  - Agent 002 dihapus saat rebuild; agent baru mendapat **ID 003** (Wazuh tidak memakai ulang ID).
  - Agent 003 `linux-victim` **active**.
  - SSH `127.0.0.1:2222`; user `labuser`/`<LAB_USER_PASSWORD>`.
  - `auth.log` dan `syslog` dibuat oleh rsyslog.
  - Uji hydra wrong password → auth.log tercatat → alert **PAM 5503** di Wazuh.
  - `auditd` gagal di container WSL (`Operation not permitted`); perlu WSL distro/host terpisah untuk auditd.
- **Status:** Sebagian (SSH/FIM/log berjalan; auditd pending)
- **Tindak lanjut:** Uji SSH brute force berulang, sudo, FIM `/etc`; dokumentasikan rule PAM vs sshd.

### 02:15 WIB — Koreksi klaim volume alert

- **Fase:** Dokumentasi
- **Aksi:** Mengoreksi wording agar tidak menyiratkan seluruh ±2.400 alert sudah ditriase.
- **Perubahan:**
  - Judul laporan menjadi “Analisis Volume Alert (Bukan Triage Menyeluruh)”.
  - Ditambahkan daftar sampel yang benar-benar ditriase: 4625/60122, 92213, 92058, FIM 550, 61102/61107 NVIDIA.
  - Lessons learned menegaskan volume ≠ triage.
- **Status:** Selesai
- **Tindak lanjut:** Gunakan wording “volume alert” vs “alert yang ditriase” secara konsisten.

---

## Template Entri

```markdown
### YYYY-MM-DD HH:MM WIB — Judul

- **Fase:**
- **Aksi:**
- **Perintah/artefak:**
- **Hasil:**
- **Status:** Selesai / Sebagian / Pending / Gagal
- **Tindak lanjut:**
```
