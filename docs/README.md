# Home Lab SIEM & SOC — Wazuh on WSL2

Dokumentasi portofolio lab keamanan defensif yang dijalankan sepenuhnya di laptop sendiri: Wazuh SIEM, Windows endpoint telemetry (Sysmon + Wazuh agent), WSL2, dan Docker.

## Status

| Item | Nilai |
|---|---|
| Tanggal | 31 Oktober 2026 |
| Fase selesai | Fase 0–3, 4A, 4B |
| Host | Acer Nitro AN515-52, i5-8300H, 16 GB RAM, Windows 11 |
| SIEM | Wazuh 4.14.9 (manager, indexer, dashboard) |
| Endpoint | Windows 11 + Sysmon64 + agent 001; Linux victim agent 003 |
| Status agent | `active` |
| Telemetri tervalidasi | Security 4625, 4688, Sysmon ID 1, PowerShell 4104, FIM rule 550 |
| Fase berikutnya | Phase 5 attack/detect/triage, ESP32 wireless lab |

## Dokumen

| File | Isi |
|---|---|
| [01-PROJECT-REPORT.md](01-PROJECT-REPORT.md) | Laporan lengkap: tujuan, arsitektur, implementasi, validasi, analisis alert, kendala, keamanan, roadmap |
| [02-ACTIVITY-TRACKING.md](02-ACTIVITY-TRACKING.md) | Log kronologis, checklist, open issues, command references |
| [03-LESSONS-LEARNED.md](03-LESSONS-LEARNED.md) | Pelajaran teknis dan SOC yang didapat |
| [06-LAB-JOURNAL.md](06-LAB-JOURNAL.md) | Jurnal kronologis setiap aksi teknis |
| [NVIDIA-ISSUE-BRIEF.md](NVIDIA-ISSUE-BRIEF.md) | Brief handoff masalah NvContainer + bukti untuk second opinion |
| [08-TUNING.md](08-TUNING.md) | Catatan rule tuning 92213/92058, risiko, dan status penerapan |
| [triage-cases.csv](triage-cases.csv) | Template case tracker |

## Kebijakan Jurnal

Setiap tindakan teknis (instalasi, perubahan konfigurasi, troubleshooting, pengujian) dicatat di [06-LAB-JOURNAL.md](06-LAB-JOURNAL.md). Ringkasan checklist ada di [02-ACTIVITY-TRACKING.md](02-ACTIVITY-TRACKING.md).

## Catatan

- Semua pengujian dilakukan pada perangkat sendiri dan tidak menyentuh jaringan pihak lain.
- Kredensial default lab sengaja **tidak ditulis** di dokumen portofolio ini. Nilainya ada di konfigurasi lokal (`~/wazuh-lab/...`) dan harus dirotasi sebelum diekspos.
- Lab berjalan dengan WSL 6 GB / 4 vCPU; ini trade-off karena host hanya 16 GB. Lihat bagian batasan di laporan.
