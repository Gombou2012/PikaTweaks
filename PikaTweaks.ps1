```powershell
# ============================================================
# PikaTweaks V4 - Security / Advanced Audit
# Read-only security audit module
# ============================================================

function Write-SecurityHeader {
    Clear-Host
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              PIKATWEAKS V4 - SECURITY" -ForegroundColor Magenta
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-DefenderAudit {
    Write-SecurityHeader
    Write-Host "[ Microsoft Defender ]" -ForegroundColor Yellow
    Write-Host ""

    try {
        $status = Get-MpComputerStatus -ErrorAction Stop

        $realTime = if ($status.RealTimeProtectionEnabled) { "ON" } else { "OFF" }
        $antivirus = if ($status.AntivirusEnabled) { "ON" } else { "OFF" }
        $antispyware = if ($status.AntispywareEnabled) { "ON" } else { "OFF" }
        $behavior = if ($status.BehaviorMonitorEnabled) { "ON" } else { "OFF" }

        Write-Host "Real-time Protection : $realTime"
        Write-Host "Antivirus            : $antivirus"
        Write-Host "Antispyware          : $antispyware"
        Write-Host "Behavior Monitoring  : $behavior"
        Write-Host "Engine Version       : $($status.AMEngineVersion)"
        Write-Host "Security Intelligence: $($status.AntivirusSignatureVersion)"
        Write-Host ""

        if ($status.RealTimeProtectionEnabled -and $status.AntivirusEnabled) {
            Write-Host "[OK] Defender protection appears enabled." -ForegroundColor Green
        }
        else {
            Write-Host "[WARNING] One or more Defender protections are disabled." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[WARNING] Defender status could not be queried." -ForegroundColor Yellow
    }

    Pause-Pika
}

function Get-FirewallAudit {
    Write-SecurityHeader
    Write-Host "[ Windows Firewall ]" -ForegroundColor Yellow
    Write-Host ""

    try {
        $profiles = Get-NetFirewallProfile -ErrorAction Stop

        foreach ($profile in $profiles) {
            $state = if ($profile.Enabled) { "ON" } else { "OFF" }

            Write-Host ("{0,-10}: {1}" -f $profile.Name, $state)

            if ($profile.Enabled) {
                Write-Host "  [OK] Firewall enabled" -ForegroundColor Green
            }
            else {
                Write-Host "  [WARNING] Firewall disabled" -ForegroundColor Red
            }

            Write-Host ""
        }
    }
    catch {
        Write-Host "[WARNING] Firewall information could not be queried." -ForegroundColor Yellow
    }

    Pause-Pika
}

function Get-UACAudit {
    Write-SecurityHeader
    Write-Host "[ User Account Control ]" -ForegroundColor Yellow
    Write-Host ""

    try {
        $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        $uac = Get-ItemProperty -Path $uacPath -ErrorAction Stop

        $enableLUA = $uac.EnableLUA
        $consent = $uac.ConsentPromptBehaviorAdmin

        Write-Host "EnableLUA                  : $enableLUA"
        Write-Host "Admin Consent Prompt Level : $consent"
        Write-Host ""

        if ($enableLUA -eq 1) {
            Write-Host "[OK] UAC is enabled." -ForegroundColor Green
        }
        else {
            Write-Host "[WARNING] UAC appears to be disabled." -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "No UAC settings were changed." -ForegroundColor DarkGray
    }
    catch {
        Write-Host "[WARNING] UAC information could not be queried." -ForegroundColor Yellow
    }

    Pause-Pika
}

function Get-RiskySettingsAudit {
    Write-SecurityHeader
    Write-Host "[ Risky Settings Scan ]" -ForegroundColor Yellow
    Write-Host ""

    $warnings = 0

    # PowerShell execution policy
    $policy = Get-ExecutionPolicy -List

    Write-Host "PowerShell Execution Policies:" -ForegroundColor Cyan
    foreach ($item in $policy) {
        Write-Host ("  {0,-15}: {1}" -f $item.Scope, $item.ExecutionPolicy)
    }

    Write-Host ""

    if ($policy | Where-Object {
        $_.ExecutionPolicy -eq "Unrestricted" -or
        $_.ExecutionPolicy -eq "Bypass"
    }) {
        Write-Host "[WARNING] A PowerShell scope uses a permissive execution policy." -ForegroundColor Yellow
        $warnings++
    }
    else {
        Write-Host "[OK] No unrestricted/bypass policy detected." -ForegroundColor Green
    }

    Write-Host ""

    # SMBv1
    try {
        $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop

        if ($smb1.State -eq "Enabled") {
            Write-Host "[WARNING] SMBv1 is enabled." -ForegroundColor Yellow
            $warnings++
        }
        else {
            Write-Host "[OK] SMBv1 is not enabled." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[INFO] SMBv1 status could not be checked." -ForegroundColor DarkGray
    }

    Write-Host ""

    # Remote Desktop
    try {
        $rdp = Get-ItemPropertyValue `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections" `
            -ErrorAction Stop

        if ($rdp -eq 0) {
            Write-Host "[REVIEW] Remote Desktop is enabled." -ForegroundColor Yellow
            $warnings++
        }
        else {
            Write-Host "[OK] Remote Desktop is disabled." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[INFO] Remote Desktop status could not be checked." -ForegroundColor DarkGray
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
        ) | Where-Object { $_ }

        if ($exclusions.Count -gt 0) {
            Write-Host "[REVIEW] Defender exclusions detected:" -ForegroundColor Yellow

            foreach ($exclusion in $exclusions) {
                Write-Host "  - $exclusion"
            }

            $warnings++
        }
        else {
            Write-Host "[OK] No Defender exclusions detected." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[INFO] Defender exclusions could not be queried." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------"

    if ($warnings -eq 0) {
        Write-Host "Security scan: NO OBVIOUS WARNINGS" -ForegroundColor Green
    }
    else {
        Write-Host "Security scan: $warnings item(s) require review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "This scan does not modify security settings." -ForegroundColor DarkGray

    Pause-Pika
}

function Export-SecurityReport {
    Write-SecurityHeader

    $reportDirectory = Join-Path $env:ProgramData "PikaTweaks\Reports"

    if (-not (Test-Path $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportPath = Join-Path $reportDirectory "Security-Audit-$timestamp.txt"

    $lines = @()

    $lines += "PikaTweaks V4 Security Audit"
    $lines += "Generated: $(Get-Date)"
    $lines += "Computer: $env:COMPUTERNAME"
    $lines += ""

    $lines += "=== DEFENDER ==="

    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop

        $lines += "Real-time Protection: $($defender.RealTimeProtectionEnabled)"
        $lines += "Antivirus: $($defender.AntivirusEnabled)"
        $lines += "Antispyware: $($defender.AntispywareEnabled)"
        $lines += "Behavior Monitoring: $($defender.BehaviorMonitorEnabled)"
        $lines += "Engine Version: $($defender.AMEngineVersion)"
        $lines += "Signature Version: $($defender.AntivirusSignatureVersion)"
    }
    catch {
        $lines += "Defender status unavailable."
    }

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

    $lines += ""
    $lines += "=== POWERSHELL POLICY ==="

    Get-ExecutionPolicy -List | ForEach-Object {
        $lines += "$($_.Scope): $($_.ExecutionPolicy)"
    }

    $lines += ""
    $lines += "=== SMBv1 ==="

    try {
        $smb = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
        $lines += "State: $($smb.State)"
    }
    catch {
        $lines += "SMBv1 status unavailable."
    }

    $lines | Out-File -FilePath $reportPath -Encoding UTF8

    Write-Host "Security report created:" -ForegroundColor Green
    Write-Host $reportPath -ForegroundColor Cyan
    Write-Host ""

    Pause-Pika
}

function Security-AdvancedMenu {
    do {
        Write-SecurityHeader

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
            "1" { Get-DefenderAudit }
            "2" { Get-FirewallAudit }
            "3" { Get-UACAudit }
            "4" { Get-RiskySettingsAudit }

            "5" {
                Get-DefenderAudit
                Get-FirewallAudit
                Get-UACAudit
                Get-RiskySettingsAudit
            }

            "6" { Export-SecurityReport }
        }

    } while ($choice -ne "0")
}
```

### Add it to the V4 main menu

Add this option:

```powershell
Write-Host "[7] Security / Advanced"
```

Then add this to your main `switch`:

```powershell
"7" {
    Security-AdvancedMenu
}
```

So your main menu becomes:

```text
[1] Dashboard
[2] One-Click Optimize
[3] Gaming Tweaks
[4] Windows Tweaks
[5] Cleanup
[6] Network
[7] Security / Advanced
[8] Backup & Restore
[9] System Information
[0] Exit
```

**Important:** this module is intentionally read-only. It can identify things such as Defender being disabled, permissive PowerShell policies, SMBv1, RDP, or Defender exclusions, but it doesn't turn security protections off or make those settings more dangerous.
