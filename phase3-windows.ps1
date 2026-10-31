#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Membutuhkan Administrator. Membuka UAC...' -ForegroundColor Yellow
    $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argLine
    exit 0
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$labRoot   = 'D:\lab-tools'
$sysmonDir = Join-Path $labRoot 'sysmon'
$wazuhMsi  = Join-Path $labRoot 'wazuh-agent-4.14.9-1.msi'
$ossecDir  = 'C:\Program Files (x86)\ossec-agent'
$ossecConf = Join-Path $ossecDir 'ossec.conf'
$srcConf   = Join-Path $PSScriptRoot 'phase3-ossec.conf'

New-Item -ItemType Directory -Path $labRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sysmonDir -Force | Out-Null
Start-Transcript -Path (Join-Path $labRoot 'phase3-install.log') -Append | Out-Null

function Get-LabFile {
    param([string]$Url, [string]$OutFile)
    if (Test-Path $OutFile) {
        Write-Host ("Sudah ada: {0}" -f $OutFile)
        return
    }
    Write-Host ("Mengunduh: {0}" -f $Url)
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

try {
    Write-Host '=== Fase 3: Sysmon + Wazuh agent ===' -ForegroundColor Cyan

    $sysmonZip = Join-Path $labRoot 'Sysmon.zip'
    $sysmonCfg = Join-Path $sysmonDir 'sysmonconfig.xml'
    Get-LabFile 'https://download.sysinternals.com/files/Sysmon.zip' $sysmonZip
    Get-LabFile 'https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml' $sysmonCfg
    Expand-Archive -Path $sysmonZip -DestinationPath $sysmonDir -Force

    $sysmonExe = Join-Path $sysmonDir 'Sysmon64.exe'
    if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
        Write-Host 'Memperbarui konfigurasi Sysmon...'
        & $sysmonExe -c $sysmonCfg
    } else {
        Write-Host 'Menginstall Sysmon...'
        & $sysmonExe -accepteula -i $sysmonCfg
    }
    if ($LASTEXITCODE -ne 0) { throw ("Sysmon exit {0}" -f $LASTEXITCODE) }
    Start-Service Sysmon64 -ErrorAction SilentlyContinue

    Get-LabFile 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.9-1.msi' $wazuhMsi

    if (-not (Get-Service WazuhSvc -ErrorAction SilentlyContinue)) {
        Write-Host 'Menginstall Wazuh agent...'
        $msiArgs = @(
            '/i', ('"{0}"' -f $wazuhMsi), '/qn',
            'WAZUH_MANAGER=127.0.0.1',
            'WAZUH_MANAGER_PORT=1514',
            'WAZUH_REGISTRATION_SERVER=127.0.0.1',
            'WAZUH_REGISTRATION_PORT=1515'
        )
        $p = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
        if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw ("MSI exit {0}" -f $p.ExitCode) }
        for ($i = 0; $i -lt 20; $i++) {
            if (Get-Service WazuhSvc -ErrorAction SilentlyContinue) { break }
            Start-Sleep -Seconds 1
        }
        if (-not (Get-Service WazuhSvc -ErrorAction SilentlyContinue)) {
            throw 'Service WazuhSvc tidak ditemukan setelah instalasi.'
        }
    } else {
        Write-Host 'Wazuh agent sudah terpasang, lanjut konfigurasi.'
    }

    $svc = Get-Service WazuhSvc -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
        Stop-Service WazuhSvc -Force
        Start-Sleep -Seconds 3
    }

    if (-not (Test-Path $srcConf)) { throw ("File tidak ditemukan: {0}" -f $srcConf) }
    if (Test-Path $ossecConf) {
        $bak = '{0}.bak-{1}' -f $ossecConf, (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item $ossecConf $bak -Force
        Write-Host ("Backup ossec.conf: {0}" -f $bak)
    }
    Copy-Item $srcConf $ossecConf -Force
    Write-Host 'ossec.conf diganti dengan konfigurasi lab.'

    try { auditpol.exe /set /subcategory:"Process Creation" /success:enable | Out-Null } catch { Write-Host 'auditpol Process Creation gagal (lanjut).' -ForegroundColor Yellow }
    try { auditpol.exe /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null } catch { Write-Host 'auditpol Logon gagal (lanjut).' -ForegroundColor Yellow }
    try {
        reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f | Out-Null
        $psLog = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
        New-Item -Path $psLog -Force | Out-Null
        Set-ItemProperty -Path $psLog -Name EnableScriptBlockLogging -Value 1 -Type DWord
    } catch { Write-Host 'Gagal mengaktifkan audit PowerShell (lanjut).' -ForegroundColor Yellow }

    Start-Service WazuhSvc
    for ($i = 0; $i -lt 30; $i++) {
        if ((Get-Service WazuhSvc).Status -eq 'Running') { break }
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Seconds 10

    Write-Host ''
    Write-Host '=== Status ===' -ForegroundColor Cyan
    Get-Service Sysmon64, WazuhSvc | Format-Table Name, Status, StartType -AutoSize
    $tcp = Test-NetConnection 127.0.0.1 -Port 1514 -InformationLevel Quiet -WarningAction SilentlyContinue
    Write-Host ("Koneksi manager 127.0.0.1:1514 = {0}" -f $tcp)

    Write-Host ''
    Write-Host '=== ossec.log (15 baris terakhir) ===' -ForegroundColor Cyan
    Get-Content (Join-Path $ossecDir 'ossec.log') -Tail 15

    Write-Host ''
    Write-Host '=== Selesai ===' -ForegroundColor Green
    Write-Host 'Cek dashboard: Agents -> agent Windows harus Active.'
    Write-Host 'Log lengkap: D:\lab-tools\phase3-install.log'
} catch {
    Write-Host ('GAGAL: {0}' -f $_.Exception.Message) -ForegroundColor Red
    throw
} finally {
    Stop-Transcript | Out-Null
}
