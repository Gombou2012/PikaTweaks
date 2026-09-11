
```powershell
# ============================================================
# PikaTweaks - Free Windows Gaming Optimizer
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# Relaunch as Administrator when needed
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Host ""
    Write-Host "PikaTweaks needs Administrator permission." -ForegroundColor Yellow
    Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$BackupFolder = Join-Path $env:ProgramData "PikaTweaks"
$BackupFile = Join-Path $BackupFolder "backup.json"

if (-not (Test-Path $BackupFolder)) {
    New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
}

function Show-Banner {
    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                     P I K A T W E A K S" -ForegroundColor Magenta
    Write-Host "              Windows Gaming Optimization Tool" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Pause-Pika {
    Write-Host ""
    Read-Host "Press ENTER to continue"
}

function Create-RestorePoint {
    Write-Host ""
    Write-Host "[*] Creating Windows restore point..." -ForegroundColor Yellow

    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue

        Checkpoint-Computer `
            -Description "PikaTweaks Backup" `
            -RestorePointType "MODIFY_SETTINGS" `
            -ErrorAction Stop

        Write-Host "[+] Restore point created." -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Windows could not create a restore point." -ForegroundColor Yellow
        Write-Host "    You can continue, but Windows Restore may not be enabled." -ForegroundColor DarkYellow
    }
}

function Save-Backup {
    try {
        $powerPlan = (powercfg /getactivescheme) 2>$null

        $backup = [ordered]@{
            Date = (Get-Date).ToString("o")
            PowerPlan = ($powerPlan -join "`n")
        }

        $backup | ConvertTo-Json | Set-Content $BackupFile -Encoding UTF8

        Write-Host "[+] PikaTweaks backup saved." -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Could not save backup." -ForegroundColor Yellow
    }
}

function Optimize-Power {
    Write-Host ""
    Write-Host "[*] Configuring Windows power settings..." -ForegroundColor Yellow

    $highPerformance = powercfg -list |
        Select-String "High performance"

    if ($highPerformance) {
        powercfg -setactive SCHEME_MAX
        Write-Host "[+] High Performance power plan selected." -ForegroundColor Green
    }
    else {
        powercfg -setactive SCHEME_BALANCED
        Write-Host "[+] Balanced power plan selected." -ForegroundColor Green
    }
}

function Cleanup-Temp {
    Write-Host ""
    Write-Host "[*] Cleaning temporary files..." -ForegroundColor Yellow

    $paths = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*"
    )

    foreach ($path in $paths) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[+] Temporary files cleaned." -ForegroundColor Green
}

function Flush-Network {
    Write-Host ""
    Write-Host "[*] Flushing DNS cache..." -ForegroundColor Yellow

    ipconfig /flushdns | Out-Null

    Write-Host "[+] DNS cache flushed." -ForegroundColor Green
}

function Gaming-Optimize {
    Write-Host ""
    Write-Host "[*] Applying safe gaming settings..." -ForegroundColor Yellow

    # Game Mode
    New-Item `
        -Path "HKCU:\Software\Microsoft\GameBar" `
        -Force | Out-Null

    Set-ItemProperty `
        -Path "HKCU:\Software\Microsoft\GameBar" `
        -Name "AutoGameModeEnabled" `
        -Type DWord `
        -Value 1 `
        -Force

    # Game DVR disabled for background recording
    New-Item `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
        -Force | Out-Null

    Set-ItemProperty `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
        -Name "AppCaptureEnabled" `
        -Type DWord `
        -Value 0 `
        -Force

    Write-Host "[+] Windows Game Mode enabled." -ForegroundColor Green
    Write-Host "[+] Background Game DVR capture disabled." -ForegroundColor Green
}

function Network-Optimize {
    Write-Host ""
    Write-Host "[*] Refreshing network configuration..." -ForegroundColor Yellow

    ipconfig /flushdns | Out-Null
    ipconfig /renew | Out-Null

    Write-Host "[+] DNS flushed." -ForegroundColor Green
    Write-Host "[+] Network lease refreshed." -ForegroundColor Green
}

function Cleanup-Windows {
    Write-Host ""
    Write-Host "[*] Running Windows cleanup..." -ForegroundColor Yellow

    Cleanup-Temp

    try {
        Start-Process `
            -FilePath cleanmgr.exe `
            -ArgumentList "/verylowdisk" `
            -Wait

        Write-Host "[+] Windows Disk Cleanup completed." -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Disk Cleanup could not be started." -ForegroundColor Yellow
    }
}

function Restore-PikaTweaks {
    Write-Host ""
    Write-Host "Restore options:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] Open Windows System Restore"
    Write-Host "[2] Restore Balanced power plan"
    Write-Host "[3] Cancel"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {
        "1" {
            Start-Process rstrui.exe
        }

        "2" {
            powercfg -setactive SCHEME_BALANCED
            Write-Host "[+] Balanced power plan restored." -ForegroundColor Green
            Pause-Pika
        }

        default {
            return
        }
    }
}

function One-Click-Optimize {
    Show-Banner

    Write-Host "ONE-CLICK OPTIMIZATION" -ForegroundColor Magenta
    Write-Host "------------------------------------------------------------"
    Write-Host ""

    Create-RestorePoint
    Save-Backup
    Optimize-Power
    Gaming-Optimize
    Cleanup-Temp
    Flush-Network

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "              OPTIMIZATION COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Windows gaming settings have been optimized." -ForegroundColor Green

    Pause-Pika
}

function Show-Menu {
    while ($true) {

        Show-Banner

        Write-Host "[1]  One-Click Optimize" -ForegroundColor Green
        Write-Host "[2]  Gaming Tweaks" -ForegroundColor Cyan
        Write-Host "[3]  Network Tweaks" -ForegroundColor Cyan
        Write-Host "[4]  Clean Temporary Files" -ForegroundColor Cyan
        Write-Host "[5]  Windows Cleanup" -ForegroundColor Cyan
        Write-Host "[6]  Create Restore Point" -ForegroundColor Cyan
        Write-Host "[7]  Restore / Undo" -ForegroundColor Yellow
        Write-Host "[8]  System Information" -ForegroundColor Cyan
        Write-Host "[0]  Exit" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "Choose an option"

        switch ($choice) {

            "1" {
                One-Click-Optimize
            }

            "2" {
                Show-Banner
                Gaming-Optimize
                Pause-Pika
            }

            "3" {
                Show-Banner
                Network-Optimize
                Pause-Pika
            }

            "4" {
                Show-Banner
                Cleanup-Temp
                Pause-Pika
            }

            "5" {
                Show-Banner
                Cleanup-Windows
                Pause-Pika
            }

            "6" {
                Show-Banner
                Create-RestorePoint
                Pause-Pika
            }

            "7" {
                Show-Banner
                Restore-PikaTweaks
            }

            "8" {
                Show-Banner

                Write-Host "SYSTEM INFORMATION" -ForegroundColor Magenta
                Write-Host "------------------------------------------------------------"

                Write-Host "Computer: $env:COMPUTERNAME"
                Write-Host "User:     $env:USERNAME"
                Write-Host "Windows:  $([Environment]::OSVersion.Version)"
                Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

                $cpu = Get-CimInstance Win32_Processor |
                    Select-Object -First 1 -ExpandProperty Name

                $ram = Get-CimInstance Win32_ComputerSystem

                Write-Host "CPU:      $cpu"
                Write-Host "RAM:      $([math]::Round($ram.TotalPhysicalMemory / 1GB, 1)) GB"

                Pause-Pika
            }

            "0" {
                Clear-Host
                Write-Host ""
                Write-Host "Thanks for using PikaTweaks!" -ForegroundColor Cyan
                Write-Host ""
                exit
            }

            default {
                Write-Host ""
                Write-Host "Invalid option." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

Show-Menu
```
