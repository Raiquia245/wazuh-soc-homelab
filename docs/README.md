# Home Lab SIEM & SOC — Wazuh on WSL2

Portfolio documentation for a self-hosted defensive security lab built on a personal laptop: Wazuh SIEM, Windows endpoint telemetry (Sysmon + Wazuh agent), WSL2, Docker, a Linux victim, and a DVWA web target with Apache log forwarding.

## Status

| Item | Value |
|---|---|
| Date | 31 October 2026 |
| Completed phases | 0–3, 4A, 4B, 4C, 5A, 5B, 5C |
| Host | Acer Nitro AN515-52, i5-8300H, 16 GB RAM, Windows 11 |
| SIEM | Wazuh 4.14.9 (manager, indexer, dashboard) |
| Endpoints | Windows 11 agent 001; Linux victim agent 004; DVWA web agent 005 |
| Agent status | `active` |
| Validated telemetry | Security 4625/4688, Sysmon ID 1, PowerShell 4104, FIM 550/554, SSH PAM 5503/2502, sudo 5401, web 31101/31151/31103/31105 |
| Project status | Finalized; Phase 6 (ESP32) optional/deferred |

## Documents

| File | Content |
|---|---|
| [01-PROJECT-REPORT.md](01-PROJECT-REPORT.md) | Full report: goals, architecture, implementation, validation, alert analysis, issues, security, roadmap |
| [02-ACTIVITY-TRACKING.md](02-ACTIVITY-TRACKING.md) | Chronological log, checklist, open issues, command reference |
| [03-LESSONS-LEARNED.md](03-LESSONS-LEARNED.md) | Technical and SOC lessons learned |
| [06-LAB-JOURNAL.md](06-LAB-JOURNAL.md) | Chronological lab journal |
| [NVIDIA-ISSUE-BRIEF.md](NVIDIA-ISSUE-BRIEF.md) | NVIDIA NvContainer incident brief and evidence |
| [08-TUNING.md](08-TUNING.md) | Tuning rules, risk analysis, and application status |
| [triage-cases.csv](triage-cases.csv) | Case tracker template |

## Journaling Policy

Every technical action (installation, configuration change, troubleshooting, testing) is recorded in [06-LAB-JOURNAL.md](06-LAB-JOURNAL.md). The checklist summary is in [02-ACTIVITY-TRACKING.md](02-ACTIVITY-TRACKING.md).

## Notes

- All testing is performed on hardware owned by the author.
- Lab credentials are not published; local values are stored in a gitignored `.env`.
- The WSL instance runs with 6 GB RAM / 4 vCPU because the host has 16 GB.
- All core project documents are in English.
