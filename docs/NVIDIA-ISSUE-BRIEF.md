# Handoff Brief — NVIDIA NvContainer Crash Loop

**Date:** October 27, 2026, ±00:45 WIB  
**Purpose:** To request a second opinion from AI/another technician about the root cause and remediation steps.  
**Status:** Investigation complete; **no fix has been applied yet**.

---

## 1. Summary

The Acer Nitro AN515-52 laptop (Windows 11 build 26200) is experiencing a crash loop in the **NVIDIA LocalSystem Container** service (`NvContainerLocalSystem`). The service repeatedly terminates, Windows runs the recovery program, but `net start` also fails with error **14109**. Wazuh SIEM receives Windows System events 7031/7023 and generates **9,991 alerts** from rules 61102/61107/61110.

These symptoms are **not a malware attack**. The GPU is still detected and working. The main hypothesis: the NvContainer/NVIDIA driver installation is inconsistent or incompatible with Windows 11 build 26200.

---

## 2. Environment

| Item | Value |
|---|---|
| Laptop | Acer Nitro AN515-52 |
| OS | Windows 11 Home Single Language, 10.0.26200 build 26200 |
| BIOS | V1.22 |
| Discrete GPU | NVIDIA GeForce GTX 1050 (mobile), 4096 MiB |
| Integrated GPU | Intel UHD Graphics 630 |
| NVIDIA driver | 546.01 (31.0.15.4601), dated October 26, 2023 |
| GeForce Experience | 3.28.0.412 |
| NVIDIA Container | 1.40 |
| NVIDIA Watchdog Plugin for NvContainer | 1.40 |
| NVIDIA ShadowPlay | 3.28.0.412 |
| NVIDIA App | Not installed |
| Wazuh agent | 4.14.9, agent 001 `LAB-WIN` |

Evidence that the GPU is not a 1050 Ti:

```text
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
NVIDIA GeForce GTX 1050, 4096 MiB, 546.01

Get-CimInstance Win32_VideoController
Name        : NVIDIA GeForce GTX 1050
DriverVersion : 31.0.15.4601
PNPDeviceID : PCI\VEN_10DE&DEV_1C8D&SUBSYS_12651025...
```

---

## 3. Services and Configuration

```text
Get-Service NvContainerLocalSystem,NVDisplay.ContainerLocalSystem

Name                            Status   StartType
NvContainerLocalSystem          Stopped  Automatic
NVDisplay.ContainerLocalSystem  Running  Automatic
```

```text
sc.exe qc NvContainerLocalSystem

BINARY_PATH_NAME : "C:\Program Files\NVIDIA Corporation\NvContainer\nvcontainer.exe"
  -s NvContainerLocalSystem -a
  -f "C:\ProgramData\NVIDIA\NvContainerLocalSystem.log" -l 3
  -d "C:\Program Files\NVIDIA Corporation\NvContainer\plugins\LocalSystem"
  -r -p 30000
  -st "C:\Program Files\NVIDIA Corporation\NvContainer\NvContainerTelemetryApi.dll" -ert
SERVICE_START_NAME : LocalSystem
```

Recovery configuration:

```text
sc.exe qfailure NvContainerLocalSystem

RESET_PERIOD : 10 seconds
FAILURE_ACTIONS:
  RESTART -- delay 6000 ms
  RESTART -- delay 8000 ms
  RUN PROCESS -- delay 10000 ms

COMMAND_LINE:
cmd.exe /C %windir%\NvContainerRecovery.bat NvContainerLocalSystem
C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log
```

The recovery program has been verified as **legitimate NVIDIA**, not malware/persistence:

- Batch contents: set registry recovery, `net start %1`, rollback registry, logging.
- No PowerShell/download/encoded command.
- ACL: SYSTEM/Administrators FullControl; Users ReadAndExecute.
- SHA256: `10102167FEFF89EB1170C6AAA6BD5871446854AEF5CBF05BF82B2FB3A4E2CA76`.

---

## 4. Windows Event Evidence

Event 7031:

```text
The NVIDIA LocalSystem Container service terminated unexpectedly.
It has done this 3 time(s). The following corrective action will be taken
in 10000 milliseconds: Run the configured recovery program.
```

Event 7023:

```text
The NVIDIA LocalSystem Container service terminated with the following error:
A generic command executable returned a result that indicates failure.
```

The events recur every few seconds; in the earlier sample the counts appeared as 1st, 2nd, 3rd, then recovery.

---

## 5. NVIDIA Log Evidence

File: `C:\ProgramData\NVIDIA\NvContainerLocalSystem.log`

```text
Transition to Initializing state for mandatory plugin NvPluginWatchdog failed
Skipping loading dependency module MessageBus.dll
  reason: Failed to get registry value size
Dependency module load failed
Failed to load library ...\GameStream\Discovery\_NvMdnsPlugin.dll. Error 126
Failed to load library ...\GameStream\Main\_NvStreamControl.dll. Error 126
Failed to load library ...\GameStream\Pairing\_IdentityPlugin.dll. Error 126
Container main exited with error
Service host: 'Stopped' status reported. Exit code 14109
```

Recovery log: `C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log`

```text
Starting service NvContainerLocalSystem
The NVIDIA LocalSystem Container service could not be started.
System error 14109 has occurred.
A generic command executable returned a result that indicates failure.
```

---

## 6. Evidence of Wazuh Impact

- Wazuh agent 001 is active.
- Rule 61102 (Windows System error), 61107 (service terminated unexpectedly), 61110 (multiple system errors).
- NVIDIA alert count: **9,991**.
- This creates a large amount of noise in the SIEM and can burden the manager/indexer.

Example query:

```bash
curl -ks -u admin:'<PASSWORD>' \
  'https://127.0.0.1:9200/wazuh-alerts-*/_search?q=agent.id:001%20AND%20rule.id:61107&size=1&pretty'
```

---

## 7. Analysis

1. `NvContainerLocalSystem` is the service for NVIDIA components such as GeForce Experience, ShadowPlay, GameStream, telemetry, and container plugins.
2. The service crashes because `NvPluginWatchdog` fails to initialize and the `MessageBus.dll` dependency cannot be loaded (registry value not found).
3. Several GameStream plugins fail to load with error 126 (module not found/dependency failure).
4. Windows recovery runs `NvContainerRecovery.bat`, but `net start` also fails with 14109.
5. Driver 546.01 (2023) and GFE 3.28 (2024) are running on Windows 11 build 26200 (2026); this is an old combination and potentially incompatible.
6. No indication of malware: the recovery program is legitimate, the GPU is detected, and there are no suspicious commands.

---

## 8. What Has and Has Not Been Done

Done:

- Verify the GPU model.
- Verify the service and recovery configuration.
- Verify the contents/ACL/hash of the recovery batch.
- Analyze NvContainer logs and Windows events.
- Analyze Wazuh alerts.
- Document in the lab journal.

Not done:

- Update/clean install the NVIDIA driver.
- Uninstall/reinstall GeForce Experience or upgrade to NVIDIA App.
- DDU.
- Change the service StartType to Manual.
- Reboot after changes.

---

## 9. Questions for AI/Other Technicians

1. Is the combination of driver 546.01 + GFE 3.28 on Windows 11 build 26200 known to cause `NvPluginWatchdog` failure and error 14109?
2. Does a clean install of the latest driver still supporting the GTX 1050 (notebook) usually fix the `MessageBus.dll` dependency and GameStream plugin error 126?
3. Should the update be done via GeForce Experience, NVIDIA App, or the standalone driver? GFE is currently legacy; NVIDIA App is not installed.
4. Is it necessary to uninstall GeForce Experience/ShadowPlay and install only the driver, given that the crash is in an NvContainer plugin?
5. Is DDU necessary, or is a clean install from the NVIDIA installer sufficient?
6. Is it safe to leave `NvContainerLocalSystem` set to Manual long-term if GFE/ShadowPlay/GameStream are not used? `NVDisplay.ContainerLocalSystem` remains Running.
7. Are there other steps to fix the `MessageBus.dll` registry without a full reinstall?

---

## 10. Temporary Recommendation

The most reasonable sequence:

1. Backup: restore point + BitLocker key.
2. Set `NvContainerLocalSystem` to Manual temporarily to stop the loop.
3. Download the official NVIDIA driver for the GTX 1050 notebook + Windows 11 64-bit.
4. Custom install → **clean install**; uncheck GFE/ShadowPlay if not used.
5. Reboot and verify service/events/alerts.
6. If it still fails: DDU Safe Mode → install driver only.
7. If it still fails: Manual service + collect logs for NVIDIA support.

Do not disable `NVDisplay.ContainerLocalSystem`; it is the display service.

---

## 11. Short Prompt for Another AI

```text
I have an Acer Nitro AN515-52, Windows 11 build 26200, GTX 1050 mobile 4GB,
NVIDIA driver 546.01, GeForce Experience 3.28.0.412, NvContainer 1.40.

NvContainerLocalSystem crash loop. Event 7031/7023:
"The NVIDIA LocalSystem Container service terminated unexpectedly. It has done this 3 time(s).
The following corrective action will be taken in 10000 milliseconds: Run the configured recovery program."
"The NVIDIA LocalSystem Container service terminated with the following error:
A generic command executable returned a result that indicates failure."

Log C:\ProgramData\NVIDIA\NvContainerLocalSystem.log:
- Transition to Initializing state for mandatory plugin NvPluginWatchdog failed
- Skipping loading dependency module MessageBus.dll, reason: Failed to get registry value size
- Failed to load ...\_NvMdnsPlugin.dll / _NvStreamControl.dll / _IdentityPlugin.dll. Error 126
- Container main exited with error
- Exit code 14109

Recovery: cmd.exe /C %windir%\NvContainerRecovery.bat ...
Recovery log: net start NvContainerLocalSystem failed, system error 14109.
The recovery batch has been verified as legitimate NVIDIA (hash 10102167...CA76), not malware.
The GPU is detected normally by nvidia-smi. NVIDIA App is not installed.

Questions: will a clean install of the latest driver still supporting the GTX 1050 fix this?
Should I use GeForce Experience, NVIDIA App, or the standalone installer? Is DDU needed?
Is it safe to set NvContainerLocalSystem to Manual if I don't use GFE/ShadowPlay?
```

---

## 12. Notes

- Do not copy passwords/tokens to other AIs.
- Do not send the laptop's unique identifier (serial number) to untrusted parties.
- After the fix, verify that events 7031/7023 stop for at least 15–30 minutes.

---

## 13. NVIDIA Alert Cleanup (Optional)

Goal: reduce noise and establish a baseline after the fix. Do not delete before capturing evidence.

### Before deleting

1. Screenshot the dashboard showing the NVIDIA alert count.
2. Export sample alerts (JSON) as evidence.
3. Record the baseline count and the fix time (`FIX_TIME` in UTC).
4. Remember: deletion via `_delete_by_query` **cannot be undone**.

### Count baseline

```bash
curl -ks -u admin:'<ADMIN_PASSWORD>' \
  'https://127.0.0.1:9200/wazuh-alerts-*/_count' \
  -H 'Content-Type: application/json' -d '{
    "query": {
      "bool": {
        "filter": [
          {"term": {"agent.id": "001"}},
          {"terms": {"rule.id": ["61102","61107"]}},
          {"match_phrase": {"data.win.eventdata.param1": "NVIDIA LocalSystem Container"}}
        ]
      }
    }
  }'
```

### Delete specific NVIDIA alerts (61102/61107)

```bash
curl -ks -u admin:'<ADMIN_PASSWORD>' -X POST \
  'https://127.0.0.1:9200/wazuh-alerts-*/_delete_by_query?conflicts=proceed&refresh=true' \
  -H 'Content-Type: application/json' -d '{
    "query": {
      "bool": {
        "filter": [
          {"term": {"agent.id": "001"}},
          {"terms": {"rule.id": ["61102","61107"]}},
          {"match_phrase": {"data.win.eventdata.param1": "NVIDIA LocalSystem Container"}}
        ]
      }
    }
  }'
```

Notes:

- Rule 61110 is a frequency rule and does not always carry `data.win.eventdata.param1`. Do not delete all 61110; leave it or delete by the crash loop time range after verification.
- Do not delete the entire `wazuh-alerts-4.x-YYYY.MM.DD` index; that deletes all alerts for that day.

### After the driver is fixed

Record `FIX_TIME` (UTC), then check whether there are new alerts:

```bash
curl -ks -u admin:'<ADMIN_PASSWORD>' \
  'https://127.0.0.1:9200/wazuh-alerts-*/_count' \
  -H 'Content-Type: application/json' -d '{
    "query": {
      "bool": {
        "filter": [
          {"term": {"agent.id": "001"}},
          {"terms": {"rule.id": ["61102","61107"]}},
          {"match_phrase": {"data.win.eventdata.param1": "NVIDIA LocalSystem Container"}},
          {"range": {"@timestamp": {"gte": "FIX_TIME_UTC"}}}
        ]
      }
    }
  }'
```

Interpretation:

- `count = 0` for 15–30 minutes after reboot → the service is no longer crashing.
- `count > 0` → the problem persists; check `Get-Service` and Event Viewer.
- 61110 may still appear from other service errors; do not use it as the sole indicator.

### Windows verification

```powershell
Get-Service NvContainerLocalSystem,NVDisplay.ContainerLocalSystem
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; StartTime=(Get-Date).AddMinutes(-30)} |
  Where-Object { $_.Message -match 'NVIDIA|NvContainer' }
```
