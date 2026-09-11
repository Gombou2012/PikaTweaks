```powershell
#requires -Version 5.1

<#
.SYNOPSIS
    PikaTweaks - Windows Optimization Utility

.DESCRIPTION
    An original Windows optimization utility focused on gaming,
    cleanup, networking, privacy and system maintenance.

.NOTES
    Designed for Windows 10/11.
    Administrative privileges are required for several operations.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================

$script:PikaVersion = "1.0.0"
$script:PikaRoot = Join-Path $env:ProgramData "PikaTweaks"
$script:BackupRoot = Join-Path $script:PikaRoot "Backups"
$script:LogFile = Join-Path $script:PikaRoot "PikaTweaks.log"

if (-not (Test-Path $script:PikaRoot)) {
    New-Item -ItemType Directory -Path $script:PikaRoot -Force | Out-Null
}

if (-not (Test-Path $script:BackupRoot)) {
    New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
}

# ============================================================
# ADMINISTRATOR
# ============================================================

function Test-PikaAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Start-PikaElevated {
    if (Test-PikaAdmin) {
        return $true
    }

    Write-Host ""
    Write-Host "PikaTweaks requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Yellow

    try {
        $args = @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-Command"
            "irm 'https://raw.githubusercontent.com/Gombou2012/PikaTweaks/main/PikaTweaks.ps1' | iex"
        )

        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList $args

        return $false
    }
    catch {
        Write-Host "Could not request Administrator privileges." -ForegroundColor Red
        return $false
    }
}

# ============================================================
# LOGGING
# ============================================================

function Write-PikaLog {
    param(
        [string]$Message
    )

    try {
        $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path $script:LogFile -Value $line -ErrorAction SilentlyContinue
    }
    catch {}
}

# ============================================================
# UI
# ============================================================

function Show-PikaHeader {
    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                      P I K A T W E A K S" -ForegroundColor Magenta
    Write-Host "                Windows Optimization Utility" -ForegroundColor Cyan
    Write-Host "                         v$script:PikaVersion" -ForegroundColor DarkCyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Pika {
    Write-Host ""
    Read-Host "Press ENTER to continue" | Out-Null
}

function Confirm-Pika {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $answer = Read-Host "Continue? [Y/N]"

    return ($answer -match "^(y|yes)$")
}

# ============================================================
# RESTORE POINT
# ============================================================

function New-PikaRestorePoint {
    Show-PikaHeader

    Write-Host "CREATE SYSTEM RESTORE POINT" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"

    if (-not (Confirm-Pika "Windows will attempt to create a restore point.")) {
        return
    }

    Write-PikaLog "Creating system restore point."

    try {
        Enable-ComputerRestore `
            -Drive "$env:SystemDrive\" `
            -ErrorAction SilentlyContinue

        Checkpoint-Computer `
            -Description "PikaTweaks $script:PikaVersion" `
            -RestorePointType "MODIFY_SETTINGS" `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "[+] Restore point created." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "[!] Windows could not create a restore point." -ForegroundColor Yellow
        Write-Host "    System Protection may be disabled or unavailable." -ForegroundColor Yellow
    }

    Pause-Pika
}

# ============================================================
# BACKUP
# ============================================================

function Backup-PikaSettings {
    Write-PikaLog "Creating PikaTweaks configuration backup."

    $backup = [ordered]@{
        Created = (Get-Date).ToString("o")
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        PowerPlan = ((powercfg /getactivescheme) -join " ")
    }

    $file = Join-Path `
        $script:BackupRoot `
        ("Backup-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

    $backup | ConvertTo-Json | Set-Content `
        -Path $file `
        -Encoding UTF8

    Write-Host "[+] Backup saved:" -ForegroundColor Green
    Write-Host "    $file" -ForegroundColor DarkGray
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

function Show-SystemInformation {
    Show-PikaHeader

    Write-Host "SYSTEM INFORMATION" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"

    try {
        $computer = Get-CimInstance Win32_ComputerSystem
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor |
            Select-Object -First 1
        $gpu = Get-CimInstance Win32_VideoController |
            Where-Object { $_.Name } |
            Select-Object -First 1

        Write-Host ""
        Write-Host "Computer : $env:COMPUTERNAME"
        Write-Host "User     : $env:USERNAME"
        Write-Host "Windows  : $($os.Caption)"
        Write-Host "Build    : $($os.BuildNumber)"
        Write-Host "CPU      : $($cpu.Name)"
        Write-Host "Cores    : $($cpu.NumberOfCores)"
        Write-Host "Threads  : $($cpu.NumberOfLogicalProcessors)"
        Write-Host "RAM      : $([math]::Round($computer.TotalPhysicalMemory / 1GB, 1)) GB"

        if ($gpu) {
            Write-Host "GPU      : $($gpu.Name)"
        }

        Write-Host ""
        Write-Host "Power Plan:" -ForegroundColor Cyan
        powercfg /getactivescheme

        Write-PikaLog "Viewed system information."
    }
    catch {
        Write-Host "Could not retrieve all system information." -ForegroundColor Yellow
    }

    Pause-Pika
}

# ============================================================
# POWER
# ============================================================

function Set-PikaPowerPlan {
    Show-PikaHeader

    Write-Host "POWER & PERFORMANCE" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[1] Balanced"
    Write-Host "[2] High Performance"
    Write-Host "[3] Ultimate Performance"
    Write-Host "[4] List available plans"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {
        "1" {
            powercfg /setactive SCHEME_BALANCED
            Write-Host "[+] Balanced selected." -ForegroundColor Green
            Pause-Pika
        }

        "2" {
            powercfg /setactive SCHEME_MAX
            Write-Host "[+] High Performance selected." -ForegroundColor Green
            Pause-Pika
        }

        "3" {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
            powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61

            Write-Host "[+] Ultimate Performance requested." -ForegroundColor Green
            Pause-Pika
        }

        "4" {
            powercfg /list
            Pause-Pika
        }
    }
}

# ============================================================
# GAMING
# ============================================================

function Set-GamingTweaks {
    Show-PikaHeader

    Write-Host "GAMING TWEAKS" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""

    Write-Host "[1] Enable Windows Game Mode"
    Write-Host "[2] Disable background Game DVR capture"
    Write-Host "[3] Enable Hardware Accelerated GPU Scheduling"
    Write-Host "[4] Apply all recommended gaming settings"
    Write-Host "[5] Open Windows Gaming settings"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {

        "1" {
            New-Item `
                "HKCU:\Software\Microsoft\GameBar" `
                -Force | Out-Null

            Set-ItemProperty `
                "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -Type DWord `
                -Value 1 `
                -Force

            Write-PikaLog "Enabled Game Mode."
            Write-Host "[+] Game Mode enabled." -ForegroundColor Green
            Pause-Pika
        }

        "2" {
            New-Item `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Force | Out-Null

            Set-ItemProperty `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -Type DWord `
                -Value 0 `
                -Force

            Write-PikaLog "Disabled Game DVR capture."
            Write-Host "[+] Background Game DVR capture disabled." -ForegroundColor Green
            Pause-Pika
        }

        "3" {
            $path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

            New-Item $path -Force | Out-Null

            Set-ItemProperty `
                $path `
                -Name "HwSchMode" `
                -Type DWord `
                -Value 2 `
                -Force

            Write-PikaLog "Enabled HAGS."
            Write-Host "[+] Hardware Accelerated GPU Scheduling enabled." -ForegroundColor Green
            Write-Host "    A Windows restart may be required." -ForegroundColor Yellow
            Pause-Pika
        }

        "4" {
            if (-not (Confirm-Pika "Apply the recommended gaming settings?")) {
                return
            }

            Backup-PikaSettings

            New-Item `
                "HKCU:\Software\Microsoft\GameBar" `
                -Force | Out-Null

            Set-ItemProperty `
                "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -Type DWord `
                -Value 1 `
                -Force

            New-Item `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Force | Out-Null

            Set-ItemProperty `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -Type DWord `
                -Value 0 `
                -Force

            powercfg /setactive SCHEME_MAX

            Write-PikaLog "Applied recommended gaming settings."

            Write-Host ""
            Write-Host "[+] Gaming optimization completed." -ForegroundColor Green
            Write-Host "[!] Restart Windows if requested by a setting." -ForegroundColor Yellow

            Pause-Pika
        }

        "5" {
            Start-Process "ms-settings:gaming"
        }
    }
}

# ============================================================
# WINDOWS TWEAKS
# ============================================================

function Set-WindowsTweaks {
    Show-PikaHeader

    Write-Host "WINDOWS TWEAKS" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[1] Disable Windows visual transparency"
    Write-Host "[2] Open Windows Update"
    Write-Host "[3] Open Startup Apps"
    Write-Host "[4] Open Storage settings"
    Write-Host "[5] Open Advanced System Settings"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {

        "1" {
            New-Item `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
                -Force | Out-Null

            Set-ItemProperty `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
                -Name "EnableTransparency" `
                -Type DWord `
                -Value 0 `
                -Force

            Write-Host "[+] Transparency disabled." -ForegroundColor Green
            Pause-Pika
        }

        "2" {
            Start-Process "ms-settings:windowsupdate"
        }

        "3" {
            Start-Process "ms-settings:startupapps"
        }

        "4" {
            Start-Process "ms-settings:storagesense"
        }

        "5" {
            Start-Process "SystemPropertiesAdvanced.exe"
        }
    }
}

# ============================================================
# NETWORK
# ============================================================

function Network-Tools {
    Show-PikaHeader

    Write-Host "NETWORK TOOLS" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[1] Flush DNS"
    Write-Host "[2] Renew IP address"
    Write-Host "[3] Show IP configuration"
    Write-Host "[4] Show network adapters"
    Write-Host "[5] Reset Winsock"
    Write-Host "[6] Reset TCP/IP"
    Write-Host "[7] Open Windows network settings"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {

        "1" {
            ipconfig /flushdns
            Write-PikaLog "Flushed DNS."
            Pause-Pika
        }

        "2" {
            ipconfig /renew
            Write-PikaLog "Renewed IP."
            Pause-Pika
        }

        "3" {
            ipconfig /all
            Pause-Pika
        }

        "4" {
            Get-NetAdapter |
                Format-Table Name, Status, LinkSpeed, MacAddress -AutoSize

            Pause-Pika
        }

        "5" {
            if (Confirm-Pika "Winsock will be reset. A restart may be required.") {
                netsh winsock reset
                Write-PikaLog "Reset Winsock."
                Pause-Pika
            }
        }

        "6" {
            if (Confirm-Pika "TCP/IP will be reset. A restart may be required.") {
                netsh int ip reset
                Write-PikaLog "Reset TCP/IP."
                Pause-Pika
            }
        }

        "7" {
            Start-Process "ms-settings:network"
        }
    }
}

# ============================================================
# CLEANUP
# ============================================================

function Clean-PikaFiles {
    Show-PikaHeader

    Write-Host "SYSTEM CLEANUP" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[1] Clean current user's TEMP"
    Write-Host "[2] Clean Windows TEMP"
    Write-Host "[3] Clean both"
    Write-Host "[4] Open Storage Sense"
    Write-Host "[5] Run Windows Disk Cleanup"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {

        "1" {
            Remove-Item "$env:TEMP\*" `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue

            Write-Host "[+] User TEMP cleaned." -ForegroundColor Green
            Pause-Pika
        }

        "2" {
            if (Confirm-Pika "Clean Windows TEMP files?") {
                Remove-Item "$env:WINDIR\Temp\*" `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue

                Write-Host "[+] Windows TEMP cleaned." -ForegroundColor Green
                Pause-Pika
            }
        }

        "3" {
            if (Confirm-Pika "Clean temporary files?") {

                Remove-Item "$env:TEMP\*" `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue

                Remove-Item "$env:WINDIR\Temp\*" `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue

                Write-Host "[+] Cleanup completed." -ForegroundColor Green
                Write-PikaLog "Cleaned temporary files."
                Pause-Pika
            }
        }

        "4" {
            Start-Process "ms-settings:storagesense"
        }

        "5" {
            Start-Process cleanmgr.exe
        }
    }
}

# ============================================================
# PRIVACY
# ============================================================

function Privacy-Tools {
    Show-PikaHeader

    Write-Host "PRIVACY" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""
    Write-Host "[1] Open Privacy settings"
    Write-Host "[2] Open Diagnostics settings"
    Write-Host
