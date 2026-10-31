# Lab Journal

Chronological journal of all technical actions in the home lab. Each entry records the time, action, commands/artifacts, results, and status. Credentials and keys are not written here.


> Note: some tutorial files referenced in older entries (`04`, `05`, `07`, `SCREENSHOT-GUIDE`, `phase4/README`) have been deleted. Those references are history, not active files.

## Logging Policy

- Every configuration change, installation, troubleshooting step, and test is recorded.
- Format: date/time, phase, action, commands/artifacts, result, status.
- Status: `Complete`, `Partial`, `Pending`, `Failed`.
- After a new entry, the checklist summary in `02-ACTIVITY-TRACKING.md` is updated if necessary.
- Screenshots/evidence are stored in `docs/screenshots/` and referenced in entries.

---

## 2026-10-26

### 12:42 WIB — Snapshot of lab condition

- **Phase:** Documentation / validation
- **Action:** Took a snapshot of the condition of WSL, Docker, Wazuh, agents, and host.
- **Commands/artifacts:** `free -h`, `df -h`, `docker compose ps`, Wazuh API agents, indexer count.
- **Results:**
  - WSL 5.8 Gi; 3.4 Gi used; 2.3 Gi cache.
  - Three Wazuh containers Up.
  - Agents 000 and 001 `active`.
  - Agent 001: ±2,167 alerts; manager: 219 alerts.
  - Host free ±2.1 GB; Sysmon64 and WazuhSvc Running.
- **Status:** Complete
- **Follow-up:** Alert analysis and documentation.

### 12:43 WIB — Creating portfolio documentation

- **Phase:** Documentation
- **Action:** Created the `docs/` folder and the report, tracking, lessons learned, triage template, SIEM comparison, and CSV tracker documents.
- **Artifacts:**
  - `docs/README.md`
  - `docs/01-PROJECT-REPORT.md`
  - `docs/02-ACTIVITY-TRACKING.md`
  - `docs/03-LESSONS-LEARNED.md`
  - `docs/04-ALERT-TRIAGE-TEMPLATE.md`
  - `docs/05-SIEM-ALERT-MANAGEMENT.md`
  - `docs/triage-cases.csv`
- **Results:** Documentation created; credentials/keys sanitized from the documents.
- **Status:** Complete

### 12:54 WIB — Screenshot guide

- **Phase:** Documentation / evidence
- **Action:** Created the screenshot folder and an evidence-capture guide.
- **Artifacts:**
  - `docs/screenshots/` (with `.gitkeep`)
  - `docs/SCREENSHOT-GUIDE.md`
- **Results:** Dashboard queries for 4625, Sysmon, FIM, 92213, and a list of evidence file names.
- **Status:** Complete
- **Follow-up:** Capture the actual screenshots.

### 12:55 WIB — NVIDIA alert investigation

- **Phase:** Alert analysis / troubleshooting
- **Action:** Traced the cause of the NVIDIA alerts from the Windows System log, Wazuh, and NVIDIA logs.
- **Commands/artifacts:**
  - Wazuh rule 61102/61107/61110 query.
  - `Get-Service *Nv*`
  - `Get-WinEvent` Service Control Manager.
  - `Get-CimInstance Win32_Service -Filter "Name='NvContainerLocalSystem'"`
  - `nvidia-smi`
  - `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log`
- **Results:**
  - `NvContainerLocalSystem` crashing repeatedly.
  - Events 7031 and 7023 from Service Control Manager.
  - NVIDIA log: `Transition to Initializing state for mandatory plugin NvPluginWatchdog failed`; container exit code **14109**.
  - Driver 546.01 (2023); Windows build 26200.
  - ±518 NVIDIA alerts: 258 × 61102, 224 × 61107, 36 × 61110.
  - `NvContainerLocalSystem` Stopped/Automatic; `NVDisplay.ContainerLocalSystem` Running.
  - No indication of attack; this is an operational/driver issue.
- **Status:** Partial (root cause identified; fix not yet performed)
- **Follow-up:** Fix the NVIDIA driver or work around it with the Manual service; tune only after the root cause is understood.

### 12:58 WIB — Journal policy and NVIDIA fix plan

- **Phase:** Documentation / planning
- **Action:** Established the policy of recording every action and drafted the NVIDIA fix plan.
- **Results:** This journal was created; the driver fix plan was recorded.
- **Status:** Complete
- **NVIDIA fix plan:**
  1. Backup: restore point, BitLocker recovery key (if enabled), WSL export, docs backup.
  2. Download the latest official NVIDIA driver that still supports the GTX 1050 for Windows 11 64-bit.
  3. Try an in-place update with the clean install option.
  4. If it still crashes: DDU in Safe Mode, then install a clean driver.
  5. Verify: `NvContainerLocalSystem` service Running, `nvidia-smi`, no 7031/7023 in Event Viewer, NVIDIA alerts stop.
  6. If it still fails: set the service to Manual as a workaround, collect logs for further analysis.
- **Status:** Pending

---

## 2026-10-27

### 00:09 WIB — Verifying the NVIDIA recovery program

- **Phase:** Analysis / troubleshooting
- **Action:** Checked the service recovery configuration and the contents of the program run by Windows.
- **Commands/artifacts:**
  - `sc.exe qfailure NvContainerLocalSystem`
  - `Get-Content C:\Windows\NvContainerRecovery.bat`
  - `Get-Acl C:\Windows\NvContainerRecovery.bat`
  - `Get-FileHash C:\Windows\NvContainerRecovery.bat -Algorithm SHA256`
  - `C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log`
- **Results:**
  - Failure actions: restart 6s, restart 8s, run process 10s.
  - Recovery command: `cmd.exe /C %windir%\NvContainerRecovery.bat NvContainerLocalSystem C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log`.
  - Batch contents only: set registry recovery, `net start %1`, rollback registry, logging. No PowerShell, download, encoded command, or suspicious binary.
  - Normal ACL: SYSTEM/Administrators FullControl; Users ReadAndExecute.
  - SHA256: `10102167FEFF89EB1170C6AAA6BD5871446854AEF5CBF05BF82B2FB3A4E2CA76`.
  - Recovery log: `net start NvContainerLocalSystem` failed with system error **14109**.
  - Conclusion: the recovery program is legitimate NVIDIA, not persistence. The root cause remains the crash in `NvPluginWatchdog`.
- **Status:** Complete (verification); driver fix still pending
- **Follow-up:** Update/clean install the NVIDIA driver; if it still fails, set the service to Manual.

### 00:25 WIB — NVIDIA installation audit and alert impact

- **Phase:** Analysis / troubleshooting
- **Action:** Checked installed NVIDIA software, NvContainer plugins, and alert counts.
- **Commands/artifacts:**
  - Registry uninstall keys for NVIDIA/GeForce.
  - `Test-Path` GFE/NVIDIA App/NvContainer folders.
  - `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log`.
  - Query for alert counts of rules 61102/61107/61110.
- **Results:**
  - Driver 546.01; GeForce Experience 3.28.0.412; NvContainer 1.40; Watchdog Plugin 1.40; ShadowPlay 3.28.
  - GFE is at `C:\Program Files\NVIDIA Corporation\NVIDIA GeForce Experience`; NVIDIA App is not installed.
  - Plugin log: dependency `MessageBus.dll` failed (registry value), `_NvMdnsPlugin.dll`, `_NvStreamControl.dll`, `_IdentityPlugin.dll` error 126, and `NvPluginWatchdog` failed to initialize; container exit 14109.
  - NVIDIA alerts rose to **9,991** (rules 61102/61107/61110).
  - Conclusion: the NvContainer/driver installation is inconsistent or incompatible with Windows build 26200; not malware.
- **Status:** Pending (fix not yet performed)
- **Follow-up:** Backup, set the service to Manual temporarily, clean install the latest driver supporting the GTX 1050; NVIDIA App option; DDU fallback.

### 00:35 WIB — GPU model verification

- **Phase:** Inventory
- **Action:** Confirmed the discrete vs integrated GPU model.
- **Commands/artifacts:**
  - `Get-CimInstance Win32_VideoController`
  - `nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader`
- **Results:**
  - NVIDIA GeForce **GTX 1050**, 4096 MiB, driver 546.01.
  - Intel UHD Graphics 630 (integrated).
  - NVIDIA PNPDeviceID: `PCI\VEN_10DE&DEV_1C8D...`.
  - Not a GTX 1050 Ti.
- **Status:** Complete
- **Follow-up:** Use the driver for the GTX 1050 (notebook), not the 1050 Ti.

### 00:45 WIB — Creating the NVIDIA handoff brief

- **Phase:** Documentation
- **Action:** Drafted a summary of the NVIDIA problem + evidence for a second opinion from AI/another technician.
- **Artifacts:** `docs/NVIDIA-ISSUE-BRIEF.md`
- **Results:** The brief contains environment, symptoms, events 7031/7023, NvContainer logs, recovery config, GPU evidence, Wazuh impact, analysis, and specific questions.
- **Status:** Complete
- **Follow-up:** Use the brief during consultation; record the results in the journal.

### 00:55 WIB — NVIDIA alert cleanup procedure

- **Phase:** Documentation / analysis
- **Action:** Added a safe procedure to delete NVIDIA alerts and verify after the driver fix.
- **Artifacts:** `docs/NVIDIA-ISSUE-BRIEF.md` section 13.
- **Results:**
  - Baseline count and evidence export before deletion.
  - `_delete_by_query` for 61102/61107 with NVIDIA `param1`.
  - 61110 was not mass-deleted because it is a frequency rule.
  - Verification uses `FIX_TIME` in UTC and a range query.
- **Status:** Complete (documentation); no alerts deleted yet
- **Follow-up:** Run cleanup only after screenshot/export and after the driver is fixed.

---

## 2026-10-29

### 12:10 WIB — Triage alert 92058 `sdbinst.exe`

- **Phase:** Alert analysis / triage
- **Action:** Validated the Application Compatibility Database launched alert (Sysmon Event ID 1).
- **Commands/artifacts:**
  - `Get-AuthenticodeSignature C:\Windows\System32\sdbinst.exe`
  - `Get-CimInstance Win32_Service -Filter "Name='PcaSvc'"`
  - `Get-ChildItem C:\Windows\AppPatch -Recurse -Filter *.sdb`
  - Wazuh query `data.win.eventdata.image:*sdbinst*`, count rule 92058.
- **Results:**
  - `sdbinst.exe` in `C:\Windows\System32`, signature **Valid** (Microsoft Windows).
  - Parent: `svchost.exe -k LocalSystemNetworkRestricted -p -s PcaSvc`; PcaSvc service Running.
  - Command line: `C:\WINDOWS\System32\sdbinst.exe -m -bg`; user SYSTEM.
  - Recurring pattern hourly (e.g., 04:01, 05:01 UTC); 15 alerts 92058 total.
  - The .sdb files in AppPatch are Windows compatibility databases; no suspicious custom paths in the command line.
  - Conclusion: benign PcaSvc background maintenance, not malicious application shimming.
- **Status:** Closed – Benign
- **Follow-up:** Consider suppression/lowering 92058 only for the PcaSvc + `sdbinst.exe System32 -m -bg` pattern; do not suppress all 92058.

### 12:45 WIB — Re-triage 92213 and broad rule analysis

- **Phase:** Alert analysis / tuning
- **Action:** Validated alert 92213 `__PSScriptPolicyTest_*.ps1` and counted the overall rule 92213 pattern.
- **Commands/artifacts:**
  - 92213 count query and aggregation of `data.win.eventdata.image` / `targetFilename`.
  - `Test-Path` of temp files, `Get-ExecutionPolicy -List`.
- **Results:**
  - File `__PSScriptPolicyTest_pva3nha2.u5d.ps1` no longer exists (PowerShell deleted it).
  - Execution policy: CurrentUser RemoteSigned, LocalMachine Restricted.
  - Total 92213: **457**.
  - Main source: **407** from `Microsoft.VisualStudio.Setup.Service\BackgroundDownload.exe`; 41 from `powershell.exe`; the rest from Opera GX, BingSvc, NVIDIA/Brave installers.
  - All examined patterns are installers/updaters/self-tests, not malicious payload execution.
  - Conclusion: the specific alert is a false positive from a PowerShell policy test; rule 92213 is broad and noisy.
- **Status:** Closed – Benign (per event); tuning pending
- **Follow-up:** Suppress/lower 92213 only for verified patterns: `__PSScriptPolicyTest_*.ps1` and Visual Studio Setup Service in Temp. Do not suppress all 92213.

### 13:00 WIB — Creating the log analysis practice guide

- **Phase:** Documentation / learning
- **Action:** Drafted a SOC log analysis guide + 7-day exercises.
- **Artifacts:** `docs/07-LOG-ANALYSIS-PRACTICE.md`
- **Results:** 5-step method, key fields, process/auth/FIM/PowerShell analysis, queries, worksheet, 7-day exercises, and common mistakes.
- **Status:** Complete
- **Follow-up:** Use for daily practice; record findings in `triage-cases.csv`.

### 13:15 WIB — Adding required log table fields

- **Phase:** Documentation / learning
- **Action:** Added the minimum column list and per-use-case columns to the log analysis guide.
- **Artifacts:** `docs/07-LOG-ANALYSIS-PRACTICE.md` sections 3.1–3.3.
- **Results:**
  - 12 default Windows triage columns.
  - Additional columns for auth, process tree, FIM, network, PowerShell, Linux/auditd.
  - How to add columns in Threat Hunting/Discover and query tips.
- **Status:** Complete
- **Follow-up:** Apply the columns in the dashboard.

### 13:30 WIB — Verifying the difference between `timestamp` and `@timestamp`

- **Phase:** Data analysis / documentation
- **Action:** Checked the mapping and presence of both time fields.
- **Commands/artifacts:**
  - `_mapping/field/@timestamp`, `_mapping/field/timestamp`
  - Count of documents without `@timestamp`/`timestamp`
  - Sample of the 3 latest alerts
- **Results:**
  - Both are of type `date`.
  - Documents without `@timestamp`: 0; without `timestamp`: 0.
  - Same value, only format differs: `...Z` vs `...+0000`.
  - The `-` in the dashboard is a render/display issue, not empty data.
- **Status:** Complete
- **Follow-up:** Use `@timestamp` for time filtering/sorting; `timestamp` for the original event time.

### 13:40 WIB — Adding Windows vs Linux field comparison

- **Phase:** Documentation / learning
- **Action:** Added tables of common fields, Windows-only fields, Linux/auditd fields, and the 12-column Linux baseline.
- **Artifacts:** `docs/07-LOG-ANALYSIS-PRACTICE.md` section 3.5.
- **Results:**
  - Common fields: time, agent, rule, MITRE, location, decoder, syscheck.
  - Windows: `data.win.*`.
  - Linux: `data.audit.*`, `data.srcuser/dstuser`, `data.srcip`.
  - 12-column Linux baseline drafted.
- **Status:** Complete
- **Follow-up:** Use when Phase 4 adds the Linux victim + auditd.

### 23:50 WIB — Verifying the NVIDIA fix

- **Phase:** Stabilization
- **Action:** Verified the results of the NVIDIA driver update.
- **Commands/artifacts:**
  - `nvidia-smi --query-gpu=name,driver_version`
  - `Get-Service NvContainerLocalSystem,NVDisplay.ContainerLocalSystem`
  - `Get-WinEvent` Service Control Manager for the last 2 hours.
  - Wazuh rule 61102/61107 query with `param1=NVIDIA LocalSystem Container`.
- **Results:**
  - Driver: **582.78** (previously 546.01).
  - `NvContainerLocalSystem` **Running**; `NVDisplay.ContainerLocalSystem` Running.
  - No 7031/7023 events in the last 2 hours.
  - 0 new NVIDIA alerts since the October 29 10:01 boot.
  - Thousands of old alerts remain as history.
- **Status:** Resolved
- **Follow-up:** Filter/clean up old alerts after screenshots; monitor for recurrence.

### 23:55 WIB — Basic tuning of 92213 and 92058

- **Phase:** Tuning
- **Action:** Applied narrow tuning rules for noise that had been verified benign.
- **Artifacts:**
  - `home-lab/wazuh-tuning-rules.xml`
  - `docs/08-TUNING.md`
  - Manager: `/var/ossec/etc/rules/lab_tuning.xml`
- **Rules:**
  - `100210` — suppress 92213 for `__PSScriptPolicyTest_*.ps1`.
  - `100211` — suppress 92213 for `BackgroundDownload.exe` (Visual Studio Setup Service).
  - `100212` — suppress 92058 for `sdbinst.exe` + parent PcaSvc + `-m -bg`.
- **Results:**
  - Manager restart succeeded; dashboard HTTP 200; agents 000/001 active.
  - PowerShell policy test: 92213 `__PSScriptPolicyTest_*` count stayed **59 → 59** (no new alerts).
  - Rules 100211/100212 loaded; no new events to test yet.
  - Note: the manager log shows the startup warning `cp -ar multigroups`; the service remained normal.
- **Status:** Complete
- **Follow-up:** Monitor for 24 hours; review if new benign patterns appear.

### 23:58 WIB — Tuning hardening (anti-evasion)

- **Phase:** Tuning / security review
- **Action:** Audited the tuning rules so an attacker could not use them to evade alerts.
- **Changes:**
  - Removed `100210` (suppress all `__PSScriptPolicyTest_*.ps1`); the file name could be imitated by an attacker.
  - Narrowed `100211` to the Visual Studio Setup Service image path **and** a target in `AppData\Local\Temp\`.
  - Narrowed `100212` to `System32\sdbinst.exe` + parent `PcaSvc` + `-m -bg`.
- **Results:**
  - Test 92213 PowerShell policy: **59 → 60** (alert visible again).
  - Rules 100211/100212 loaded; dashboard HTTP 200; agent active.
  - Conclusion: no global suppression for 92213/92058; patterns outside the rules still alert.
- **Status:** Complete
- **Follow-up:** Monitor for 24 hours; review if new benign patterns appear.

---

## 2026-10-30

### 01:20 WIB — Phase 4A: DVWA running

- **Phase:** 4A — Victim container
- **Action:** Prepared the victim compose and ran DVWA.
- **Artifacts:**
  - `home-lab/phase4/docker-compose.victims.yml`
  - `home-lab/phase4/install-tools.sh`
  - `home-lab/phase4/README.md`
- **Results:**
  - Image `vulnerables/web-dvwa` (935 MB) pulled successfully.
  - Container `lab-dvwa` Up; port `127.0.0.1:8080->80`.
  - `http://localhost:8080` → HTTP 302 (redirect to setup/login).
  - WSL RAM 3.1 Gi of 5.8 Gi; ±2.5 Gi still available.
  - Attack tools not installed yet (requires sudo).
- **Status:** Partial (4A target running; tools pending)
- **Follow-up:** Run `phase4/install-tools.sh`, set up DVWA, then do an initial scan.

### 01:40 WIB — Detection and availability documentation

- **Phase:** 4A / 4B planning
- **Action:** Explained the web/Linux detection pipeline, agent behavior when the manager is down, and Linux victim options.
- **Artifacts:** `phase4/README.md` section "Attack Detection & Availability".
- **Results:**
  - Wazuh + agent in WSL stop when WSL shuts down.
  - Agents on other hosts still buffer to a limited extent; not a local SIEM.
  - Victim options: WSL container, second WSL distro, or separate host.
  - Web detection requires shipping Apache logs/sidecar agent; Linux detection requires an agent + auth.log/auditd.
- **Status:** Complete (documentation); detection implementation not yet
- **Follow-up:** Choose the 4B architecture and start the log pipeline.

### 01:45 WIB — Fix dirb wordlist path

- **Phase:** 4A — tools
- **Action:** Fixed the wrong wordlist path in the ffuf/gobuster commands.
- **Results:**
  - The `dirb` package is installed.
  - The Ubuntu wordlist is at `/usr/share/dirb/wordlists/common.txt`.
  - The `/usr/share/wordlists/dirb/common.txt` path is a Kali path, not present on Ubuntu.
  - Phase 4A documentation was updated.
- **Status:** Complete
- **Follow-up:** Run ffuf/gobuster with the correct path.

### 02:05 WIB — Phase 4B Linux victim + agent 003

- **Phase:** 4B — Linux victim
- **Action:** Built the Ubuntu victim container, sshd, rsyslog, Wazuh agent; enrolled it with the manager.
- **Artifacts:**
  - `phase4/linux-victim/Dockerfile`
  - `phase4/linux-victim/docker-compose.yml`
  - `phase4/linux-victim/ossec.conf`
  - `phase4/linux-victim/entrypoint.sh`
  - `phase4/linux-victim/lab.rules`
- **Results:**
  - Agent 002 was removed during the rebuild; the new agent received **ID 003** (Wazuh does not reuse IDs).
  - Agent 003 `linux-victim` **active**.
  - SSH `127.0.0.1:2222`; user `labuser`/`<LAB_USER_PASSWORD>`.
  - `auth.log` and `syslog` created by rsyslog.
  - Hydra wrong password test → auth.log recorded → **PAM 5503** alert in Wazuh.
  - `auditd` failed in the WSL container (`Operation not permitted`); auditd needs a separate WSL distro/host.
- **Status:** Partial (SSH/FIM/logs working; auditd pending)
- **Follow-up:** Repeated SSH brute force, sudo, FIM `/etc` tests; document PAM vs sshd rules.

### 02:15 WIB — Correcting the alert volume claim

- **Phase:** Documentation
- **Action:** Corrected the wording so it would not imply that all ±2,400 alerts had been triaged.
- **Changes:**
  - Report title changed to "Alert Volume Analysis (Not Full Triage)".
  - Added the list of samples actually triaged: 4625/60122, 92213, 92058, FIM 550, 61102/61107 NVIDIA.
  - Lessons learned emphasize volume ≠ triage.
- **Status:** Complete
- **Follow-up:** Use "alert volume" vs "triaged alerts" wording consistently.

### 19:05 WIB — Fix screenshot file names and README

- **Phase:** Documentation
- **Action:** Aligned screenshot file names with the README links and reduced excessive redaction.
- **Changes:**
  - `2agent windows and linux.png` → `agents-active.png`
  - `syscheck linux.png` → `linux-fim.png`
  - `sysmon2.png` → `sysmon-process.png`
  - `4625.png` → `alert-4625.png`
  - `92213.png` → `false-positive-92213.png`
  - API IDs left visible; only hostnames/usernames anonymized.
- **Status:** Complete
- **Follow-up:** Push the README update.

### 19:59 WIB — Restart lab + Phase 4C controlled tests

- **Phase:** 4C — baseline/controlled tests
- **Action:** Restarted Docker/Wazuh/Linux victim/DVWA, fixed a duplicate agent, then tested Linux detection.
- **Results:**
  - Docker started via `wsl.exe -u root`; Wazuh dashboard HTTP 200.
  - Old agent 003 removed due to a duplicate name; new agent **004** active.
  - Containers `lab-linux-victim` and `lab-dvwa` Up.
  - FIM `/etc/lab-fim-test-2` → rule **554 File added**.
  - SSH failed login → auth.log → rule **5503 PAM login failed**.
  - Tools nmap/hydra/sqlmap/nikto/ffuf/gobuster available.
- **Status:** Complete
- **Follow-up:** Move to Phase 5 — attack → detect → triage → tuning; auditd still needs a separate distro/host.

### 20:45 WIB — Phase 5A attack/detect

- **Phase:** 5A — attack, detect, triage
- **Action:** Ran controlled attacks against the Linux victim/DVWA and checked alerts.
- **Results:**
  - SSH brute force 10 attempts → rules **5503** and **2502**.
  - FIM `/etc/lab-phase5-fim` → rule **554**.
  - Persistence `/etc/cron.d/lab-phase5` → rule **554/550**.
  - Sudo failure → rule **5401**.
  - Web scan nmap/nikto/ffuf against DVWA succeeded, but there were **no web alerts** because Apache logs were not yet shipped to Wazuh.
  - Test cron/FIM artifacts were deleted.
- **Status:** 5A complete; 5B gap
- **Follow-up:** Ship DVWA Apache access logs via sidecar/agent, then test SQLi/XSS and triage.

### 22:55 WIB — Phase 5B Apache log pipeline

- **Phase:** 5B — web log ingestion
- **Action:** Shipped DVWA Apache access/error logs to Wazuh via a Wazuh agent sidecar.
- **Artifacts:**
  - `phase4/dvwa-agent/Dockerfile`
  - `phase4/dvwa-agent/ossec.conf`
  - `phase4/dvwa-agent/entrypoint.sh`
  - `phase4/docker-compose.victims.yml`
- **Technical details:**
  - DVWA writes `/var/log/apache2` to the named volume `dvwa-logs`.
  - Sidecar `lab-dvwa-agent` (agent 005 `dvwa-web`) mounts the volume read-only at `/logs`.
  - The agent sends logs to `wazuh.manager:1514` via the `single-node_default` network.
  - Wazuh Apache decoder + web rules process the access logs.
- **Results:**
  - Agent 005 `active`.
  - Nikto scan → rules **31101** and **31151**.
  - SQLi `UNION SELECT` → rule **31103**.
  - XSS `<script>` → rule **31105**.
  - Total >1,000 web alerts from the scan; needs triage/tuning.
- **Status:** Complete
- **Follow-up:** Phase 5C — web alert aggregation/tuning, case triage, continue to ESP32.

### 23:00 WIB — Phase 5C web triage/tuning

- **Phase:** 5C — triage/tuning
- **Action:** Evaluated web scan noise without disabling SQLi/XSS.
- **Changes:**
  - Rule `100230` was removed: suppressing 31101 from the authorized scanner would hide a true positive.
  - Rule `100231` remains for benign `/home/*/.cache/` FIM noise.
- **Results:**
  - A normal-UA 404 increased 31101 from **737 to 738**.
  - Nikto user-agent triggers **31508**; SQLi **31103**; XSS **31105**; aggregation **31151** remains active.
  - No attack signal is suppressed.
- **Status:** Complete
- **Follow-up:** Phase 6 ESP32 (wireless/physical/IoT), then the final report.

---

## Entry Template

```markdown
### YYYY-MM-DD HH:MM WIB — Title

- **Phase:**
- **Action:**
- **Commands/artifacts:**
- **Results:**
- **Status:** Complete / Partial / Pending / Failed
- **Follow-up:**
```
