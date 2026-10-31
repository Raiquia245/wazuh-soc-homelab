# Home Lab SIEM & SOC — Wazuh

Lab keamanan defensif mandiri di laptop pribadi: Wazuh SIEM di WSL2/Docker, endpoint Windows (Sysmon + Wazuh agent), dan Linux victim container (SSH, rsyslog, FIM).

## Status

- Wazuh 4.14.9 single-node berjalan.
- Agent Windows 001 dan Linux victim 003 `active`.
- Phase 0–3 selesai; Phase 4A (DVWA) dan 4B (Linux victim) berjalan.
- NVIDIA `NvContainerLocalSystem` crash loop sudah diperbaiki dengan driver 582.78.
- Tuning sempit untuk noise 92213/92058; tidak ada suppression global.

## Dokumentasi

- [docs/README.md](docs/README.md) — indeks dokumentasi.
- [docs/01-PROJECT-REPORT.md](docs/01-PROJECT-REPORT.md) — laporan lengkap.
- [docs/02-ACTIVITY-TRACKING.md](docs/02-ACTIVITY-TRACKING.md) — tracking aktivitas.
- [docs/03-LESSONS-LEARNED.md](docs/03-LESSONS-LEARNED.md) — lessons learned.
- [docs/06-LAB-JOURNAL.md](docs/06-LAB-JOURNAL.md) — jurnal kronologis.
- [docs/08-TUNING.md](docs/08-TUNING.md) — catatan tuning rule.

## Privasi

- Hostname, username, dan nama agent Windows sudah disamarkan (`LAB-WIN`, `analyst`).
- Screenshot di `docs/screenshots/` sudah diredaksi (hostname, username, API ID).
- Original screenshot mentah disimpan **di luar repo**.
- Credential lab diganti placeholder; secret lokal ada di `.env` yang di-gitignore.
- Jangan commit `.env`, `client.keys`, `*.pem`, atau screenshot original.

## Struktur

```text
home-lab/
├─ docs/                 # laporan, tracking, jurnal, screenshot redacted
├─ phase4/               # victim container, Linux victim, tools
├─ phase0-windows.ps1    # disk/WSL tuning
├─ phase1-docker.sh      # Docker Engine
├─ phase2-wazuh.sh       # Wazuh single-node
├─ phase3-*.{ps1,sh,conf}# Sysmon + Wazuh agent
└─ wazuh-tuning-rules.xml
```
