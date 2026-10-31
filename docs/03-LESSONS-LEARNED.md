# Lessons Learned — Home Lab SIEM & SOC

This document summarizes the technical and operational lessons from building a Wazuh lab on a 16 GB laptop, along with their implications for the SOC Analyst role.

---

## 1. Technical Lessons

### 1.1 Resource planning is part of security design

Wazuh single-node looks lightweight in the documentation, but in practice:

- The manager, indexer, and dashboard containers use ±2–3.4 GB.
- Linux uses free RAM for page cache; `vmmemWSL` can approach the WSL limit even when applications use only part of it.
- On a 16 GB host, the Windows baseline is already ±8–10 GB. Adding 8 GB for WSL pushes the total beyond physical capacity and triggers paging.

Lessons:

- Plan RAM for **host + VM/WSL + applications**, not just applications.
- Understand the difference between `MemFree` and `MemAvailable`; cache is not a leak.
- `autoMemoryReclaim=gradual` helps, but the `memory=` limit is the main control.
- For a SIEM + Windows + browser lab, 32 GB RAM is much more comfortable.

### 1.2 Disk location and VHDX matter

- A nearly full C: prevented Docker images and Wazuh volumes from fitting.
- The WSL VHDX on C: had to be moved to D: before deployment.
- Docker data resides inside the WSL ext4; after the VHDX is moved, the data moves with it.
- WSL swap defaults to C:; move it to D: via `swapFile`.

Lesson: check `df -h` and the VHDX location **before** pulling large images.

### 1.3 Docker Desktop vs native Docker Engine

- Leftover Docker Desktop configuration (`credsStore: desktop.exe`) caused pulls to fail even though native Docker Engine was running.
- Removing `credsStore` from `~/.docker/config.json` resolved the problem.
- Native Docker Engine in WSL is lighter and its data-root is on ext4.

Lesson: clean up old client configuration when switching runtimes.

### 1.4 Bind mounts and ownership

- Docker creates bind mount folders that do not yet exist as `root:root` with restrictive permissions.
- The Wazuh certificate generator failed to write to that folder.
- Solution: create the folder as a user before running the container, then regenerate certificates.

Lesson: do not let Docker create host directories that containers will write to; prepare paths and permissions explicitly.

### 1.5 Wazuh startup order

- The indexer needs time to become ready; the dashboard can time out during saved objects migration.
- The timeout leaves a half-finished `.kibana_1` index and the dashboard waits forever.
- Solution: delete `.kibana_1`, restart the dashboard after the indexer is healthy.

Lesson: on fresh installs with slow I/O, prepare a runbook for dashboard migration and verify the cluster is `green` before accessing the UI.

### 1.6 Enrollment is not connection

- An agent can be registered (`id 001`) but have the status `never_connected`.
- That status means enrollment with authd succeeded, but the agent has not sent a keepalive to remoted.
- After the first connection, the status changes to `active`.

Lesson: distinguish **registered**, **connected**, and **active**. Check `lastKeepAlive`, port 1514, and agent logs.

### 1.7 Telemetry can duplicate

- Security 4688 and Sysmon Event ID 1 both record process creation.
- The result is two alerts per process (67027 and 92031/92032).
- SCA and Windows service errors add substantial volume.

Lesson: telemetry design must consider coverage and overlap. Choose a primary source, use others as fallback, and tune rules.

### 1.8 FIM needs proper testing

- A file created and deleted within seconds may not be captured on the first test.
- FIM is still proven to work via changes under `C:\Windows\System32\Tasks` (rule 550).
- FIM tests should use files that persist for several minutes and paths that are definitely monitored.

Lesson: failure of one test scenario does not automatically mean the feature is broken; verify from multiple sources.

### 1.9 Operational service failures can dominate alerts

- `NvContainerLocalSystem` crashed repeatedly because the `NvPluginWatchdog` plugin failed to initialize (exit code 14109).
- Windows Service Control Manager recorded 7031/7023 and performed recovery restarts; Sysmon also recorded `net start NvContainerLocalSystem`.
- Wazuh translated this into rules 61102, 61107, and frequency rule 61110: 518 alerts in the snapshot.
- There was no indication of attack; this was an NVIDIA driver/software issue (driver 546.01 on Windows 11 build 26200).

Lesson: high alert volume can come from operational failures, not an adversary. Fix the root cause or suppress it specifically—do not turn off the entire System error category.

---

## 2. SOC Lessons

### 2.1 An alert is not an incident

- ±2,400 alerts does not mean ±2,400 attacks, nor does it mean all were triaged.
- The majority are level 3–7: process creation, SCA compliance, service errors.
- An alert is a signal; an incident is a validated signal with impact.

### 2.2 Severity is not truth

- Rule 92213 level 15 flags the `__PSScriptPolicyTest_*.ps1` file created by PowerShell to test execution policy.
- Without context (parent process, path, user, hash), high-level alerts can be misleading.
- Context validation is mandatory before escalation.

### 2.3 Triage is a process, not a button

- Wazuh 4.x has no per-alert status.
- "New" vs "processed" status must be tracked in an external case tracker.
- A case must have an owner, status, disposition, evidence, and action.
- Other SIEMs (Splunk ES, Sentinel, Elastic, QRadar) provide this feature natively; Wazuh relies on integrations/ticketing.

### 2.4 Deduplication and aggregation

- One failed login is a weak signal; many failures from the same source in a short time is a strong signal.
- Use frequency rules, `same_source_ip`, `same_user`, and time windows.
- One case can cover many related alerts.

### 2.5 Alert fatigue must be fought with design

- Do not just lower levels globally; that can blind detection.
- Tune per rule: suppress known patterns, filter noise, separate compliance from the incident queue.
- Measure alert volume per rule and over time; the top rules are tuning candidates.

### 2.6 Documentation is a deliverable

- A SOC Analyst must be able to explain: what happened, what evidence, what decision, what action.
- A good case can be audited again.
- Documentation also serves as portfolio evidence: architecture, decisions, constraints, and results.

### 2.7 Ethics and scope

- Lab only on own devices.
- Do not deauth/scan other people's networks.
- Do not expose the dashboard/API to the internet without hardening.
- Store credentials and agent keys securely.

### 2.8 Distinguish operational noise from security signal

- The NVIDIA crash loop is a **benign true positive**: the alert genuinely occurred, but it is not a security incident.
- Correct disposition: fix the service/driver or suppress specifically, not ignore all System errors.
- In an interview, the ability to explain this difference shows triage maturity.

---

## 3. Design Decisions and Trade-offs

| Decision | Reason | Trade-off |
|---|---|---|
| WSL + Docker, not full VMs | No KVM; lighter | Not as strong isolation as VMs; different network behavior |
| Wazuh single-node | Sufficient for the lab and learning | No HA/cluster |
| 6 GB WSL | 16 GB host, actual usage ±3.4 GB | Below the official recommendation; OOM risk |
| No Kali | Ubuntu can run the same tools | Manual install needed; not all tools preinstalled |
| Sysmon + 4688 | Greater coverage | Duplication and alert volume |
| Enrollment without password | Simplifies the local lab | Insecure if port 1515 is exposed |
| Dashboard on localhost | Reduces exposure risk | Cannot be accessed from other devices without a tunnel |
| External case tracker | Wazuh has no case management | Requires discipline and additional tooling |

---

## 4. What I Would Do Differently

1. Start with 32 GB RAM or plan 6–8 GB for WSL from the beginning.
2. Move the VHDX and swap before installing Docker/Wazuh.
3. Design telemetry and rule tuning before enabling all channels.
4. Create the case tracker from day one, not after alerts pile up.
5. Test FIM with longer-lived files.
6. Document every configuration change and its rationale.
7. Prepare backups/exports before risky experiments.

---

## 5. SOC Competencies Practiced

- **Log analysis:** reading Windows events, Sysmon, and Wazuh alerts.
- **Detection validation:** proving events actually arrive and trigger rules.
- **Triage:** distinguishing true positive, false positive, benign, duplicate.
- **Alert tuning:** suppression, filtering, prioritization, noise reduction.
- **Incident documentation:** cases, evidence, disposition, action.
- **Infrastructure:** WSL, Docker, localhost forwarding networking, resource tuning.
- **Security hygiene:** default credentials, binding, enrollment, least privilege.
- **Communication:** explaining findings and decisions concisely.

---

## 6. Interview-Ready Lesson Quote

> "I built a Wazuh lab on a 16 GB laptop with WSL and Docker. The biggest challenge was not installing the SIEM, but getting Windows telemetry working, validating detections, and reducing alert fatigue. I found that thousands of alerts were dominated by process creation and SCA; one level 15 alert turned out to be a false positive from a PowerShell test file. From that I learned that triage requires context, case management, and tuning—not just looking at severity."
