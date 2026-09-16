```powershell
# ============================================================
# PikaTweaks V4
# Windows 11 Gaming & System Utility
#
# Safe / reversible edition
# - Gaming optimization
# - Cleanup
# - Power plans
# - Game Mode / Game DVR
# - Network tools
# - Security / Advanced audit
# - Backup / Restore
# - System dashboard
#
# Does NOT disable Windows Defender, Firewall or UAC.
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$PikaRoot   = Join-Path $env:ProgramData "PikaTweaks"
$BackupRoot = Join-Path $PikaRoot "Backups"
$ReportRoot = Join-Path $PikaRoot "Reports"

New-Item -ItemType Directory -Path $PikaRoot -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

# ============================================================
# ADMIN
# ============================================================

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-IsAdmin)) {
    Write-Host ""
    Write-Host "PikaTweaks requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Restarting as Administrator..." -ForegroundColor Cyan

    $scriptPath = $MyInvocation.MyCommand.Path

    if ($scriptPath) {
        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    }
    else {
        Write-Host ""
        Write-Host "Please run PowerShell as Administrator." -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }

    exit
}

# ============================================================
# UI
# ============================================================

function Clear-Pika {
    Clear-Host
}

function Write-Logo {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                    PIKATWEAKS V4" -ForegroundColor Magenta
    Write-Host "              WINDOWS GAMING UTILITY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Pika {
    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Write-OK {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-WarningPika {
    param([string]$Text)
    Write-Host "[WARNING] $Text" -ForegroundColor Yellow
}

function Write-InfoPika {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

# ============================================================
# BACKUP
# ============================================================

function Backup-PikaSettings {

    Write-Section "Creating Backup"

    $backup = [ordered]@{}

    # Current power scheme
    try {
        $power = powercfg /getactivescheme

        if ($power) {
            $backup.PowerScheme = ($power | Out-String).Trim()
        }
    }
    catch {}

    # Game Mode
    try {
        $backup.GameMode = (
            Get-ItemPropertyValue `
                -Path "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -ErrorAction Stop
        )
    }
    catch {
        $backup.GameMode = $null
    }

    # Game DVR
    try {
        $backup.GameDVR = (
            Get-ItemPropertyValue `
                -Path "HKCU:\System\GameConfigStore" `
                -Name "GameDVR_Enabled" `
                -ErrorAction Stop
        )
    }
    catch {
        $backup.GameDVR = $null
    }

    # App Capture
    try {
        $backup.AppCapture = (
            Get-ItemPropertyValue `
                -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -ErrorAction Stop
        )
    }
    catch {
        $backup.AppCapture = $null
    }

    $backup.Created = Get-Date

    $backupPath = Join-Path `
        $BackupRoot `
        "PikaTweaks-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

    $backup | ConvertTo-Json | Set-Content -Path $backupPath -Encoding UTF8

    Write-OK "Backup created."
    Write-InfoPika $backupPath

    return $backupPath
}

# ============================================================
# RESTORE
# ============================================================

function Restore-PikaSettings {

    Clear-Pika
    Write-Logo

    Write-Section "Restore / Undo"

    $files = Get-ChildItem `
        -Path $BackupRoot `
        -Filter "*.json" `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if (-not $files) {
        Write-WarningPika "No PikaTweaks backups were found."
        Pause-Pika
        return
    }

    Write-Host "Available backups:"
    Write-Host ""

    for ($i = 0; $i -lt $files.Count; $i++) {
        Write-Host "[$($i + 1)] $($files[$i].Name)"
    }

    Write-Host "[0] Cancel"
    Write-Host ""

    $selection = Read-Host "Select backup"

    if ($selection -eq "0") {
        return
    }

    $index = 0

    if (-not [int]::TryParse($selection, [ref]$index)) {
        Write-WarningPika "Invalid selection."
        Pause-Pika
        return
    }

    $index--

    if ($index -lt 0 -or $index -ge $files.Count) {
        Write-WarningPika "Invalid selection."
        Pause-Pika
        return
    }

    try {
        $backup = Get-Content $files[$index].FullName -Raw |
            ConvertFrom-Json

        if ($null -ne $backup.GameMode) {
            New-Item `
                -Path "HKCU:\Software\Microsoft\GameBar" `
                -Force | Out-Null

            Set-ItemProperty `
                -Path "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -Value ([int]$backup.GameMode)
        }

        if ($null -ne $backup.GameDVR) {
            New-Item `
                -Path "HKCU:\System\GameConfigStore" `
                -Force | Out-Null

            Set-ItemProperty `
                -Path "HKCU:\System\GameConfigStore" `
                -Name "GameDVR_Enabled" `
                -Value ([int]$backup.GameDVR)
        }

        if ($null -ne $backup.AppCapture) {
            New-Item `
                -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Force | Out-Null

            Set-ItemProperty `
                -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -Value ([int]$backup.AppCapture)
        }

        Write-OK "Registry settings restored."
        Write-InfoPika "The original power plan is shown in the backup but was not automatically changed."

    }
    catch {
        Write-WarningPika "Restore failed."
    }

    Pause-Pika
}

# ============================================================
# RESTORE POINT
# ============================================================

function New-PikaRestorePoint {

    Write-Section "System Restore Point"

    try {
        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction Stop

        Checkpoint-Computer `
            -Description "PikaTweaks V4 Backup" `
            -RestorePointType "MODIFY_SETTINGS" `
            -ErrorAction Stop

        Write-OK "Restore point created."
    }
    catch {
        Write-WarningPika "Could not create a restore point."
        Write-InfoPika "Windows System Protection may not be enabled."
    }
}

# ============================================================
# POWER PLAN
# ============================================================

function Get-CurrentPowerPlan {

    try {
        powercfg /getactivescheme
    }
    catch {}
}

function Set-GamingPowerPlan {

    Write-Section "Gaming Power Plan"

    try {
        $ultimate = powercfg -list |
            Select-String "Ultimate Performance"

        if ($ultimate) {
            powercfg -duplicatescheme `
                e9a42b02-d5df-448d-aa00-03f14749eb61 `
                2>$null | Out-Null

            $plans = powercfg /list

            $ultimateLine = $plans |
                Select-String "Ultimate Performance" |
                Select-Object -First 1

            if ($ultimateLine) {
                $guid = [regex]::Match(
                    $ultimateLine.ToString(),
                    '[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}'
                ).Value

                if ($guid) {
                    powercfg /setactive $guid
                    Write-OK "Ultimate Performance activated."
                    return
                }
            }
        }

        powercfg /setactive SCHEME_MIN

        Write-OK "High Performance power plan activated."
    }
    catch {
        Write-WarningPika "Could not change the power plan."
    }
}

# ============================================================
# GAME MODE
# ============================================================

function Enable-PikaGameMode {

    Write-Section "Windows Game Mode"

    try {
        New-Item `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Force | Out-Null

        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Name "AutoGameModeEnabled" `
            -Type DWord `
            -Value 1

        Write-OK "Windows Game Mode enabled."
    }
    catch {
        Write-WarningPika "Could not enable Game Mode."
    }
}

# ============================================================
# GAME DVR
# ============================================================

function Disable-PikaGameCapture {

    Write-Section "Background Game Capture"

    try {
        New-Item `
            -Path "HKCU:\System\GameConfigStore" `
            -Force | Out-Null

        Set-ItemProperty `
            -Path "HKCU:\System\GameConfigStore" `
            -Name "GameDVR_Enabled" `
            -Type DWord `
            -Value 0

        New-Item `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Force | Out-Null

        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Name "AppCaptureEnabled" `
            -Type DWord `
            -Value 0

        Write-OK "Background Game Capture disabled."
    }
    catch {
        Write-WarningPika "Could not change Game Capture settings."
    }
}

# ============================================================
# TEMP CLEANUP
# ============================================================

function Clean-PikaTemp {

    Write-Section "Temporary File Cleanup"

    $targets = @(
        $env:TEMP,
        "$env:WINDIR\Temp"
    )

    foreach ($target in $targets) {

        if (-not (Test-Path $target)) {
            continue
        }

        Write-InfoPika "Cleaning $target"

        Get-ChildItem `
            -Path $target `
            -Force `
            -ErrorAction SilentlyContinue |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
    }

    Write-OK "Temporary-file cleanup completed."
}

# ============================================================
# DNS
# ============================================================

function Flush-PikaDNS {

    Write-Section "DNS Cache"

    try {
        Clear-DnsClientCache
        Write-OK "DNS cache flushed."
    }
    catch {
        ipconfig /flushdns | Out-Null
        Write-OK "DNS cache flushed."
    }
}

# ============================================================
# NETWORK
# ============================================================

function Network-Refresh {

    Clear-Pika
    Write-Logo

    Write-Section "Network Refresh"

    Write-Host "This performs a Winsock reset."
    Write-Host "A Windows restart may be required afterwards." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (Y/N)"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    try {
        ipconfig /flushdns | Out-Null
        netsh winsock reset | Out-Null

        Write-OK "DNS cache flushed."
        Write-OK "Winsock reset completed."
        Write-WarningPika "Restart Windows before expecting the reset to take effect."
    }
    catch {
        Write-WarningPika "Network refresh failed."
    }

    Pause-Pika
}

# ============================================================
# DISK CLEANUP
# ============================================================

function Run-DiskCleanup {

    Clear-Pika
    Write-Logo

    Write-Section "Windows Disk Cleanup"

    try {
        Start-Process `
            cleanmgr.exe `
            -ArgumentList "/verylowdisk" `
            -Wait

        Write-OK "Disk Cleanup finished."
    }
    catch {
        Write-WarningPika "Disk Cleanup could not be started."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - DEFENDER
# ============================================================

function Security-DefenderAudit {

    Clear-Pika
    Write-Logo

    Write-Section "Microsoft Defender Audit"

    try {

        $status = Get-MpComputerStatus -ErrorAction Stop

        $realTime = if ($status.RealTimeProtectionEnabled) {
            "ON"
        } else {
            "OFF"
        }

        $antivirus = if ($status.AntivirusEnabled) {
            "ON"
        } else {
            "OFF"
        }

        $antispyware = if ($status.AntispywareEnabled) {
            "ON"
        } else {
            "OFF"
        }

        $behavior = if ($status.BehaviorMonitorEnabled) {
            "ON"
        } else {
            "OFF"
        }

        Write-Host "Real-time Protection : $realTime"
        Write-Host "Antivirus            : $antivirus"
        Write-Host "Antispyware          : $antispyware"
        Write-Host "Behavior Monitoring  : $behavior"
        Write-Host "Engine Version       : $($status.AMEngineVersion)"
        Write-Host "Signature Version    : $($status.AntivirusSignatureVersion)"
        Write-Host ""

        if ($status.RealTimeProtectionEnabled -and
            $status.AntivirusEnabled) {

            Write-OK "Defender protection appears enabled."
        }
        else {
            Write-WarningPika "One or more Defender protections are disabled."
        }

    }
    catch {
        Write-WarningPika "Defender status could not be queried."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - FIREWALL
# ============================================================

function Security-FirewallAudit {

    Clear-Pika
    Write-Logo

    Write-Section "Windows Firewall Audit"

    try {

        $profiles = Get-NetFirewallProfile -ErrorAction Stop

        foreach ($profile in $profiles) {

            $state = if ($profile.Enabled) {
                "ON"
            } else {
                "OFF"
            }

            Write-Host ("{0,-10}: {1}" -f $profile.Name, $state)

            if ($profile.Enabled) {
                Write-OK "$($profile.Name) firewall enabled."
            }
            else {
                Write-WarningPika "$($profile.Name) firewall disabled."
            }

            Write-Host ""
        }

    }
    catch {
        Write-WarningPika "Firewall information could not be queried."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - UAC
# ============================================================

function Security-UACAudit {

    Clear-Pika
    Write-Logo

    Write-Section "User Account Control Audit"

    try {

        $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        $uac = Get-ItemProperty `
            -Path $path `
            -ErrorAction Stop

        Write-Host "EnableLUA                  : $($uac.EnableLUA)"
        Write-Host "ConsentPromptBehaviorAdmin : $($uac.ConsentPromptBehaviorAdmin)"
        Write-Host ""

        if ($uac.EnableLUA -eq 1) {
            Write-OK "UAC is enabled."
        }
        else {
            Write-WarningPika "UAC appears to be disabled."
        }

        Write-Host ""
        Write-InfoPika "PikaTweaks does not modify UAC."
    }
    catch {
        Write-WarningPika "UAC information could not be queried."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - RISKY SETTINGS
# ============================================================

function Security-RiskySettings {

    Clear-Pika
    Write-Logo

    Write-Section "Risky Settings Scan"

    $warnings = 0

    # PowerShell policy
    Write-Host "PowerShell Execution Policy:" -ForegroundColor Cyan

    $policies = Get-ExecutionPolicy -List

    foreach ($policy in $policies) {
        Write-Host ("  {0,-15}: {1}" -f `
            $policy.Scope,
            $policy.ExecutionPolicy)
    }

    $permissive = $policies | Where-Object {
        $_.ExecutionPolicy -eq "Bypass" -or
        $_.ExecutionPolicy -eq "Unrestricted"
    }

    if ($permissive) {
        Write-WarningPika "A PowerShell scope uses Bypass/Unrestricted."
        $warnings++
    }
    else {
        Write-OK "No Bypass/Unrestricted policy detected."
    }

    Write-Host ""

    # SMBv1
    try {

        $smb = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -ErrorAction Stop

        if ($smb.State -eq "Enabled") {
            Write-WarningPika "SMBv1 is enabled."
            $warnings++
        }
        else {
            Write-OK "SMBv1 is not enabled."
        }

    }
    catch {
        Write-InfoPika "SMBv1 status unavailable."
    }

    Write-Host ""

    # RDP
    try {

        $rdp = Get-ItemPropertyValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections" `
            -ErrorAction Stop

        if ($rdp -eq 0) {
            Write-WarningPika "Remote Desktop is enabled."
            $warnings++
        }
        else {
            Write-OK "Remote Desktop is disabled."
        }

    }
    catch {
        Write-InfoPika "Remote Desktop status unavailable."
    }

    Write-Host ""

    # Defender exclusions
    try {

        $prefs = Get-MpPreference -ErrorAction Stop

        $exclusions = @(
            $prefs.ExclusionPath
            $prefs.ExclusionProcess
            $prefs.ExclusionExtension
            $prefs.ExclusionIpAddress
        ) | Where-Object {
            $_
        }

        if ($exclusions.Count -gt 0) {

            Write-WarningPika "Defender exclusions detected:"

            foreach ($exclusion in $exclusions) {
                Write-Host "  - $exclusion"
            }

            $warnings++
        }
        else {
            Write-OK "No Defender exclusions detected."
        }

    }
    catch {
        Write-InfoPika "Defender exclusions unavailable."
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------"

    if ($warnings -eq 0) {
        Write-OK "No obvious risky settings detected."
    }
    else {
        Write-WarningPika "$warnings item(s) require review."
    }

    Write-Host ""
    Write-InfoPika "This scan does not change security settings."

    Pause-Pika
}

# ============================================================
# SECURITY - REPORT
# ============================================================

function Export-SecurityReport {

    Clear-Pika
    Write-Logo

    Write-Section "Export Security Report"

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    $reportPath = Join-Path `
        $ReportRoot `
        "Security-Audit-$timestamp.txt"

    $lines = @()

    $lines += "PikaTweaks V4 Security Audit"
    $lines += "Generated: $(Get-Date)"
    $lines += "Computer: $env:COMPUTERNAME"
    $lines += ""

    # Defender
    $lines += "=== MICROSOFT DEFENDER ==="

    try {

        $defender = Get-MpComputerStatus `
            -ErrorAction Stop

        $lines += "Real-time Protection: $($defender.RealTimeProtectionEnabled)"
        $lines += "Antivirus: $($defender.AntivirusEnabled)"
        $lines += "Antispyware: $($defender.AntispywareEnabled)"
        $lines += "Behavior Monitoring: $($defender.BehaviorMonitorEnabled)"
        $lines += "Engine: $($defender.AMEngineVersion)"
        $lines += "Signatures: $($defender.AntivirusSignatureVersion)"

    }
    catch {
        $lines += "Defender status unavailable."
    }

    # Firewall
    $lines += ""
    $lines += "=== FIREWALL ==="

    try {

        Get-NetFirewallProfile | ForEach-Object {
            $lines += "$($_.Name): Enabled=$($_.Enabled)"
        }

    }
    catch {
        $lines += "Firewall status unavailable."
    }

    # UAC
    $lines += ""
    $lines += "=== UAC ==="

    try {

        $uac = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        $lines += "EnableLUA: $($uac.EnableLUA)"
        $lines += "ConsentPromptBehaviorAdmin: $($uac.ConsentPromptBehaviorAdmin)"

    }
    catch {
        $lines += "UAC status unavailable."
    }

    # PowerShell
    $lines += ""
    $lines += "=== POWERSHELL POLICY ==="

    Get-ExecutionPolicy -List | ForEach-Object {
        $lines += "$($_.Scope): $($_.ExecutionPolicy)"
    }

    # SMB
    $lines += ""
    $lines += "=== SMBv1 ==="

    try {

        $smb = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol

        $lines += "State: $($smb.State)"

    }
    catch {
        $lines += "SMBv1 status unavailable."
    }

    # RDP
    $lines += ""
    $lines += "=== REMOTE DESKTOP ==="

    try {

        $rdp = Get-ItemPropertyValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections"

        $lines += "Enabled: $($rdp -eq 0)"

    }
    catch {
        $lines += "RDP status unavailable."
    }

    $lines | Out-File `
        -FilePath $reportPath `
        -Encoding UTF8

    Write-OK "Security report exported."
    Write-Host ""
    Write-Host $reportPath -ForegroundColor Cyan

    Pause-Pika
}

# ============================================================
# SECURITY MENU
# ============================================================

function Security-AdvancedMenu {

    do {

        Clear-Pika
        Write-Logo

        Write-Section "SECURITY / ADVANCED"

        Write-Host "[1] Defender Audit"
        Write-Host "[2] Firewall Audit"
        Write-Host "[3] UAC Audit"
        Write-Host "[4] Risky Settings Scan"
        Write-Host "[5] Full Security Audit"
        Write-Host "[6] Export Security Report"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Security-DefenderAudit
            }

            "2" {
                Security-FirewallAudit
            }

            "3" {
                Security-UACAudit
            }

            "4" {
                Security-RiskySettings
            }

            "5" {

                Security-DefenderAudit
                Security-FirewallAudit
                Security-UACAudit
                Security-RiskySettings
            }

            "6" {
                Export-SecurityReport
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# GAMING MENU
# ============================================================

function Gaming-Menu {

    do {

        Clear-Pika
        Write-Logo

        Write-Section "GAMING TWEAKS"

        Write-Host "[1] Enable Game Mode"
        Write-Host "[2] Disable Background Game Capture"
        Write-Host "[3] Gaming Power Plan"
        Write-Host "[4] Apply Gaming Profile"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Enable-PikaGameMode
                Pause-Pika
            }

            "2" {
                Disable-PikaGameCapture
                Pause-Pika
            }

            "3" {
                Set-GamingPowerPlan
                Pause-Pika
            }

            "4" {
                Backup-PikaSettings
                New-PikaRestorePoint
                Set-GamingPowerPlan
                Enable-PikaGameMode
                Disable-PikaGameCapture

                Write-Host ""
                Write-OK "Gaming profile applied."
                Pause-Pika
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# CLEANUP MENU
# ============================================================

function Cleanup-Menu {

    do {

        Clear-Pika
        Write-Logo

        Write-Section "CLEANUP"

        Write-Host "[1] Clean Temporary Files"
        Write-Host "[2] Windows Disk Cleanup"
        Write-Host "[3] Flush DNS"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Clean-PikaTemp
                Pause-Pika
            }

            "2" {
                Run-DiskCleanup
            }

            "3" {
                Flush-PikaDNS
                Pause-Pika
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# DASHBOARD
# ============================================================

function Show-Dashboard {

    Clear-Pika
    Write-Logo

    Write-Section "SYSTEM DASHBOARD"

    try {

        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor |
            Select-Object -First 1

        $computer = Get-CimInstance Win32_ComputerSystem

        Write-Host "Computer       : $env:COMPUTERNAME"
        Write-Host "Windows        : $($os.Caption)"
        Write-Host "Build          : $($os.BuildNumber)"
        Write-Host "CPU            : $($cpu.Name)"
        Write-Host "RAM            : $([math]::Round($computer.TotalPhysicalMemory / 1GB, 1)) GB"
        Write-Host ""

    }
    catch {
        Write-WarningPika "System information unavailable."
    }

    Write-Host "Power Plan:"
    Get-CurrentPowerPlan

    Write-Host ""

    try {

        $gameMode = Get-ItemPropertyValue `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Name "AutoGameModeEnabled" `
            -ErrorAction Stop

        if ($gameMode -eq 1) {
            Write-Host "Game Mode      : ON" -ForegroundColor Green
        }
        else {
            Write-Host "Game Mode      : OFF" -ForegroundColor Yellow
        }

    }
    catch {
        Write-Host "Game Mode      : Unknown"
    }

    Pause-Pika
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

function Show-SystemInformation {

    Clear-Pika
    Write-Logo

    Write-Section "SYSTEM INFORMATION"

    try {

        Get-CimInstance Win32_ComputerSystem |
            Select-Object `
                Manufacturer,
                Model,
                TotalPhysicalMemory |
            Format-List

        Get-CimInstance Win32_Processor |
            Select-Object `
                Name,
                NumberOfCores,
                NumberOfLogicalProcessors,
                MaxClockSpeed |
            Format-List

        Get-CimInstance Win32_VideoController |
            Select-Object `
                Name,
                DriverVersion,
                VideoMemoryType |
            Format-List

        Get-CimInstance Win32_OperatingSystem |
            Select-Object `
                Caption,
                Version,
                BuildNumber,
                OSArchitecture |
            Format-List

    }
    catch {
        Write-WarningPika "Could not collect all system information."
    }

    Pause-Pika
}

# ============================================================
# ONE CLICK OPTIMIZE
# ============================================================

function One-ClickOptimize {

    Clear-Pika
    Write-Logo

    Write-Section "ONE-CLICK OPTIMIZE"

    Write-Host "PikaTweaks will:"
    Write-Host ""
    Write-Host "  - Create a backup"
    Write-Host "  - Attempt a restore point"
    Write-Host "  - Set a gaming power plan"
    Write-Host "  - Enable Game Mode"
    Write-Host "  - Disable background Game Capture"
    Write-Host "  - Clean temporary files"
    Write-Host "  - Flush DNS"
    Write-Host ""
    Write-Host "Network reset and security settings are NOT changed."
    Write-Host ""

    $confirm = Read-Host "Start optimization? (Y/N)"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    Backup-PikaSettings

    New-PikaRestorePoint

    Set-GamingPowerPlan

    Enable-PikaGameMode

    Disable-PikaGameCapture

    Clean-PikaTemp

    Flush-PikaDNS

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             OPTIMIZATION COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Restart Windows if you want all changes to fully apply."

    Pause-Pika
}

# ============================================================
# MAIN MENU
# ============================================================

function Main-Menu {

    do {

        Clear-Pika
        Write-Logo

        Write-Host "[1] Dashboard"
        Write-Host "[2] One-Click Optimize"
        Write-Host "[3] Gaming Tweaks"
        Write-Host "[4] Cleanup"
        Write-Host "[5] Network"
        Write-Host "[6] Security / Advanced"
        Write-Host "[7] Backup & Restore"
        Write-Host "[8] System Information"
        Write-Host "[0] Exit"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Show-Dashboard
            }

            "2" {
                One-ClickOptimize
            }

            "3" {
                Gaming-Menu
            }

            "4" {
                Cleanup-Menu
            }

            "5" {
                Network-Refresh
            }

            "6" {
                Security-AdvancedMenu
            }

            "7" {
                Restore-PikaSettings
            }

            "8" {
                Show-SystemInformation
            }

            "0" {
                Clear-Pika
                Write-Host ""
                Write-Host "Thanks for using PikaTweaks V4!" -ForegroundColor Cyan
                Write-Host ""
                break
            }

            default {
                Write-WarningPika "Invalid option."
                Start-Sleep -Milliseconds 800
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# START
# ============================================================

Main-Menu
``````powershell
# ============================================================
# PikaTweaks V4
# Windows 11 Gaming & System Utility
#
# Safe / reversible edition
# - Gaming optimization
# - Cleanup
# - Power plans
# - Game Mode / Game DVR
# - Network tools
# - Security / Advanced audit
# - Backup / Restore
# - System dashboard
#
# Does NOT disable Windows Defender, Firewall or UAC.
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$PikaRoot   = Join-Path $env:ProgramData "PikaTweaks"
$BackupRoot = Join-Path $PikaRoot "Backups"
$ReportRoot = Join-Path $PikaRoot "Reports"

New-Item -ItemType Directory -Path $PikaRoot -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

# ============================================================
# ADMIN
# ============================================================

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-IsAdmin)) {
    Write-Host ""
    Write-Host "PikaTweaks requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Restarting as Administrator..." -ForegroundColor Cyan

    $scriptPath = $MyInvocation.MyCommand.Path

    if ($scriptPath) {
        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    }
    else {
        Write-Host ""
        Write-Host "Please run PowerShell as Administrator." -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }

    exit
}

# ============================================================
# UI
# ============================================================

function Clear-Pika {
    Clear-Host
}

function Write-Logo {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                    PIKATWEAKS V4" -ForegroundColor Magenta
    Write-Host "              WINDOWS GAMING UTILITY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Pika {
    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Write-OK {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-WarningPika {
    param([string]$Text)
    Write-Host "[WARNING] $Text" -ForegroundColor Yellow
}

function Write-InfoPika {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

# ============================================================
# BACKUP
# ============================================================

function Backup-PikaSettings {

    Write-Section "Creating Backup"

    $backup = [ordered]@{}

    # Current power scheme
    try {
        $power = powercfg /getactivescheme

        if ($power) {
            $backup.PowerScheme = ($power | Out-String).Trim()
        }
    }
    catch {}

    # Game Mode
    try {
        $backup.GameMode = (
            Get-ItemPropertyValue `
                -Path "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -ErrorAction Stop
        )
    }
    catch {
        $backup.GameMode = $null
    }

    # Game DVR
    try {
        $backup.GameDVR = (
            Get-ItemPropertyValue `
                -Path "HKCU:\System\GameConfigStore" `
                -Name "GameDVR_Enabled" `
                -ErrorAction Stop
        )
    }
    catch {
        $backup.GameDVR = $null
    }

    # App Capture
    try {
        $backup.AppCapture = (
            Get-ItemPropertyValue `
                -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -ErrorAction Stop
        )
    }
    catch {
        $backup.AppCapture = $null
    }

    $backup.Created = Get-Date

    $backupPath = Join-Path `
        $BackupRoot `
        "PikaTweaks-Backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

    $backup | ConvertTo-Json | Set-Content -Path $backupPath -Encoding UTF8

    Write-OK "Backup created."
    Write-InfoPika $backupPath

    return $backupPath
}

# ============================================================
# RESTORE
# ============================================================

function Restore-PikaSettings {

    Clear-Pika
    Write-Logo

    Write-Section "Restore / Undo"

    $files = Get-ChildItem `
        -Path $BackupRoot `
        -Filter "*.json" `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if (-not $files) {
        Write-WarningPika "No PikaTweaks backups were found."
        Pause-Pika
        return
    }

    Write-Host "Available backups:"
    Write-Host ""

    for ($i = 0; $i -lt $files.Count; $i++) {
        Write-Host "[$($i + 1)] $($files[$i].Name)"
    }

    Write-Host "[0] Cancel"
    Write-Host ""

    $selection = Read-Host "Select backup"

    if ($selection -eq "0") {
        return
    }

    $index = 0

    if (-not [int]::TryParse($selection, [ref]$index)) {
        Write-WarningPika "Invalid selection."
        Pause-Pika
        return
    }

    $index--

    if ($index -lt 0 -or $index -ge $files.Count) {
        Write-WarningPika "Invalid selection."
        Pause-Pika
        return
    }

    try {
        $backup = Get-Content $files[$index].FullName -Raw |
            ConvertFrom-Json

        if ($null -ne $backup.GameMode) {
            New-Item `
                -Path "HKCU:\Software\Microsoft\GameBar" `
                -Force | Out-Null

            Set-ItemProperty `
                -Path "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -Value ([int]$backup.GameMode)
        }

        if ($null -ne $backup.GameDVR) {
            New-Item `
                -Path "HKCU:\System\GameConfigStore" `
                -Force | Out-Null

            Set-ItemProperty `
                -Path "HKCU:\System\GameConfigStore" `
                -Name "GameDVR_Enabled" `
                -Value ([int]$backup.GameDVR)
        }

        if ($null -ne $backup.AppCapture) {
            New-Item `
                -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Force | Out-Null

            Set-ItemProperty `
                -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -Value ([int]$backup.AppCapture)
        }

        Write-OK "Registry settings restored."
        Write-InfoPika "The original power plan is shown in the backup but was not automatically changed."

    }
    catch {
        Write-WarningPika "Restore failed."
    }

    Pause-Pika
}

# ============================================================
# RESTORE POINT
# ============================================================

function New-PikaRestorePoint {

    Write-Section "System Restore Point"

    try {
        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction Stop

        Checkpoint-Computer `
            -Description "PikaTweaks V4 Backup" `
            -RestorePointType "MODIFY_SETTINGS" `
            -ErrorAction Stop

        Write-OK "Restore point created."
    }
    catch {
        Write-WarningPika "Could not create a restore point."
        Write-InfoPika "Windows System Protection may not be enabled."
    }
}

# ============================================================
# POWER PLAN
# ============================================================

function Get-CurrentPowerPlan {

    try {
        powercfg /getactivescheme
    }
    catch {}
}

function Set-GamingPowerPlan {

    Write-Section "Gaming Power Plan"

    try {
        $ultimate = powercfg -list |
            Select-String "Ultimate Performance"

        if ($ultimate) {
            powercfg -duplicatescheme `
                e9a42b02-d5df-448d-aa00-03f14749eb61 `
                2>$null | Out-Null

            $plans = powercfg /list

            $ultimateLine = $plans |
                Select-String "Ultimate Performance" |
                Select-Object -First 1

            if ($ultimateLine) {
                $guid = [regex]::Match(
                    $ultimateLine.ToString(),
                    '[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}'
                ).Value

                if ($guid) {
                    powercfg /setactive $guid
                    Write-OK "Ultimate Performance activated."
                    return
                }
            }
        }

        powercfg /setactive SCHEME_MIN

        Write-OK "High Performance power plan activated."
    }
    catch {
        Write-WarningPika "Could not change the power plan."
    }
}

# ============================================================
# GAME MODE
# ============================================================

function Enable-PikaGameMode {

    Write-Section "Windows Game Mode"

    try {
        New-Item `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Force | Out-Null

        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Name "AutoGameModeEnabled" `
            -Type DWord `
            -Value 1

        Write-OK "Windows Game Mode enabled."
    }
    catch {
        Write-WarningPika "Could not enable Game Mode."
    }
}

# ============================================================
# GAME DVR
# ============================================================

function Disable-PikaGameCapture {

    Write-Section "Background Game Capture"

    try {
        New-Item `
            -Path "HKCU:\System\GameConfigStore" `
            -Force | Out-Null

        Set-ItemProperty `
            -Path "HKCU:\System\GameConfigStore" `
            -Name "GameDVR_Enabled" `
            -Type DWord `
            -Value 0

        New-Item `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Force | Out-Null

        Set-ItemProperty `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Name "AppCaptureEnabled" `
            -Type DWord `
            -Value 0

        Write-OK "Background Game Capture disabled."
    }
    catch {
        Write-WarningPika "Could not change Game Capture settings."
    }
}

# ============================================================
# TEMP CLEANUP
# ============================================================

function Clean-PikaTemp {

    Write-Section "Temporary File Cleanup"

    $targets = @(
        $env:TEMP,
        "$env:WINDIR\Temp"
    )

    foreach ($target in $targets) {

        if (-not (Test-Path $target)) {
            continue
        }

        Write-InfoPika "Cleaning $target"

        Get-ChildItem `
            -Path $target `
            -Force `
            -ErrorAction SilentlyContinue |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
    }

    Write-OK "Temporary-file cleanup completed."
}

# ============================================================
# DNS
# ============================================================

function Flush-PikaDNS {

    Write-Section "DNS Cache"

    try {
        Clear-DnsClientCache
        Write-OK "DNS cache flushed."
    }
    catch {
        ipconfig /flushdns | Out-Null
        Write-OK "DNS cache flushed."
    }
}

# ============================================================
# NETWORK
# ============================================================

function Network-Refresh {

    Clear-Pika
    Write-Logo

    Write-Section "Network Refresh"

    Write-Host "This performs a Winsock reset."
    Write-Host "A Windows restart may be required afterwards." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (Y/N)"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    try {
        ipconfig /flushdns | Out-Null
        netsh winsock reset | Out-Null

        Write-OK "DNS cache flushed."
        Write-OK "Winsock reset completed."
        Write-WarningPika "Restart Windows before expecting the reset to take effect."
    }
    catch {
        Write-WarningPika "Network refresh failed."
    }

    Pause-Pika
}

# ============================================================
# DISK CLEANUP
# ============================================================

function Run-DiskCleanup {

    Clear-Pika
    Write-Logo

    Write-Section "Windows Disk Cleanup"

    try {
        Start-Process `
            cleanmgr.exe `
            -ArgumentList "/verylowdisk" `
            -Wait

        Write-OK "Disk Cleanup finished."
    }
    catch {
        Write-WarningPika "Disk Cleanup could not be started."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - DEFENDER
# ============================================================

function Security-DefenderAudit {

    Clear-Pika
    Write-Logo

    Write-Section "Microsoft Defender Audit"

    try {

        $status = Get-MpComputerStatus -ErrorAction Stop

        $realTime = if ($status.RealTimeProtectionEnabled) {
            "ON"
        } else {
            "OFF"
        }

        $antivirus = if ($status.AntivirusEnabled) {
            "ON"
        } else {
            "OFF"
        }

        $antispyware = if ($status.AntispywareEnabled) {
            "ON"
        } else {
            "OFF"
        }

        $behavior = if ($status.BehaviorMonitorEnabled) {
            "ON"
        } else {
            "OFF"
        }

        Write-Host "Real-time Protection : $realTime"
        Write-Host "Antivirus            : $antivirus"
        Write-Host "Antispyware          : $antispyware"
        Write-Host "Behavior Monitoring  : $behavior"
        Write-Host "Engine Version       : $($status.AMEngineVersion)"
        Write-Host "Signature Version    : $($status.AntivirusSignatureVersion)"
        Write-Host ""

        if ($status.RealTimeProtectionEnabled -and
            $status.AntivirusEnabled) {

            Write-OK "Defender protection appears enabled."
        }
        else {
            Write-WarningPika "One or more Defender protections are disabled."
        }

    }
    catch {
        Write-WarningPika "Defender status could not be queried."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - FIREWALL
# ============================================================

function Security-FirewallAudit {

    Clear-Pika
    Write-Logo

    Write-Section "Windows Firewall Audit"

    try {

        $profiles = Get-NetFirewallProfile -ErrorAction Stop

        foreach ($profile in $profiles) {

            $state = if ($profile.Enabled) {
                "ON"
            } else {
                "OFF"
            }

            Write-Host ("{0,-10}: {1}" -f $profile.Name, $state)

            if ($profile.Enabled) {
                Write-OK "$($profile.Name) firewall enabled."
            }
            else {
                Write-WarningPika "$($profile.Name) firewall disabled."
            }

            Write-Host ""
        }

    }
    catch {
        Write-WarningPika "Firewall information could not be queried."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - UAC
# ============================================================

function Security-UACAudit {

    Clear-Pika
    Write-Logo

    Write-Section "User Account Control Audit"

    try {

        $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        $uac = Get-ItemProperty `
            -Path $path `
            -ErrorAction Stop

        Write-Host "EnableLUA                  : $($uac.EnableLUA)"
        Write-Host "ConsentPromptBehaviorAdmin : $($uac.ConsentPromptBehaviorAdmin)"
        Write-Host ""

        if ($uac.EnableLUA -eq 1) {
            Write-OK "UAC is enabled."
        }
        else {
            Write-WarningPika "UAC appears to be disabled."
        }

        Write-Host ""
        Write-InfoPika "PikaTweaks does not modify UAC."
    }
    catch {
        Write-WarningPika "UAC information could not be queried."
    }

    Pause-Pika
}

# ============================================================
# SECURITY - RISKY SETTINGS
# ============================================================

function Security-RiskySettings {

    Clear-Pika
    Write-Logo

    Write-Section "Risky Settings Scan"

    $warnings = 0

    # PowerShell policy
    Write-Host "PowerShell Execution Policy:" -ForegroundColor Cyan

    $policies = Get-ExecutionPolicy -List

    foreach ($policy in $policies) {
        Write-Host ("  {0,-15}: {1}" -f `
            $policy.Scope,
            $policy.ExecutionPolicy)
    }

    $permissive = $policies | Where-Object {
        $_.ExecutionPolicy -eq "Bypass" -or
        $_.ExecutionPolicy -eq "Unrestricted"
    }

    if ($permissive) {
        Write-WarningPika "A PowerShell scope uses Bypass/Unrestricted."
        $warnings++
    }
    else {
        Write-OK "No Bypass/Unrestricted policy detected."
    }

    Write-Host ""

    # SMBv1
    try {

        $smb = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol `
            -ErrorAction Stop

        if ($smb.State -eq "Enabled") {
            Write-WarningPika "SMBv1 is enabled."
            $warnings++
        }
        else {
            Write-OK "SMBv1 is not enabled."
        }

    }
    catch {
        Write-InfoPika "SMBv1 status unavailable."
    }

    Write-Host ""

    # RDP
    try {

        $rdp = Get-ItemPropertyValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections" `
            -ErrorAction Stop

        if ($rdp -eq 0) {
            Write-WarningPika "Remote Desktop is enabled."
            $warnings++
        }
        else {
            Write-OK "Remote Desktop is disabled."
        }

    }
    catch {
        Write-InfoPika "Remote Desktop status unavailable."
    }

    Write-Host ""

    # Defender exclusions
    try {

        $prefs = Get-MpPreference -ErrorAction Stop

        $exclusions = @(
            $prefs.ExclusionPath
            $prefs.ExclusionProcess
            $prefs.ExclusionExtension
            $prefs.ExclusionIpAddress
        ) | Where-Object {
            $_
        }

        if ($exclusions.Count -gt 0) {

            Write-WarningPika "Defender exclusions detected:"

            foreach ($exclusion in $exclusions) {
                Write-Host "  - $exclusion"
            }

            $warnings++
        }
        else {
            Write-OK "No Defender exclusions detected."
        }

    }
    catch {
        Write-InfoPika "Defender exclusions unavailable."
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------"

    if ($warnings -eq 0) {
        Write-OK "No obvious risky settings detected."
    }
    else {
        Write-WarningPika "$warnings item(s) require review."
    }

    Write-Host ""
    Write-InfoPika "This scan does not change security settings."

    Pause-Pika
}

# ============================================================
# SECURITY - REPORT
# ============================================================

function Export-SecurityReport {

    Clear-Pika
    Write-Logo

    Write-Section "Export Security Report"

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    $reportPath = Join-Path `
        $ReportRoot `
        "Security-Audit-$timestamp.txt"

    $lines = @()

    $lines += "PikaTweaks V4 Security Audit"
    $lines += "Generated: $(Get-Date)"
    $lines += "Computer: $env:COMPUTERNAME"
    $lines += ""

    # Defender
    $lines += "=== MICROSOFT DEFENDER ==="

    try {

        $defender = Get-MpComputerStatus `
            -ErrorAction Stop

        $lines += "Real-time Protection: $($defender.RealTimeProtectionEnabled)"
        $lines += "Antivirus: $($defender.AntivirusEnabled)"
        $lines += "Antispyware: $($defender.AntispywareEnabled)"
        $lines += "Behavior Monitoring: $($defender.BehaviorMonitorEnabled)"
        $lines += "Engine: $($defender.AMEngineVersion)"
        $lines += "Signatures: $($defender.AntivirusSignatureVersion)"

    }
    catch {
        $lines += "Defender status unavailable."
    }

    # Firewall
    $lines += ""
    $lines += "=== FIREWALL ==="

    try {

        Get-NetFirewallProfile | ForEach-Object {
            $lines += "$($_.Name): Enabled=$($_.Enabled)"
        }

    }
    catch {
        $lines += "Firewall status unavailable."
    }

    # UAC
    $lines += ""
    $lines += "=== UAC ==="

    try {

        $uac = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        $lines += "EnableLUA: $($uac.EnableLUA)"
        $lines += "ConsentPromptBehaviorAdmin: $($uac.ConsentPromptBehaviorAdmin)"

    }
    catch {
        $lines += "UAC status unavailable."
    }

    # PowerShell
    $lines += ""
    $lines += "=== POWERSHELL POLICY ==="

    Get-ExecutionPolicy -List | ForEach-Object {
        $lines += "$($_.Scope): $($_.ExecutionPolicy)"
    }

    # SMB
    $lines += ""
    $lines += "=== SMBv1 ==="

    try {

        $smb = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName SMB1Protocol

        $lines += "State: $($smb.State)"

    }
    catch {
        $lines += "SMBv1 status unavailable."
    }

    # RDP
    $lines += ""
    $lines += "=== REMOTE DESKTOP ==="

    try {

        $rdp = Get-ItemPropertyValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections"

        $lines += "Enabled: $($rdp -eq 0)"

    }
    catch {
        $lines += "RDP status unavailable."
    }

    $lines | Out-File `
        -FilePath $reportPath `
        -Encoding UTF8

    Write-OK "Security report exported."
    Write-Host ""
    Write-Host $reportPath -ForegroundColor Cyan

    Pause-Pika
}

# ============================================================
# SECURITY MENU
# ============================================================

function Security-AdvancedMenu {

    do {

        Clear-Pika
        Write-Logo

        Write-Section "SECURITY / ADVANCED"

        Write-Host "[1] Defender Audit"
        Write-Host "[2] Firewall Audit"
        Write-Host "[3] UAC Audit"
        Write-Host "[4] Risky Settings Scan"
        Write-Host "[5] Full Security Audit"
        Write-Host "[6] Export Security Report"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Security-DefenderAudit
            }

            "2" {
                Security-FirewallAudit
            }

            "3" {
                Security-UACAudit
            }

            "4" {
                Security-RiskySettings
            }

            "5" {

                Security-DefenderAudit
                Security-FirewallAudit
                Security-UACAudit
                Security-RiskySettings
            }

            "6" {
                Export-SecurityReport
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# GAMING MENU
# ============================================================

function Gaming-Menu {

    do {

        Clear-Pika
        Write-Logo

        Write-Section "GAMING TWEAKS"

        Write-Host "[1] Enable Game Mode"
        Write-Host "[2] Disable Background Game Capture"
        Write-Host "[3] Gaming Power Plan"
        Write-Host "[4] Apply Gaming Profile"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Enable-PikaGameMode
                Pause-Pika
            }

            "2" {
                Disable-PikaGameCapture
                Pause-Pika
            }

            "3" {
                Set-GamingPowerPlan
                Pause-Pika
            }

            "4" {
                Backup-PikaSettings
                New-PikaRestorePoint
                Set-GamingPowerPlan
                Enable-PikaGameMode
                Disable-PikaGameCapture

                Write-Host ""
                Write-OK "Gaming profile applied."
                Pause-Pika
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# CLEANUP MENU
# ============================================================

function Cleanup-Menu {

    do {

        Clear-Pika
        Write-Logo

        Write-Section "CLEANUP"

        Write-Host "[1] Clean Temporary Files"
        Write-Host "[2] Windows Disk Cleanup"
        Write-Host "[3] Flush DNS"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Clean-PikaTemp
                Pause-Pika
            }

            "2" {
                Run-DiskCleanup
            }

            "3" {
                Flush-PikaDNS
                Pause-Pika
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# DASHBOARD
# ============================================================

function Show-Dashboard {

    Clear-Pika
    Write-Logo

    Write-Section "SYSTEM DASHBOARD"

    try {

        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor |
            Select-Object -First 1

        $computer = Get-CimInstance Win32_ComputerSystem

        Write-Host "Computer       : $env:COMPUTERNAME"
        Write-Host "Windows        : $($os.Caption)"
        Write-Host "Build          : $($os.BuildNumber)"
        Write-Host "CPU            : $($cpu.Name)"
        Write-Host "RAM            : $([math]::Round($computer.TotalPhysicalMemory / 1GB, 1)) GB"
        Write-Host ""

    }
    catch {
        Write-WarningPika "System information unavailable."
    }

    Write-Host "Power Plan:"
    Get-CurrentPowerPlan

    Write-Host ""

    try {

        $gameMode = Get-ItemPropertyValue `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Name "AutoGameModeEnabled" `
            -ErrorAction Stop

        if ($gameMode -eq 1) {
            Write-Host "Game Mode      : ON" -ForegroundColor Green
        }
        else {
            Write-Host "Game Mode      : OFF" -ForegroundColor Yellow
        }

    }
    catch {
        Write-Host "Game Mode      : Unknown"
    }

    Pause-Pika
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

function Show-SystemInformation {

    Clear-Pika
    Write-Logo

    Write-Section "SYSTEM INFORMATION"

    try {

        Get-CimInstance Win32_ComputerSystem |
            Select-Object `
                Manufacturer,
                Model,
                TotalPhysicalMemory |
            Format-List

        Get-CimInstance Win32_Processor |
            Select-Object `
                Name,
                NumberOfCores,
                NumberOfLogicalProcessors,
                MaxClockSpeed |
            Format-List

        Get-CimInstance Win32_VideoController |
            Select-Object `
                Name,
                DriverVersion,
                VideoMemoryType |
            Format-List

        Get-CimInstance Win32_OperatingSystem |
            Select-Object `
                Caption,
                Version,
                BuildNumber,
                OSArchitecture |
            Format-List

    }
    catch {
        Write-WarningPika "Could not collect all system information."
    }

    Pause-Pika
}

# ============================================================
# ONE CLICK OPTIMIZE
# ============================================================

function One-ClickOptimize {

    Clear-Pika
    Write-Logo

    Write-Section "ONE-CLICK OPTIMIZE"

    Write-Host "PikaTweaks will:"
    Write-Host ""
    Write-Host "  - Create a backup"
    Write-Host "  - Attempt a restore point"
    Write-Host "  - Set a gaming power plan"
    Write-Host "  - Enable Game Mode"
    Write-Host "  - Disable background Game Capture"
    Write-Host "  - Clean temporary files"
    Write-Host "  - Flush DNS"
    Write-Host ""
    Write-Host "Network reset and security settings are NOT changed."
    Write-Host ""

    $confirm = Read-Host "Start optimization? (Y/N)"

    if ($confirm -notmatch "^[Yy]$") {
        return
    }

    Backup-PikaSettings

    New-PikaRestorePoint

    Set-GamingPowerPlan

    Enable-PikaGameMode

    Disable-PikaGameCapture

    Clean-PikaTemp

    Flush-PikaDNS

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             OPTIMIZATION COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Restart Windows if you want all changes to fully apply."

    Pause-Pika
}

# ============================================================
# MAIN MENU
# ============================================================

function Main-Menu {

    do {

        Clear-Pika
        Write-Logo

        Write-Host "[1] Dashboard"
        Write-Host "[2] One-Click Optimize"
        Write-Host "[3] Gaming Tweaks"
        Write-Host "[4] Cleanup"
        Write-Host "[5] Network"
        Write-Host "[6] Security / Advanced"
        Write-Host "[7] Backup & Restore"
        Write-Host "[8] System Information"
        Write-Host "[0] Exit"
        Write-Host ""

        $choice = Read-Host "Select an option"

        switch ($choice) {

            "1" {
                Show-Dashboard
            }

            "2" {
                One-ClickOptimize
            }

            "3" {
                Gaming-Menu
            }

            "4" {
                Cleanup-Menu
            }

            "5" {
                Network-Refresh
            }

            "6" {
                Security-AdvancedMenu
            }

            "7" {
                Restore-PikaSettings
            }

            "8" {
                Show-SystemInformation
            }

            "0" {
                Clear-Pika
                Write-Host ""
                Write-Host "Thanks for using PikaTweaks V4!" -ForegroundColor Cyan
                Write-Host ""
                break
            }

            default {
                Write-WarningPika "Invalid option."
                Start-Sleep -Milliseconds 800
            }
        }

    } while ($choice -ne "0")
}

# ============================================================
# START
# ============================================================

Main-Menu
```
