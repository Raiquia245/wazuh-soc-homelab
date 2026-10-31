# Lessons Learned — Home Lab SIEM & SOC

Dokumen ini merangkum pelajaran teknis dan operasional dari pembangunan lab Wazuh di laptop 16 GB, serta implikasinya untuk peran SOC Analyst.

---

## 1. Pelajaran Teknis

### 1.1 Resource planning adalah bagian dari desain keamanan

Wazuh single-node terlihat ringan di dokumentasi, tetapi dalam praktik:

- Container manager, indexer, dan dashboard memakai ±2–3,4 GB.
- Linux memakai RAM kosong untuk page cache; `vmmemWSL` bisa mendekati batas WSL meski aplikasi hanya memakai sebagian.
- Di host 16 GB, Windows baseline sudah ±8–10 GB. Menambahkan WSL 8 GB membuat total melebihi kapasitas fisik dan memicu paging.

Pelajaran:

- Rencanakan RAM untuk **host + VM/WSL + aplikasi**, bukan hanya aplikasi.
- Pahami perbedaan `MemFree` dan `MemAvailable`; cache bukan kebocoran.
- `autoMemoryReclaim=gradual` membantu, tetapi batas `memory=` adalah kontrol utama.
- Untuk lab SIEM + Windows + browser, 32 GB RAM jauh lebih nyaman.

### 1.2 Lokasi disk dan VHDX sangat penting

- C: yang hampir penuh membuat image Docker dan volume Wazuh tidak muat.
- VHDX WSL di C: harus dipindah ke D: sebelum deploy.
- Data Docker berada di dalam ext4 WSL; setelah VHDX dipindah, data ikut pindah.
- Swap WSL default berada di C:; pindahkan dengan `swapFile` ke D:.

Pelajaran: cek `df -h` dan lokasi VHDX **sebelum** pull image besar.

### 1.3 Docker Desktop vs Docker Engine native

- Sisa konfigurasi Docker Desktop (`credsStore: desktop.exe`) menyebabkan pull gagal meski Docker Engine native sudah jalan.
- Menghapus `credsStore` dari `~/.docker/config.json` menyelesaikan masalah.
- Docker Engine native di WSL lebih ringan dan data-root-nya di ext4.

Pelajaran: bersihkan konfigurasi client lama saat berpindah runtime.

### 1.4 Bind mount dan ownership

- Docker membuat folder bind mount yang belum ada sebagai `root:root` dengan permission ketat.
- Generator certificate Wazuh gagal menulis ke folder tersebut.
- Solusi: buat folder sebagai user sebelum menjalankan container, lalu regenerasi certificate.

Pelajaran: jangan biarkan Docker membuat direktori host yang akan ditulis container; siapkan path dan permission secara eksplisit.

### 1.5 Urutan startup Wazuh

- Indexer perlu waktu untuk siap; dashboard dapat timeout saat migrasi saved objects.
- Timeout meninggalkan index `.kibana_1` setengah jadi dan dashboard menunggu selamanya.
- Solusi: hapus `.kibana_1`, restart dashboard setelah indexer sehat.

Pelajaran: pada fresh install di I/O lambat, siapkan runbook untuk migrasi dashboard dan verifikasi cluster `green` sebelum mengakses UI.

### 1.6 Enrollment bukan koneksi

- Agent bisa terdaftar (`id 001`) tetapi berstatus `never_connected`.
- Status itu berarti enrollment ke authd berhasil, tetapi agent belum mengirim keepalive ke remoted.
- Setelah koneksi pertama, status berubah menjadi `active`.

Pelajaran: bedakan **registered**, **connected**, dan **active**. Cek `lastKeepAlive`, port 1514, dan log agent.

### 1.7 Telemetri bisa duplikat

- Security 4688 dan Sysmon Event ID 1 sama-sama mencatat process creation.
- Hasilnya dua alert untuk satu proses (67027 dan 92031/92032).
- SCA dan error service Windows menambah volume besar.

Pelajaran: desain telemetri harus mempertimbangkan coverage dan overlap. Pilih sumber utama, gunakan sumber lain sebagai fallback, dan tuning rule.

### 1.8 FIM perlu pengujian yang tepat

- File yang dibuat lalu dihapus dalam hitungan detik bisa tidak tertangkap pada uji pertama.
- FIM tetap terbukti bekerja melalui perubahan `C:\Windows\System32\Tasks` (rule 550).
- Uji FIM sebaiknya memakai file yang bertahan beberapa menit dan path yang pasti dimonitor.

Pelajaran: kegagalan satu skenario uji tidak otomatis berarti fitur rusak; verifikasi dari beberapa sumber.

### 1.9 Kegagalan service operasional bisa mendominasi alert

- `NvContainerLocalSystem` crash berulang karena plugin `NvPluginWatchdog` gagal inisialisasi (exit code 14109).
- Windows Service Control Manager mencatat 7031/7023 dan melakukan recovery restart; Sysmon juga mencatat `net start NvContainerLocalSystem`.
- Wazuh menerjemahkannya menjadi rule 61102, 61107, dan frequency rule 61110: 518 alert pada snapshot.
- Tidak ada indikasi serangan; ini masalah driver/software NVIDIA (driver 546.01 pada Windows 11 build 26200).

Pelajaran: alert volume tinggi bisa berasal dari kegagalan operasional, bukan adversary. Root cause harus diperbaiki atau di-suppress secara spesifik—jangan mematikan seluruh kategori System error.

---

## 2. Pelajaran SOC

### 2.1 Alert bukan insiden

- ±2.400 alert bukan berarti ±2.400 serangan, dan bukan berarti semuanya sudah ditriase.
- Mayoritas adalah level 3–7: process creation, SCA compliance, error service.
- Alert adalah sinyal; insiden adalah sinyal yang sudah divalidasi dan memiliki dampak.

### 2.2 Severity bukan kebenaran

- Rule 92213 level 15 menandai file `__PSScriptPolicyTest_*.ps1` yang dibuat PowerShell untuk uji execution policy.
- Tanpa konteks (parent process, path, user, hash), alert level tinggi bisa menyesatkan.
- Validasi konteks wajib sebelum eskalasi.

### 2.3 Triage adalah proses, bukan tombol

- Wazuh 4.x tidak punya status per-alert.
- Status "baru" vs "sudah diproses" harus dilacak di case tracker eksternal.
- Case harus memiliki owner, status, disposisi, bukti, dan tindakan.
- SIEM lain (Splunk ES, Sentinel, Elastic, QRadar) menyediakan fitur ini native; Wazuh mengandalkan integrasi/ticketing.

### 2.4 Deduplikasi dan agregasi

- Satu kegagalan login adalah sinyal lemah; banyak kegagalan dari sumber yang sama dalam waktu singkat adalah sinyal kuat.
- Gunakan frequency rule, `same_source_ip`, `same_user`, dan time window.
- Satu case dapat mencakup banyak alert terkait.

### 2.5 Alert fatigue harus dilawan dengan desain

- Jangan hanya menurunkan level global; itu bisa membutakan deteksi.
- Tuning per rule: suppression pola yang diketahui, filter noise, pisahkan compliance dari incident queue.
- Ukur volume alert per rule dan waktu; rule teratas adalah kandidat tuning.

### 2.6 Dokumentasi adalah deliverable

- SOC Analyst harus bisa menjelaskan: apa yang terjadi, bukti apa, keputusan apa, tindakan apa.
- Case yang baik dapat diaudit ulang.
- Dokumentasi juga menjadi bukti portofolio: arsitektur, keputusan, kendala, dan hasil.

### 2.7 Etika dan scope

- Lab hanya pada perangkat sendiri.
- Jangan deauth/scan jaringan orang lain.
- Jangan ekspos dashboard/API ke internet tanpa hardening.
- Simpan kredensial dan key agent dengan aman.

### 2.8 Bedakan operational noise dari security signal

- NVIDIA crash loop adalah **benign true positive**: alert benar-benar terjadi, tetapi bukan insiden keamanan.
- Disposisi yang tepat: perbaiki service/driver atau suppress spesifik, bukan mengabaikan semua error System.
- Dalam interview, kemampuan menjelaskan perbedaan ini menunjukkan maturity triage.

---

## 3. Keputusan Desain dan Trade-off

| Keputusan | Alasan | Trade-off |
|---|---|---|
| WSL + Docker, bukan VM penuh | Tidak ada KVM; lebih ringan | Bukan isolasi sekuat VM; perilaku jaringan berbeda |
| Wazuh single-node | Cukup untuk lab dan pembelajaran | Tidak ada HA/cluster |
| 6 GB WSL | Host 16 GB, usage aktual ±3,4 GB | Di bawah rekomendasi resmi; risiko OOM |
| Tanpa Kali | Ubuntu bisa menjalankan tools yang sama | Perlu install manual; tidak semua tool preinstalled |
| Sysmon + 4688 | Coverage lebih besar | Duplikasi dan volume alert |
| Enrollment tanpa password | Memudahkan lab lokal | Tidak aman jika port 1515 terekspos |
| Dashboard di localhost | Mengurangi risiko eksposur | Tidak bisa diakses dari perangkat lain tanpa tunnel |
| Case tracker eksternal | Wazuh tidak punya case management | Perlu disiplin dan tooling tambahan |

---

## 4. Yang Akan Dilakukan Berbeda

1. Mulai dengan RAM 32 GB atau rencanakan WSL 6–8 GB sejak awal.
2. Pindahkan VHDX dan swap sebelum install Docker/Wazuh.
3. Rancang telemetri dan rule tuning sebelum mengaktifkan semua channel.
4. Buat case tracker sejak hari pertama, bukan setelah alert menumpuk.
5. Uji FIM dengan file yang bertahan lebih lama.
6. Dokumentasikan setiap perubahan konfigurasi dan alasan.
7. Siapkan backup/export sebelum eksperimen berisiko.

---

## 5. Kompetensi SOC yang Dilatih

- **Log analysis:** membaca event Windows, Sysmon, dan alert Wazuh.
- **Detection validation:** membuktikan event benar-benar masuk dan memicu rule.
- **Triage:** membedakan true positive, false positive, benign, duplicate.
- **Alert tuning:** suppression, filter, prioritas, pengurangan noise.
- **Incident documentation:** case, bukti, disposisi, tindakan.
- **Infrastructure:** WSL, Docker, networking localhost forwarding, resource tuning.
- **Security hygiene:** default credentials, binding, enrollment, least privilege.
- **Communication:** menjelaskan temuan dan keputusan secara ringkas.

---

## 6. Kutipan Pelajaran untuk Interview

> "Saya membangun lab Wazuh di laptop 16 GB dengan WSL dan Docker. Tantangan terbesarnya bukan memasang SIEM, tetapi membuat telemetri Windows, memvalidasi deteksi, dan menekan alert fatigue. Saya menemukan bahwa ribuan alert didominasi process creation dan SCA; satu alert level 15 ternyata false positive dari file uji PowerShell. Dari situ saya belajar bahwa triage membutuhkan konteks, case management, dan tuning—bukan hanya melihat severity."
