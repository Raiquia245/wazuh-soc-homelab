#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$distro     = 'Ubuntu'
$destRoot   = 'D:\WSL'
$dest       = Join-Path $destRoot $distro
$wslConfig  = Join-Path $env:USERPROFILE '.wslconfig'

Write-Host '=== Fase 0: pindah disk WSL + tuning RAM ===' -ForegroundColor Cyan

if (-not (Test-Path 'D:\')) { throw 'Drive D: tidak ditemukan.' }

$dFree = (Get-PSDrive D).Free / 1GB
if ($dFree -lt 60) { throw ('D: hanya punya {0:N1} GB free; butuh minimal 60 GB.' -f $dFree) }
Write-Host ('C: free sebelum : {0:N1} GB' -f ((Get-PSDrive C).Free / 1GB))
Write-Host ('D: free         : {0:N1} GB' -f $dFree)

$docker = Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue
if ($docker) {
    Write-Host 'Menutup Docker Desktop agar WSL bisa dimatikan...'
    $docker | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

Write-Host 'Mematikan WSL...'
wsl --shutdown
Start-Sleep -Seconds 5

if (-not (Test-Path $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot | Out-Null
}

$distros = (wsl -l -q) -replace "`0", '' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($distros -notcontains $distro) {
    throw ("Distro '{0}' tidak ditemukan. Yang ada: {1}" -f $distro, ($distros -join ', '))
}

if (Test-Path $dest) {
    Write-Host ("Tujuan sudah ada, lewati move: {0}" -f $dest) -ForegroundColor Yellow
} else {
    Write-Host ("Memindahkan {0} ke {1} (bisa beberapa menit)..." -f $distro, $dest)
    wsl --manage $distro --move $dest
    if ($LASTEXITCODE -ne 0) {
        throw ("wsl --manage --move gagal (exit {0}). Pastikan Docker Desktop benar-benar tertutup." -f $LASTEXITCODE)
    }
}

try {
    wsl --manage $distro --set-sparse true 2>$null | Out-Null
    Write-Host 'Sparse VHD diaktifkan.'
} catch {
    Write-Host 'Sparse VHD tidak didukung versi WSL ini (boleh dilewati).' -ForegroundColor Yellow
}

if (Test-Path $wslConfig) {
    $backup = '{0}.bak-{1}' -f $wslConfig, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $wslConfig $backup
    Write-Host ("Backup .wslconfig lama: {0}" -f $backup)
}

$content = @'
[wsl2]
memory=10GB
processors=6
swap=4GB
swapFile=D:\\WSL\\swap.vhdx
localhostForwarding=true

[experimental]
sparseVhd=true
'@

[System.IO.File]::WriteAllText($wslConfig, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("Ditulis: {0}" -f $wslConfig)

Write-Host 'Menyalakan WSL dengan konfigurasi baru...'
wsl -d $distro --exec bash -lc "free -h | sed -n '1,2p'; echo; df -h / | tail -1"

Write-Host ''
Write-Host '=== Fase 0 selesai ===' -ForegroundColor Green
Write-Host ('C: free sekarang: {0:N1} GB' -f ((Get-PSDrive C).Free / 1GB))
Write-Host 'Berikutnya: buka terminal Ubuntu, lalu jalankan:'
Write-Host '  sudo bash /mnt/d/Portofolio/CyberSecurity/home-lab/phase1-docker.sh'
