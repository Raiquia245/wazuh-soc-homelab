# Home Lab Activity Tracking

**Project:** Wazuh SIEM + SOC Home Lab  
**Period:** October 25–26, 2026  
**Status:** Phases 0–5C complete; Phase 6 pending

> Full chronological journal: [06-LAB-JOURNAL.md](06-LAB-JOURNAL.md). Every technical action is recorded there.

---

## 1. Chronological Log

| Date | Phase | Activity | Artifacts / Commands | Result | Status |
|---|---|---|---|---|---|
| 2026-10-25 | Inventory | Check OS, CPU, RAM, disk, Docker, virtualization, tools | `free -h`, `df -h`, `docker --version`, `/dev/kvm` | 16 GB RAM, C: 18.8 GB free, VHDX 28 GB on C:, Docker Desktop installed but stopped | Complete |
| 2026-10-25 | 0 | Move Ubuntu VHDX to D: | `wsl --manage Ubuntu --move D:\WSL\Ubuntu` | VHDX on D:, C: freed ±28 GB | Complete |
| 2026-10-25 | 0 | Tune WSL | `.wslconfig`: memory 10→8→6 GB, 4 vCPU, 4 GB swap on D:, autoMemoryReclaim | WSL 6 GB, 4 vCPU | Complete |
| 2026-10-25 | 1 | Install Docker Engine + Compose | `phase1-docker.sh` | Docker 29.9.2, Compose 5.6.1 | Complete |
| 2026-10-25 | 1 | Fix credential helper error | Remove `credsStore` from `~/.docker/config.json` (backup) | `hello-world` succeeded | Complete |
| 2026-10-25 | 1 | Set `vm.max_map_count` | `sysctl -w vm.max_map_count=262144` + persist | Value 262144 | Complete |
| 2026-10-25 | 2 | Clone and configure Wazuh | `phase2-wazuh.sh`, tag `v4.14.9` | Repo at `~/wazuh-lab/wazuh-docker` | Complete |
| 2026-10-25 | 2 | Fix empty certificates | Create `config/wazuh_indexer_ssl_certs`, regenerate certs | 12 complete cert files | Complete |
| 2026-10-25 | 2 | Fix dashboard stuck on `.kibana_1` | Delete index, restart dashboard | Migration completed ±14 seconds, dashboard HTTP 200 | Complete |
| 2026-10-25 | 2 | Validate stack | `docker compose ps`, cluster health, API | Manager/indexer/dashboard up, cluster `green`, agent 000 active | Complete |
| 2026-10-26 | Resource | Analyze host RAM | Task Manager, `vmmemWSL`, `Get-Process` | Host 92–94%, vmmemWSL ±7.6 GB, high Windows baseline | Complete |
| 2026-10-26 | Resource | Disable non-essential services/startup | `Set-Service ... Manual`, `Stop-Service` | CCleaner, SQL, MySQL, PostgreSQL, Splunkd, SplunkForwarder stopped/Manual | Complete |
| 2026-10-26 | Resource | Reduce WSL to 6 GB + auto reclaim | `.wslconfig` | WSL 5.8 Gi; host free ±2.1 GB | Complete |
| 2026-10-26 | 3 | Create Sysmon + agent scripts | `phase3-windows.ps1`, `phase3-ossec.conf`, `phase3-verify.sh` | Scripts syntactically valid | Complete |
| 2026-10-26 | 3 | Install Sysmon + Wazuh agent | Run `phase3-windows.ps1` (UAC) | Sysmon64 Running, WazuhSvc Running | Complete |
| 2026-10-26 | 3 | Agent enrollment | Agent 001 `LAB-WIN` | Briefly `never_connected`, then `active` | Complete |
| 2026-10-26 | 3 | Failed logon test | `net use \\127.0.0.1\IPC$ /user:fake wrongpass` | Security 4625 → rule 60122 | Complete |
| 2026-10-26 | 3 | Process creation test | `notepad.exe`, `cmd`, PowerShell | Sysmon ID 1 → 92031/92032; 4688 → 67027 | Complete |
| 2026-10-26 | 3 | PowerShell 4104 test | Script block logging | Rule 91815/91816 | Complete |
| 2026-10-26 | 3 | FIM test | File in Startup; Tasks change | Rule 550 on Tasks; short-lived Startup file not captured | Partial |
| 2026-10-26 | Analysis | Alert volume analysis | Indexer aggregation | ±2,167 alerts agent 001, 219 manager; mostly level 3–7; **not full triage** | Complete |
| 2026-10-26 | Analysis | False positive analysis | Alert 92213 details | `__PSScriptPolicyTest_*.ps1` by PowerShell = FP | Complete |
| 2026-10-26 | Analysis | NVIDIA alert investigation | `NvContainerLocalSystem.log`, Event 7031/7023, `Get-Service *Nv*` | `NvContainerLocalSystem` crash loop; `NvPluginWatchdog` failed; exit 14109 | Complete |
| 2026-10-27 | Analysis | Verify NVIDIA recovery program | `sc qfailure`, contents of `NvContainerRecovery.bat`, ACL, hash, recovery log | Program legitimate; `net start` failed 14109; not persistence | Complete |
| 2026-10-27 | Analysis | Audit NVIDIA installation | Uninstall registry, `Test-Path`, NvContainer log, alert count | Driver 546.01; GFE 3.28; plugin dependency error 126; NVIDIA alerts 9,991 | Complete |
| 2026-10-27 | Inventory | Verify GPU model | `Win32_VideoController`, `nvidia-smi --query-gpu` | NVIDIA GTX 1050 4 GB mobile, not 1050 Ti; Intel UHD 630 | Complete |
| 2026-10-29 | Fix | Update NVIDIA driver | Install driver 582.78 | Service Running; 0 events 7031/7023 within 2 hours; 0 new alerts since boot | Complete |
| 2026-10-29 | Tuning | Apply `lab_tuning.xml` | Rules 100211–100212; 100210 removed during hardening | Test 92213 PowerShell: 59 → 60 (still visible); dashboard 200; agent active | Complete |
| 2026-10-30 | 4A | Run DVWA | `docker compose --profile dvwa up -d` | `lab-dvwa` Up, `127.0.0.1:8080`, HTTP 302 | Complete |
| 2026-10-30 | 4B | Build Linux victim + Wazuh agent | `linux-victim/docker-compose.yml`, `Dockerfile` | `lab-linux-victim` Up, SSH 2222, agent **003 active** | Complete |
| 2026-10-30 | 4B | SSH + auth log test | `hydra -l labuser -p wrongpass ssh://127.0.0.1:2222` | auth.log recorded; PAM alert 5503 | Complete |
| 2026-10-31 | 4C | Restart lab + rebuild agent | Docker/Wazuh, Linux victim, DVWA | Agent 004 active; DVWA/Linux victim up | Complete |
| 2026-10-31 | 4C | Linux FIM test | `touch /etc/lab-fim-test-2` | Rule 554 File added | Complete |
| 2026-10-31 | 4C | SSH failed login test | `sshpass`/hydra wrong password | Rule 5503 PAM login failed | Complete |
| 2026-10-31 | 5A | SSH brute force 10 attempts | hydra password list | Rules 5503/2502 | Complete |
| 2026-10-31 | 5A | FIM cron persistence | `/etc/cron.d/lab-phase5` | Rules 554/550 | Complete |
| 2026-10-31 | 5A | Sudo failure | SSH admin + wrong sudo password | Rule 5401 | Complete |
| 2026-10-31 | 5A | DVWA web scan | nmap/nikto/ffuf | No web alerts; Apache log not yet shipped | Gap |
| 2026-10-31 | 5B | Apache log pipeline | `dvwa-logs` volume + agent 005 sidecar | Web alerts 31101/31151/31103/31105 | Complete |
| 2026-10-31 | 5C | Tune web scan noise | 100230 removed; 100231 kept | 31101 active 737 → 738; 31508/31103/31105 remain | Complete |
| 2026-10-26 | Documentation | Report, tracking, lessons, triage template, SIEM comparison | `docs/` folder | Documents created | Complete |

---

## 2. Checklist

### Complete

- [x] Hardware/software inventory.
- [x] Move WSL VHDX to D: and enable sparse VHD.
- [x] Tune WSL RAM/CPU/swap.
- [x] Install Docker Engine + Compose.
- [x] Fix leftover Docker Desktop configuration.
- [x] Deploy Wazuh 4.14.9 single-node.
- [x] Fix certificate generation.
- [x] Fix dashboard `.kibana_1` migration.
- [x] Dashboard, API, indexer validated.
- [x] Agents 000 and 001 active.
- [x] Sysmon64 + SwiftOnSecurity config.
- [x] Wazuh agent 4.14.9 + custom `ossec.conf`.
- [x] Audit Process Creation + command line.
- [x] Audit Logon success/failure.
- [x] PowerShell Script Block Logging.
- [x] Validate 4625, 4688, Sysmon ID 1, 4104, FIM 550.
- [x] Alert volume and false positive analysis.
- [x] Report/tracking/lessons/triage documentation.

### In progress / needs completion

- [x] Initial tuning of 92213/92058 with narrow rules; 92213 PowerShell still visible.
- [x] Phase 4A: DVWA container running at `127.0.0.1:8080`.
- [ ] Phase 4A: install attack tools in Ubuntu.
- [ ] Phase 4A: Juice Shop.
- [x] Phase 4B: Linux victim container + SSH + rsyslog + Wazuh agent.
- [x] Phase 4C: FIM rule 554 and SSH failed login PAM 5503 validated.
- [x] Phase 5A: SSH brute force, FIM persistence, sudo failure validated.
- [x] Phase 5B: DVWA Apache logs shipped to Wazuh; SQLi/XSS/scan alerts validated.
- [ ] Phase 4C: auditd (not supported in WSL containers; needs a separate distro/host).
- [ ] Filter/clean up old NVIDIA alerts after screenshots.
- [ ] Separate SCA 19007/19008 into a compliance dashboard.
- [ ] Decide whether to suppress 67027 (4688 vs Sysmon duplicate).
- [ ] Validate FIM with a longer-lived file.
- [ ] Create an active case tracker (CSV → Notion/Jira).
- [ ] Screenshot evidence for the portfolio.
- [ ] Rotate default credentials.
- [ ] Disable demo indexer users.
- [ ] Back up configuration and volumes.

### Not started

- [ ] Phase 4B: Linux victim/auditd (continued).
- [ ] Phase 5: attack → detect → triage → tuning.
- [ ] Phase 6: ESP32 attacker/sensor + MQTT/syslog bridge.
- [ ] NIDS Suricata/Zeek (optional).
- [ ] RAM upgrade 2×16 GB.

---

## 3. Open Issues

| # | Issue | Impact | Plan |
|---:|---|---|---|
| 1 | Short-lived Startup FIM file not captured | FIM test appeared to fail | FIM proven via Tasks; retest with a file lasting >1 minute |
| 2 | Wazuh API config query timeout | Cannot retrieve the effective agent config | Retry when the manager is idle; check `api.log` |
| 3 | 6 GB WSL below the official recommendation | OOM risk as load rises | Monitor `docker stats`; raise to 7–8 GB if needed |
| 4 | High alert volume | Alert fatigue | Rule tuning, dashboard filters, case tracker |
| 5 | Default credentials | Risk if exposed | Rotate + disable demo users + enrollment password |
| 6 | Host free ±2.1 GB | Still tight | Close heavy apps; consider a 32 GB upgrade |
| 7 | No backup yet | Risk of losing configuration | Export WSL + back up compose/volumes |
| 8 | NVIDIA `NvContainerLocalSystem` crash loop | Thousands of old alerts; 0 new alerts since the fix | **Resolved:** driver 582.78; service Running; old alerts can be filtered/cleaned after screenshots |

---

## 4. Important Configuration Changes

| Item | Before | After | Reason |
|---|---|---|---|
| VHDX location | C: (`Packages\...\LocalState`) | D:\WSL\Ubuntu | C: full |
| WSL memory | 7.7 GB (default) | 6 GB | 16 GB host, Wazuh actual ±3.4 GB |
| WSL CPU | 8 threads | 4 vCPU | Leave resources for Windows |
| Swap | Default on C: | 4 GB on D: | C: full |
| Auto reclaim | None | `autoMemoryReclaim=gradual` | Return cache to Windows |
| Docker | Docker Desktop (stopped) | Native Docker Engine | Lighter, data on ext4 |
| Agent manager | — | `127.0.0.1:1514` | WSL localhost forwarding |
| Enrollment | — | `1515`, no password | Local lab |
| Audit | Default | Process Creation + Logon + Script Block | Detection telemetry |
| Sysmon config | — | SwiftOnSecurity | Process/file/network telemetry |

---

## 5. Command Reference

### Lab operations

```bash
# Start full Wazuh
bash ~/wazuh-lab/up.sh

# Start without dashboard (save RAM)
bash ~/wazuh-lab/up.sh --no-dashboard

# Stop containers
bash ~/wazuh-lab/down.sh

# Status
cd ~/wazuh-lab/wazuh-docker/single-node
docker compose ps
docker stats --no-stream
```

### Agent and alert verification

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
# 10 latest alerts for agent 001
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

## 6. Paths and Artifacts

| Path | Contents |
|---|---|
| `D:\Portofolio\CyberSecurity\home-lab\` | Phase 0–3 scripts |
| `D:\Portofolio\CyberSecurity\home-lab\docs\` | Portfolio documentation |
| `~/wazuh-lab/wazuh-docker\` | Wazuh repo and compose |
| `~/wazuh-lab/up.sh`, `down.sh` | Operations |
| `D:\lab-tools\` | Sysmon installer, Wazuh MSI, config, logs |
| `D:\lab-tools\phase3-install.log` | Endpoint installation log |
| `C:\Program Files (x86)\ossec-agent\` | Agent, config, log, client.keys |
| `D:\WSL\Ubuntu\ext4.vhdx` | Ubuntu disk |
| `D:\WSL\swap.vhdx` | WSL swap |

---

## 7. Next Actions

High priority:

1. Fix the NVIDIA crash loop (`NvContainerLocalSystem`) — update/clean install the driver.
2. Tune the 92213 false positive and 61110/NVIDIA noise after the root cause is understood.
3. Create a case tracker and fill in example cases.
4. Capture screenshot evidence.
5. Start Phase 4: DVWA/Juice Shop + tools.

Medium priority:

5. Linux victim + auditd + agent.
6. Suricata/Zeek (optional).
7. Credential hardening.
8. Backup.

Long-term priority:

9. Targeted attacks + purple team loop.
10. ESP32 attacker/sensor.
11. 32 GB RAM upgrade.
