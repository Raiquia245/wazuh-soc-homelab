# Home Lab SIEM & SOC Project Report

**Project:** Virtual Home Lab + Wazuh SIEM on a Personal Laptop  
**Author:** Valdez Bentiraz  
**Date:** October 26, 2026  
**Status:** Phases 0–5C complete; project finalized; Phase 6 optional/deferred  
**Environment:** Acer Nitro AN515-52, Windows 11, WSL2 Ubuntu 22.04, Docker, Wazuh 4.14.9

---

## 1. Executive Summary

This project builds a self-contained defensive security lab on a single laptop without additional hardware. The goal is not merely to install a SIEM, but to practice the SOC workflow: collecting endpoint telemetry, validating detections, analyzing alerts, distinguishing false positives from incidents, and documenting the process.

Key results:

- Wazuh 4.14.9 runs as a single-node stack (manager, indexer, dashboard) in Docker within WSL2.
- The Windows 11 host is monitored as the first endpoint using Sysmon and Wazuh agent 001.
- Validated telemetry: Security 4625 (failed logon), Security 4688 (process creation), Sysmon Event ID 1, PowerShell 4104, and FIM rule 550.
- Alert volume analyzed: the majority are low-level from process creation, SCA compliance, and Windows service errors. One level 15 alert proved to be a false positive.
- Real constraints (C: drive, 16 GB RAM, Docker/WSL quirks) were resolved and documented as part of the learning.

---

## 2. Objectives

1. Build a Wazuh SIEM that runs stably on a personal laptop.
2. Send relevant Windows telemetry for detection to Wazuh.
3. Validate that security events actually arrive and trigger rules.
4. Analyze alert volume and false positives.
5. Develop a triage workflow that can be explained in a SOC Analyst interview.
6. Prepare a foundation for attack–detection (purple team) exercises and an ESP32 wireless lab.

## 3. Scope and Ethics

- All testing is performed on my own laptop, VMs/WSL, containers, and AP.
- No scanning or attacks against networks, domains, or devices belonging to others.
- The lab runs locally; dashboard/API are not exposed to the internet.
- Default credentials are not included in portfolio documents and must be rotated before any exposure.
- Brute force testing against real Windows accounts is limited to avoid lockout; the primary practice target is a Linux container.

---

## 4. Architecture

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
|  [Phase 4] victim containers: DVWA / Juice Shop / Ubuntu      |
|  [Phase 4] attack tools in Ubuntu (not a separate Kali)       |
|  [Phase 6] MQTT/syslog bridge for ESP32                       |
+---------------------------------------------------------------+
```

Network notes:

- WSL uses NAT. Dashboard port 443 is published in WSL, but is not automatically opened to the LAN.
- Windows can access the dashboard and agent ports via `localhost` (localhost forwarding).
- Indexer 9200 and API 55000 are bound to `127.0.0.1`.
- Agent enrollment uses port 1515 without a password in this lab.

---

## 5. Hardware and Software Inventory

| Component | Detail |
|---|---|
| Host | Acer Nitro AN515-52 |
| CPU | Intel Core i5-8300H, 4 cores / 8 threads |
| GPU | NVIDIA GeForce GTX 1050 (mobile) 4 GB + Intel UHD Graphics 630 |
| RAM | 16 GB (2 × 8 GB DDR4-2666), 2 slots, max 32 GB |
| Storage | C: 476 GB (±35 GB free), D: 931 GB (±232 GB free) |
| OS | Windows 11 Home Single Language, build 26200 |
| WSL | WSL 3.0.3.0, Ubuntu 22.04.5 LTS, kernel 6.18.54.1 |
| WSL config | 6 GB RAM, 4 vCPU, 4 GB swap on D:, `autoMemoryReclaim=gradual` |
| Docker | Engine 29.9.2, Compose v5.6.1 |
| SIEM | Wazuh 4.14.9 (manager, indexer, dashboard) |
| Endpoint telemetry | Sysmon64 + SwiftOnSecurity config; Wazuh agent 4.14.9 |
| Agent | ID 001, name `LAB-WIN`, status `active` |
| Dashboard | `https://localhost/app/login` |
| API | `https://127.0.0.1:55000` |
| Indexer | `https://127.0.0.1:9200` |

---

## 6. Implementation Summary by Phase

| Phase | Activity | Status |
|---|---|---|
| 0 | Move WSL VHDX to D:, tune RAM/CPU/swap | Complete |
| 1 | Install native Docker Engine + Compose | Complete |
| 2 | Deploy Wazuh single-node 4.14.9 | Complete |
| 3 | Sysmon + Wazuh agent + audit policy + event validation | Complete |
| 4 | Victim containers + attack tools + Linux victim; SWEB log pipeline | Complete (auditd limited) |
| 5 | Attack → detect → triage → tuning cycle | Complete |
| 6 | ESP32 wireless attacker/sensor + log bridge | Optional / deferred |
| 7 | Credential hardening, backup, retention, final portfolio | Partial |

---

## 7. Implementation Details

### 7.1 Phase 0 — WSL Storage and Resources

Initial problems:

- C: had only 18.8 GB free (97% used), while the Ubuntu `ext4.vhdx` was 28 GB on C:.
- WSL by default received only 7.7 GB RAM, below the Wazuh single-node recommendation (8 GB).
- Because the system has no `/dev/kvm`, the lab focused on WSL + Docker rather than a full VM.

Actions:

- `wsl --shutdown`, then `wsl --manage Ubuntu --move D:\WSL\Ubuntu`.
- Enabled sparse VHD.
- Created `C:\Users\analyst\.wslconfig`:

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

- Swap was moved to D: so C: would not fill up again.

Results:

- C: freed from ±19 GB to ±46 GB.
- WSL runs with 6 GB and 4 vCPU; 3.4 GB used when Wazuh is active.
- `autoMemoryReclaim=gradual` helps return page cache to Windows when idle.

Trade-off note:

- 6 GB is below Wazuh's official figure (8 GB), but measured load is only ±3.4 GB. If OOM/container restarts occur, raise it to 7–8 GB.

### 7.2 Phase 1 — Docker Engine

- Installed the official Docker Engine and Compose plugin on Ubuntu WSL.
- Removed leftover Docker Desktop configuration in `~/.docker/config.json` that caused a `docker-credential-desktop.exe` error (backup created).
- Set `vm.max_map_count=262144` so the Wazuh indexer could run.
- Docker data root is on the WSL ext4 (physically on D: after the VHDX was moved).

Validation:

- `docker run --rm hello-world` succeeded.
- `docker info` showed Engine 29.9.2 and data root `/var/lib/docker`.

### 7.3 Phase 2 — Wazuh Single-Node

- Cloned `wazuh-docker` tag `v4.14.9`, ran the single-node stack.
- Certificates generated with `generate-indexer-certs.yml`.
- Dashboard port 443, agent 1514/1515, API 55000, indexer 9200.
- API and indexer bound to `127.0.0.1`; dashboard follows WSL NAT.

Issues and fixes:

1. **Empty certificates** — Docker created the `config/wazuh_indexer_ssl_certs` folder as `root:root` mode `500` on the first bind mount. Fix: create the folder before the generator, regenerate certificates, then start the stack.
2. **Dashboard stuck on `.kibana_1` migration** — the first request timed out because the indexer was still slow at startup, leaving a half-finished index. Fix: delete `.kibana_1`, restart the dashboard; migration completed in ±14 seconds.

Validation:

- Dashboard `https://localhost/app/login` → HTTP 200.
- Indexer cluster `green`.
- Manager processes `running`.
- Agent 000 (manager) active.

### 7.4 Phase 3 — Windows Endpoint Telemetry

Components installed on Windows:

- **Sysmon64** with the SwiftOnSecurity config.
- **Wazuh agent 4.14.9** with manager `127.0.0.1`.
- Agent configuration:
  - Event channels: Security, System, Application, Sysmon/Operational, PowerShell/Operational, TaskScheduler/Operational, Defender/Operational, TerminalServices, WinRM, WMI-Activity, SMBClient.
  - FIM: Startup folder, System32\Tasks, drivers\etc, Desktop, Downloads, registry Run/RunOnce.
  - SCA, rootcheck, syscollector.
- Audit policy:
  - Process Creation + command line.
  - Logon success/failure.
  - PowerShell Script Block Logging (4104).

Issues:

- Agent 001 was briefly `never_connected` after enrollment; this was transient before the first connection. After the first keepalive, the status became `active`.
- `Stop-Service SplunkForwarder` timed out at 120 seconds (event 7011), but the service eventually stopped and StartMode became `Manual`.

Detection validation:

| Test | Event / Rule | Result |
|---|---|---|
| Failed logon `net use \\127.0.0.1\IPC$ /user:fake wrongpass` | Security 4625 → rule 60122 | Success |
| Process creation (notepad/cmd) | Sysmon ID 1 → rule 92031/92032 | Success |
| Process creation audit | Security 4688 → rule 67027 | Success |
| PowerShell activity | 4104 → rule 91815/91816 | Success |
| FIM Windows task change | Rule 550 (`C:\Windows\System32\Tasks\...`) | Success |
| FIM short-lived file in Startup | Rule 550 | Not captured in the short test; FIM proven working via Tasks |

---

## 8. Alert Volume Analysis (Not Full Triage)

Snapshot October 26, 2026 ±12:42 WIB:

- Agent 001: ±2,167 alerts.
- Agent 000 (manager): 219 alerts.
- Total approximately 2,400 alerts, mostly low level.

**Important clarification:** this number is the **alert volume indexed**, not the number of alerts that have been triaged. Actual triage was performed only on a representative sample: 4625/60122, 92213, 92058, FIM 550, and 61102/61107 NVIDIA. Other low-level alerts have not been triaged individually.

Level distribution (snapshot):

| Level | Category | Count |
|---:|---|---:|
| 3 | Low | ±1,343 |
| 4 | Medium-low | ±122 |
| 5 | Medium | ±316 |
| 7 | Medium | ±353 |
| 9 | High | ±23 |
| 10 | High | ±24 |
| 12 | Critical | 1 |
| 15 | Critical | 9 |

Top rules:

| Rule | Count | Source / Meaning |
|---|---:|---|
| 67027 | 944 | Security 4688 process creation |
| 19007 | 347 | SCA CIS Windows 11 (compliance) |
| 61102 | 168 | Windows System error events |
| 61107 | 146 | Windows System error events |
| 19008 | 126 | SCA CIS Windows 11 (compliance) |
| 92032 | 114 | Sysmon process-related rule |
| 92031 | 64 | Sysmon discovery activity |
| 92052 | 60 | Sysmon rule |
| 92036 | 58 | Sysmon `net.exe` from cmd |
| 61110 | 24 | Multiple System error events (NVIDIA noise) |
| 92213 | 9 | Executable dropped in malware folder |

Interpretation:

1. **Alert ≠ incident.** Most are normal telemetry matching low-level rules.
2. **Process creation duplication.** 4688 (67027) and Sysmon (92031/92032) both record processes. This adds volume.
3. **SCA is not an incident.** 19007/19008 are CIS compliance findings, not attacks.
4. **NVIDIA service crash loop.** 61102/61107/61110 come from `NvContainerLocalSystem` crashing repeatedly. The log `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log` shows the mandatory plugin `NvPluginWatchdog` failing to initialize and the container exiting with exit code `14109`. Windows Service Control Manager records event 7031 (service terminated unexpectedly) and 7023 (service terminated with error), then performs a recovery restart. This is an operational/driver issue (driver 546.01 on Windows build 26200), not an attack. In the initial snapshot there were 518 NVIDIA alerts (258 rule 61102, 224 rule 61107, 36 rule 61110); because the crash loop continued, the count rose to **9,991** in the next snapshot. The plugin log also shows the `MessageBus.dll` dependency failing and several plugins (`_NvMdnsPlugin.dll`, `_NvStreamControl.dll`, `_IdentityPlugin.dll`) error 126, along with `NvPluginWatchdog` failing to initialize. The recovery program run by Windows is `C:\Windows\NvContainerRecovery.bat`; this file was verified legitimate (only registry recovery + `net start`, normal ACL, SHA256 `10102167...CA76`), not persistence. The recovery log also shows `net start` failing with error 14109. **Fix:** driver updated to **582.78**; `NvContainerLocalSystem` is now `Running`; no 7031/7023 events or new NVIDIA alerts since the October 29 10:01 boot. The thousands of old alerts remain as history.
5. **Level 15 false positive.** Rule 92213 flags `__PSScriptPolicyTest_*.ps1` in `AppData\Local\Temp` created by `powershell.exe`. This file is PowerShell's internal test when checking execution policy, not malware. In the October 29 snapshot, rule 92213 reached 457 alerts: 407 from Visual Studio Setup Service (`BackgroundDownload.exe`), 41 from PowerShell policy tests, the rest from Opera GX/BingSvc/installer updaters. This shows rule 92213 is very broad and needs tuning based on parent process/target file, not global suppression.
6. **One failed logon** from the `net use` test triggered 60122; a single failure is not necessarily an incident; frequency and source context are needed.

---

## 9. Alert Management Workflow

Wazuh 4.x has no per-alert status or native case management. Alerts are immutable. Therefore, triage status must be managed outside the SIEM.

Recommended flow:

1. Filter the queue: `rule.level >= 7`, last 24 hours.
2. Discard non-incident categories: SCA, known service errors, level 3 process creation rules.
3. Deduplicate by rule + agent + user/source IP + time window.
4. Create a case in an external tracker and store the Wazuh alert `_id`.
5. Enrichment: parent process, hash, signer, user, path, reputation, asset criticality.
6. Determine disposition: True Positive, False Positive, Benign, Duplicate.
7. Escalate/act or close.
8. Tuning: suppression, threshold, frequency rule, or configuration fix.

Triage details and example cases are in `06-LAB-JOURNAL.md` and `triage-cases.csv`.

---

## 10. Issues and Resolution

| # | Issue | Impact | Resolution |
|---:|---|---|---|
| 1 | C: nearly full, VHDX on C: | Wazuh would not fit | Move VHDX to D:, sparse VHD |
| 2 | WSL only 7.7 GB | Below Wazuh recommendation | Raise the limit, then lower to 6 GB after analysis |
| 3 | `docker-credential-desktop.exe` | Image pull failed | Remove `credsStore` from `~/.docker/config.json` |
| 4 | Wazuh certificates empty | Stack could not start | Create the cert folder before the generator, regenerate |
| 5 | Dashboard stuck on `.kibana_1` migration | Dashboard 503 | Delete the half-finished index, restart the dashboard |
| 6 | Host 92–94% RAM | Lag | Disable non-essential services/startup, close Chrome, limit WSL, autoMemoryReclaim |
| 7 | SplunkForwarder stop timeout | Slow stop process | Service still stopped; StartMode Manual |
| 8 | Agent `never_connected` | Appeared failed | Transient; became active after the first connection |
| 9 | FIM Startup file not captured | FIM test appeared to fail | FIM proven working via rule 550 on Tasks; short file test needs better timing |
| 10 | Wazuh API config query timeout | FIM investigation via API failed | Retry when the manager is idle; use logs/alternative query |
| 11 | NVIDIA `NvContainerLocalSystem` crash loop | Thousands of noise alerts; repeated service restarts | **Resolved:** update driver to 582.78; service Running; 0 new alerts since boot |

---

## 11. Security and Limitations

### Security

- Dashboard/API/indexer only for localhost/NAT; no port forwarding to the internet.
- Indexer and API bound to `127.0.0.1`.
- Lab default credentials are **not written** in this document; rotation has not been performed.
- Agent enrollment uses `use_password=no`; port 1515 is only reachable locally. If mirrored networking or exposure is used later, enable the enrollment password.
- Demo indexer users (`kibanaro`, `logstash`, `readall`, `snapshotrestore`) are still active with default passwords and should be disabled.
- The `docker` group in WSL is equivalent to root; do not add untrusted users.
- Agent keys in `client.keys` are secrets; do not publish them.

### Limitations

- 16 GB RAM is the main constraint. 6 GB for WSL is a trade-off; if Wazuh OOMs, raise it to 7–8 GB.
- No KVM, so the lab does not use full VMs.
- WSL2 is not identical to a production server; network and I/O behavior differ.
- No NIDS (Suricata/Zeek), no Linux victim, no ESP32 yet.
- Alert volume is still high; tuning is only partial.
- Screenshots are available in `docs/screenshots/` (redacted for privacy).

---

## 12. Roadmap

### Short term

1. Alert tuning:
   - Keep 92213 PowerShell policy-test alerts visible; only narrow 92213 for the verified VS Setup Service pattern.
   - Keep NVIDIA service alerts active; the crash loop was fixed with driver 582.78.
   - Separate SCA 19007/19008 into a compliance view.
   - Decide between 67027 vs Sysmon to reduce duplication.
2. Use the case tracker (`triage-cases.csv`).
3. Re-validate FIM with a longer-lived file.

### Phase 4 — Victim and Attack Tools (complete)

- **DVWA** runs at `127.0.0.1:8080`; Apache logs are forwarded by sidecar agent 005.
- Linux victim runs at `127.0.0.1:2222` with sshd, rsyslog, FIM, and agent 004.
- Tools: nmap, hydra, sqlmap, nikto, ffuf, gobuster, impacket, netexec; Metasploit on demand.
- `auditd` is not usable inside the WSL container; a second WSL distro or separate host is required.

### Phase 5 — Attack → Detect → Triage (complete)

- SSH brute force → rules 5503/2502; FIM persistence → 554/550; sudo failure → 5401.
- DVWA scans → 31101/31151; SQLi attempt → 31103; successful web attack (HTTP 200) → 31106; XSS → 31105; Nikto UA → 31508.
- Successful UNION SQLi validation returned HTTP 200/5500 bytes with user/password data; Wazuh fired 31106. Response body is not parsed by Wazuh, so data-extraction proof comes from the application response.
- Web tuning: 100230 was removed because it suppressed an authorized attack; 100231 remains for benign cache FIM.
- MITRE ATT&CK and case documentation are included.

### Phase 6 — ESP32 (optional/deferred)

- Would add wireless deauth/evil-twin/rogue-AP simulation, BLE HID/BadUSB, and IoT MQTT telemetry.
- Wazuh does not natively parse 802.11 frames; this phase would require an ESP32 sensor and MQTT/syslog bridge.
- Deferred because the host/OS/web lab already covers the core SOC workflow.

### Hardening

- Rotate admin, kibanaserver, wazuh-wui passwords.
- Disable demo indexer users.
- Enable enrollment password if port 1515 is exposed.
- Back up configuration and volumes; 7–14 day index retention.
- Upgrade RAM to 2×16 GB DDR4-2666.

---

## 13. Evidence to Capture for the Portfolio

- Screenshot of dashboard overview and agent 001 `active`.
- Screenshot of alert 4625 details (rule 60122).
- Screenshot of Sysmon Event ID 1 (rule 92031/92032).
- Screenshot of PowerShell 4104.
- Screenshot of FIM rule 550.
- Screenshot of alert 92213 with false positive analysis.
- Screenshot of MITRE ATT&CK dashboard.
- Screenshot of `docker compose ps` and `free -h`.
- Keep sanitized configuration files (without passwords/keys).

---

## 14. References

- Wazuh Documentation — Docker deployment, agent configuration, rules.
- Microsoft Sysinternals — Sysmon.
- SwiftOnSecurity — sysmon-config.
- Microsoft — WSL configuration (`.wslconfig`), memory reclaim.
- MITRE ATT&CK — techniques and tactics.
- OpenSearch — indexer, security plugin.

---

## 15. Lessons Summary

Details are in [03-LESSONS-LEARNED.md](03-LESSONS-LEARNED.md). Key points:

- RAM and disk capacity must be planned before deploying a SIEM.
- Understanding the difference between events, alerts, and incidents is a core SOC skill.
- High severity still requires context validation.
- False positives should produce tuning, not just be closed.
- Alert management is a combination of process, ticketing, and tuning—not just a SIEM feature.
- Documentation and evidence are part of SOC work, not an add-on.
