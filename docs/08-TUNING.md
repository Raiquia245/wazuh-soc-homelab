# Tuning Record — Rules 92213 and 92058

**Status:** Applied October 29, 2026, then hardened the same day.  
**Rule file:** `home-lab/wazuh-tuning-rules.xml`  
**Manager location:** `/var/ossec/etc/rules/lab_tuning.xml`

## Active Rules

| Rule | Parent | Pattern | Action | Reason |
|---|---|---|---|---|
| `100211` | `92213` | `image` = Visual Studio Setup Service path `BackgroundDownload.exe` and target in `AppData\Local\Temp\` | level 0 | Visual Studio Setup Service writes temporary files in Temp |
| `100212` | `92058` | `System32\sdbinst.exe` + parent `PcaSvc` + command `-m -bg` | level 0 | Windows compatibility database maintenance by PcaSvc |
| `100231` | `554,550` | `syscheck.path` matches `/home/*/.cache/` | level 0 | User cache files at login |

## What Is Not Suppressed

- Not all `92213` and `92058` rules are disabled.
- `92213` for `__PSScriptPolicyTest_*.ps1` is deliberately left visible so it cannot be used for evasion.
- NVIDIA `61102/61107/61110` are not suppressed; the driver is fixed and recurrence remains detectable.
- `67027` (4688 process creation) remains active for hunting.

## Risk Analysis

- Rule `100210` (suppress all `__PSScriptPolicyTest_*.ps1`) was removed because the file name could be imitated by an attacker.
- `100211` was narrowed to a specific image path and target path; not all files from a process named `BackgroundDownload.exe`.
- `100212` only matches the PcaSvc maintenance command; use of `sdbinst` with a custom `.sdb` does not match and still alerts.
- Sysmon process creation/network detection remains active; suppression applies only to file-create for specific patterns.

## Test Status

- 92213 PowerShell policy test after hardening: count **59 → 60**; alert visible again.
- Dashboard HTTP 200; agents 000/001/003 active.
- Rules `100211`/`100212` loaded; no new events to retest yet.

## Notes

- Old alerts were not deleted.
- Tuning is reviewed periodically; do not mask new detections.
- Rule changes and test results are recorded in `06-LAB-JOURNAL.md`.

## Phase 5A Observations

- SSH brute force was detected as **PAM 5503** and **syslog 2502**, not the sshd rules 5710/5712. This is sufficient to detect brute force, but the decoder can be tuned if standard sshd rules are desired.
- FIM `/home/*/.cache` produces noise at login; consider a specific cache ignore.
- Sudo failure detected by rule **5401**.
- Web attacks were not detected because DVWA Apache logs were not yet shipped to Wazuh; this is a Phase 5B gap.

## Phase 5B Web Pipeline

- Apache logs are shipped by sidecar agent 005 from a shared Docker volume.
- Scan activity generates many 31101 alerts; rule 31151 aggregates repeated 400 errors.
- SQLi (31103) and XSS (31105) must not be suppressed.
- Tuning direction: aggregate/filter scanner noise by source IP/time window, not by disabling web rules.

## Phase 5C — Web Tuning Result

- Rule `100230` was evaluated and then removed: the scan was an authorized attack simulation, so suppressing 31101 would hide a real true positive.
- `31101` remains active: a normal-UA 404 increased the count from **737 to 738**.
- Nikto user-agent triggers **31508** (blacklisted user agent); SQLi keeps firing **31103**, XSS keeps firing **31105**, and **31151** aggregates repeated scan errors.
- `100231` remains active only for benign `/home/*/.cache/` FIM noise.
