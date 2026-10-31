# Tuning Record — Rule 92213 dan 92058

**Status:** Diterapkan 29 Oktober 2026, lalu di-hardening pada hari yang sama.  
**File rule:** `home-lab/wazuh-tuning-rules.xml`  
**Lokasi manager:** `/var/ossec/etc/rules/lab_tuning.xml`

## Rule Aktif

| Rule | Parent | Pola | Aksi | Alasan |
|---|---|---|---|---|
| `100211` | `92213` | `image` = path Visual Studio Setup Service `BackgroundDownload.exe` dan target di `AppData\Local\Temp\` | level 0 | Visual Studio Setup Service menulis file sementara di Temp |
| `100212` | `92058` | `System32\sdbinst.exe` + parent `PcaSvc` + command `-m -bg` | level 0 | Maintenance database kompatibilitas Windows oleh PcaSvc |

## Yang Tidak Di-suppress

- Seluruh rule `92213` dan `92058` tidak dimatikan.
- `92213` untuk `__PSScriptPolicyTest_*.ps1` sengaja dibiarkan terlihat agar tidak bisa dipakai evasion.
- `61102/61107/61110` NVIDIA tidak disuppress; driver sudah diperbaiki dan rekurensi tetap terdeteksi.
- `67027` (process creation 4688) tetap aktif untuk hunting.

## Analisis Risiko

- Rule `100210` (suppress semua `__PSScriptPolicyTest_*.ps1`) dihapus karena nama file bisa ditiru attacker.
- `100211` dipersempit ke image path dan target path tertentu; bukan semua file dari proses bernama `BackgroundDownload.exe`.
- `100212` hanya match command maintenance PcaSvc; penggunaan `sdbinst` dengan `.sdb` custom tidak match dan tetap alert.
- Deteksi process creation/network Sysmon tetap aktif; suppression hanya pada file-create untuk pola tertentu.

## Status Uji

- Test 92213 PowerShell policy setelah hardening: count **59 → 60**; alert kembali terlihat.
- Dashboard HTTP 200; agent 000/001/003 active.
- Rule `100211`/`100212` termuat; belum ada event baru untuk diuji ulang.

## Catatan

- Alert lama tidak dihapus.
- Tuning direview berkala; jangan menutupi deteksi baru.
- Perubahan aturan dan hasil test dicatat di `06-LAB-JOURNAL.md`.

## Observasi Phase 5A

- SSH brute force terdeteksi sebagai **PAM 5503** dan **syslog 2502**, bukan rule sshd 5710/5712. Ini cukup untuk mendeteksi brute force, tetapi decoder bisa dituning jika ingin rule sshd standar.
- FIM `/home/*/.cache` memunculkan noise saat login; pertimbangkan ignore khusus cache.
- Sudo failure terdeteksi rule **5401**.
- Web attack belum terdeteksi karena Apache log DVWA belum dikirim ke Wazuh; ini gap Phase 5B.

## Phase 5B Web Pipeline

- Apache logs are shipped by sidecar agent 005 from a shared Docker volume.
- Scan activity generates many 31101 alerts; rule 31151 aggregates repeated 400 errors.
- SQLi (31103) and XSS (31105) must not be suppressed.
- Tuning direction: aggregate/filter scanner noise by source IP/time window, not by disabling web rules.
