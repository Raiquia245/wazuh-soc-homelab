# Brief Handoff — NVIDIA NvContainer Crash Loop

**Tanggal:** 27 Oktober 2026, ±00:45 WIB  
**Tujuan:** Meminta second opinion dari AI/teknisi lain tentang akar masalah dan langkah perbaikan.  
**Status:** Investigasi selesai; **belum ada perbaikan yang dijalankan**.

---

## 1. Ringkasan

Laptop Acer Nitro AN515-52 (Windows 11 build 26200) mengalami crash loop pada service **NVIDIA LocalSystem Container** (`NvContainerLocalSystem`). Service berulang kali terminate, Windows menjalankan recovery program, tetapi `net start` juga gagal dengan error **14109**. Wazuh SIEM menerima event Windows System 7031/7023 dan menghasilkan **9.991 alert** dari rule 61102/61107/61110.

Gejala ini **bukan serangan malware**. GPU tetap terdeteksi dan berfungsi. Dugaan utama: instalasi NvContainer/driver NVIDIA tidak konsisten atau tidak cocok dengan Windows 11 build 26200.

---

## 2. Environment

| Item | Nilai |
|---|---|
| Laptop | Acer Nitro AN515-52 |
| OS | Windows 11 Home Single Language, 10.0.26200 build 26200 |
| BIOS | V1.22 |
| GPU discrete | NVIDIA GeForce GTX 1050 (mobile), 4096 MiB |
| GPU integrated | Intel UHD Graphics 630 |
| NVIDIA driver | 546.01 (31.0.15.4601), tanggal 26 Oktober 2023 |
| GeForce Experience | 3.28.0.412 |
| NVIDIA Container | 1.40 |
| NVIDIA Watchdog Plugin for NvContainer | 1.40 |
| NVIDIA ShadowPlay | 3.28.0.412 |
| NVIDIA App | Tidak terpasang |
| Wazuh agent | 4.14.9, agent 001 `LAB-WIN` |

Bukti GPU bukan 1050 Ti:

```text
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
NVIDIA GeForce GTX 1050, 4096 MiB, 546.01

Get-CimInstance Win32_VideoController
Name        : NVIDIA GeForce GTX 1050
DriverVersion : 31.0.15.4601
PNPDeviceID : PCI\VEN_10DE&DEV_1C8D&SUBSYS_12651025...
```

---

## 3. Service dan Konfigurasi

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

RESET_PERIOD : 10 detik
FAILURE_ACTIONS:
  RESTART -- delay 6000 ms
  RESTART -- delay 8000 ms
  RUN PROCESS -- delay 10000 ms

COMMAND_LINE:
cmd.exe /C %windir%\NvContainerRecovery.bat NvContainerLocalSystem
C:\ProgramData\NVIDIA\NvContainerRecoveryNvContainerLocalSystem.log
```

Recovery program sudah diverifikasi **legitimate NVIDIA**, bukan malware/persistence:

- Isi batch: set registry recovery, `net start %1`, rollback registry, logging.
- Tidak ada PowerShell/download/encoded command.
- ACL: SYSTEM/Administrators FullControl; Users ReadAndExecute.
- SHA256: `10102167FEFF89EB1170C6AAA6BD5871446854AEF5CBF05BF82B2FB3A4E2CA76`.

---

## 4. Bukti Event Windows

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

Event berulang beberapa detik sekali; pada sampel sebelumnya muncul hitungan ke-1, ke-2, ke-3 lalu recovery.

---

## 5. Bukti Log NVIDIA

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

## 6. Bukti Dampak ke Wazuh

- Agent Wazuh 001 aktif.
- Rule 61102 (Windows System error), 61107 (service terminated unexpectedly), 61110 (multiple system errors).
- Jumlah alert NVIDIA: **9.991**.
- Ini membuat noise besar di SIEM dan bisa membebani manager/indexer.

Contoh query:

```bash
curl -ks -u admin:'<PASSWORD>' \
  'https://127.0.0.1:9200/wazuh-alerts-*/_search?q=agent.id:001%20AND%20rule.id:61107&size=1&pretty'
```

---

## 7. Analisis

1. `NvContainerLocalSystem` adalah service untuk komponen NVIDIA seperti GeForce Experience, ShadowPlay, GameStream, telemetry, dan container plugins.
2. Service crash karena `NvPluginWatchdog` gagal inisialisasi dan dependency `MessageBus.dll` tidak dapat dimuat (registry value tidak ditemukan).
3. Beberapa plugin GameStream gagal load dengan error 126 (module not found/dependency failure).
4. Windows recovery menjalankan `NvContainerRecovery.bat`, tetapi `net start` juga gagal dengan 14109.
5. Driver 546.01 (2023) dan GFE 3.28 (2024) berjalan di Windows 11 build 26200 (2026); ini kombinasi lama dan berpotensi tidak kompatibel.
6. Tidak ada indikasi malware: recovery program legitimate, GPU terdeteksi, tidak ada command mencurigakan.

---

## 8. Yang Sudah dan Belum Dilakukan

Sudah:

- Verifikasi model GPU.
- Verifikasi service dan recovery configuration.
- Verifikasi isi/ACL/hash recovery batch.
- Analisis log NvContainer dan event Windows.
- Analisis alert Wazuh.
- Dokumentasi di jurnal lab.

Belum:

- Update/clean install driver NVIDIA.
- Uninstall/reinstall GeForce Experience atau upgrade ke NVIDIA App.
- DDU.
- Mengubah StartType service menjadi Manual.
- Reboot setelah perubahan.

---

## 9. Pertanyaan untuk AI/Teknisi Lain

1. Apakah kombinasi driver 546.01 + GFE 3.28 pada Windows 11 build 26200 dikenal menyebabkan `NvPluginWatchdog` gagal dan error 14109?
2. Apakah clean install driver terbaru yang masih mendukung GTX 1050 (notebook) biasanya memperbaiki dependency `MessageBus.dll` dan plugin GameStream error 126?
3. Sebaiknya update lewat GeForce Experience, NVIDIA App, atau standalone driver? GFE saat ini legacy; NVIDIA App belum terpasang.
4. Apakah perlu uninstall GeForce Experience/ShadowPlay dan install driver saja, mengingat crash berada di plugin NvContainer?
5. Apakah DDU perlu, atau clean install dari installer NVIDIA sudah cukup?
6. Apakah aman menjadikan `NvContainerLocalSystem` Manual jangka panjang jika tidak memakai GFE/ShadowPlay/GameStream? `NVDisplay.ContainerLocalSystem` tetap Running.
7. Apakah ada langkah lain untuk memperbaiki registry `MessageBus.dll` tanpa reinstall total?

---

## 10. Rekomendasi Sementara

Urutan yang paling masuk akal:

1. Backup: restore point + BitLocker key.
2. Set `NvContainerLocalSystem` ke Manual sementara untuk menghentikan loop.
3. Download driver resmi NVIDIA untuk GTX 1050 notebook + Windows 11 64-bit.
4. Custom install → **clean install**; uncheck GFE/ShadowPlay jika tidak dipakai.
5. Reboot dan verifikasi service/event/alert.
6. Jika masih gagal: DDU Safe Mode → install driver saja.
7. Jika tetap gagal: service Manual + kumpulkan log untuk NVIDIA support.

Jangan mematikan `NVDisplay.ContainerLocalSystem`; itu service display.

---

## 11. Prompt Singkat untuk AI Lain

```text
Saya punya Acer Nitro AN515-52, Windows 11 build 26200, GTX 1050 mobile 4GB,
driver NVIDIA 546.01, GeForce Experience 3.28.0.412, NvContainer 1.40.

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
Recovery batch sudah diverifikasi legitimate NVIDIA (hash 10102167...CA76), bukan malware.
GPU terdeteksi normal oleh nvidia-smi. NVIDIA App belum terpasang.

Pertanyaan: apakah clean install driver terbaru yang masih mendukung GTX 1050 akan memperbaiki ini?
Sebaiknya lewat GeForce Experience, NVIDIA App, atau standalone installer? Perlu DDU?
Apakah aman set NvContainerLocalSystem ke Manual jika tidak memakai GFE/ShadowPlay?
```

---

## 12. Catatan

- Jangan menyalin password/token ke AI lain.
- Jangan mengirim identifier unik laptop (serial number) ke pihak tidak tepercaya.
- Setelah perbaikan, verifikasi event 7031/7023 berhenti selama minimal 15–30 menit.

---

## 13. Cleanup Alert NVIDIA (Opsional)

Tujuan: mengurangi noise dan membuat baseline setelah perbaikan. Jangan menghapus sebelum mengambil bukti.

### Sebelum menghapus

1. Screenshot dashboard yang menunjukkan jumlah alert NVIDIA.
2. Export sample alert (JSON) untuk bukti.
3. Catat baseline count dan waktu perbaikan (`FIX_TIME` dalam UTC).
4. Ingat: penghapusan lewat `_delete_by_query` **tidak bisa dibatalkan**.

### Hitung baseline

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

### Hapus alert NVIDIA spesifik (61102/61107)

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

Catatan:

- Rule 61110 adalah frequency rule dan tidak selalu membawa `data.win.eventdata.param1`. Jangan hapus semua 61110; biarkan atau hapus berdasarkan rentang waktu crash loop setelah verifikasi.
- Jangan menghapus seluruh index `wazuh-alerts-4.x-YYYY.MM.DD`; itu menghapus semua alert hari itu.

### Setelah driver diperbaiki

Catat `FIX_TIME` (UTC), lalu cek apakah ada alert baru:

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

Interpretasi:

- `count = 0` selama 15–30 menit setelah reboot → service tidak crash lagi.
- `count > 0` → masalah masih ada; cek `Get-Service` dan Event Viewer.
- 61110 bisa tetap muncul dari error service lain; jangan jadikan satu-satunya indikator.

### Verifikasi Windows

```powershell
Get-Service NvContainerLocalSystem,NVDisplay.ContainerLocalSystem
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; StartTime=(Get-Date).AddMinutes(-30)} |
  Where-Object { $_.Message -match 'NVIDIA|NvContainer' }
```
