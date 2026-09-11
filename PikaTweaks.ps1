# ============================================================
# PikaTweaks V3.1
# Windows 11 Optimization Utility
# ============================================================

$ErrorActionPreference = "Continue"

$script:PikaVersion = "3.1.0"
$script:PikaRoot = Join-Path $env:ProgramData "PikaTweaks"
$script:BackupRoot = Join-Path $script:PikaRoot "Backups"
$script:LogRoot = Join-Path $script:PikaRoot "Logs"
$script:CurrentBackup = $null

# ------------------------------------------------------------
# FOLDERS
# ------------------------------------------------------------

foreach ($folder in @(
    $script:PikaRoot,
    $script:BackupRoot,
    $script:LogRoot
)) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

$script:LogFile = Join-Path $script:LogRoot "PikaTweaks.log"

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------

function Write-PikaLog {
    param(
        [string]$Message
    )

    try {
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $script:LogFile -Value "[$time] $Message"
    }
    catch {}
}

function Write-Info {
    param([string]$Message)

    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Write-PikaLog $Message
}

function Write-Success {
    param([string]$Message)

    Write-Host "[ OK ] $Message" -ForegroundColor Green
    Write-PikaLog $Message
}

function Write-WarningText {
    param([string]$Message)

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    Write-PikaLog "WARNING: $Message"
}

function Write-ErrorText {
    param([string]$Message)

    Write-Host "[ERR ] $Message" -ForegroundColor Red
    Write-PikaLog "ERROR: $Message"
}

# ------------------------------------------------------------
# ADMIN CHECK
# ------------------------------------------------------------

function Test-PikaAdmin {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Restart-PikaAsAdmin {

    if (Test-PikaAdmin) {
        return
    }

    Write-WarningText "PikaTweaks needs Administrator permissions."

    $scriptPath = $PSCommandPath

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        Write-ErrorText "Unable to determine script path."
        Write-Host "Run PowerShell as Administrator and start PikaTweaks.ps1 again."
        Read-Host "Press Enter"
        exit
    }

    try {
        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

        exit
    }
    catch {
        Write-ErrorText "Administrator elevation was cancelled."
        Read-Host "Press Enter"
        exit
    }
}

# ------------------------------------------------------------
# UI
# ------------------------------------------------------------

function Clear-PikaScreen {
    Clear-Host
}

function Show-PikaHeader {

    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host "                     PIKA TWEAKS" -ForegroundColor Cyan
    Write-Host "                        V3.1.0" -ForegroundColor Magenta
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Pause-Pika {
    Write-Host ""
    Read-Host "Press Enter to continue"
}

# ------------------------------------------------------------
# CONFIRMATION
# ------------------------------------------------------------

function Confirm-PikaAction {

    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow

    $answer = Read-Host "Continue? [Y/N]"

    return ($answer -match "^(Y|YES)$")
}

# ------------------------------------------------------------
# REGISTRY HELPERS
# ------------------------------------------------------------

function Set-PikaRegistryValue {

    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    try {

        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty `
            -Path $Path `
            -Name $Name `
            -Value $Value `
            -PropertyType $Type `
            -Force | Out-Null

        return $true
    }
    catch {

        Write-ErrorText "Registry change failed: $Path\$Name"
        return $false
    }
}

# ------------------------------------------------------------
# BACKUP
# ------------------------------------------------------------

function New-PikaBackup {

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $backup = Join-Path $script:BackupRoot "Backup-$stamp"

    New-Item -ItemType Directory -Path $backup -Force | Out-Null

    $script:CurrentBackup = $backup

    Write-Info "Creating backup..."

    $registryKeys = @(
        "HKCU\Software\Microsoft\GameBar",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    )

    foreach ($key in $registryKeys) {

        $safeName = $key `
            -replace "\\","_" `
            -replace ":",""

        $file = Join-Path $backup "$safeName.reg"

        & reg.exe export $key $file /y 2>$null | Out-Null
    }

    try {
        $activePower = (powercfg /getactivescheme) -join " "

        Set-Content `
            -Path (Join-Path $backup "powerplan.txt") `
            -Value $activePower
    }
    catch {}

    Write-Success "Backup created:"
    Write-Host $backup

    return $backup
}

# ------------------------------------------------------------
# RESTORE
# ------------------------------------------------------------

function Restore-PikaBackup {

    Show-PikaHeader

    Write-Host "Available backups:" -ForegroundColor Cyan
    Write-Host ""

    $backups = Get-ChildItem `
        -Path $script:BackupRoot `
        -Directory `
        -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

    if (-not $backups) {
        Write-WarningText "No backups found."
        Pause-Pika
        return
    }

    for ($i = 0; $i -lt $backups.Count; $i++) {
        Write-Host "[$($i + 1)] $($backups[$i].Name)"
    }

    Write-Host ""
    $choice = Read-Host "Select backup number or B to go back"

    if ($choice -match "^[Bb]$") {
        return
    }

    $number = 0

    if (-not [int]::TryParse($choice, [ref]$number)) {
        Write-ErrorText "Invalid selection."
        Pause-Pika
        return
    }

    if ($number -lt 1 -or $number -gt $backups.Count) {
        Write-ErrorText "Invalid selection."
        Pause-Pika
        return
    }

    $selected = $backups[$number - 1]

    if (-not (Confirm-PikaAction "Restore backup '$($selected.Name)'?")) {
        return
    }

    $regFiles = Get-ChildItem `
        -Path $selected.FullName `
        -Filter "*.reg" `
        -ErrorAction SilentlyContinue

    foreach ($reg in $regFiles) {

        Write-Info "Restoring $($reg.Name)..."

        try {
            & reg.exe import $reg.FullName 2>$null | Out-Null
            Write-Success $reg.Name
        }
        catch {
            Write-ErrorText "Failed to restore $($reg.Name)"
        }
    }

    Write-Success "Restore completed."
    Pause-Pika
}

# ------------------------------------------------------------
# RESTORE POINT
# ------------------------------------------------------------

function New-PikaRestorePoint {

    Write-Info "Creating Windows restore point..."

    try {

        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" `
            -ErrorAction SilentlyContinue

        Checkpoint-Computer `
            -Description "PikaTweaks V3.1" `
            -RestorePointType "MODIFY_SETTINGS" `
            -ErrorAction Stop

        Write-Success "Restore point created."
        return $true
    }
    catch {

        Write-WarningText "Windows could not create a restore point."
        return $false
    }
}

# ============================================================
# TWEAK FUNCTIONS
# ============================================================

function Enable-PikaGameMode {

    $path = "HKCU:\Software\Microsoft\GameBar"

    if (Set-PikaRegistryValue `
        -Path $path `
        -Name "AutoGameModeEnabled" `
        -Value 1) {

        Write-Success "Game Mode enabled."
    }
}

function Disable-PikaGameDVR {

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"

    Set-PikaRegistryValue `
        -Path $path `
        -Name "AppCaptureEnabled" `
        -Value 0 | Out-Null

    Set-PikaRegistryValue `
        -Path $path `
        -Name "GameDVR_Enabled" `
        -Value 0 | Out-Null

    Write-Success "Game DVR capture disabled."
}

function Enable-PikaHAGS {

    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

    if (Set-PikaRegistryValue `
        -Path $path `
        -Name "HwSchMode" `
        -Value 2) {

        Write-Success "Hardware Accelerated GPU Scheduling enabled."
        Write-WarningText "A restart is required."
    }
}

function Disable-PikaHAGS {

    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

    try {

        Remove-ItemProperty `
            -Path $path `
            -Name "HwSchMode" `
            -ErrorAction SilentlyContinue

        Write-Success "HAGS setting returned to Windows default."
        Write-WarningText "A restart is required."
    }
    catch {
        Write-ErrorText "Could not modify HAGS."
    }
}

function Enable-PikaHighPerformance {

    try {

        $result = powercfg /setactive SCHEME_MIN 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Success "High Performance power plan enabled."
        }
        else {
            Write-ErrorText "Could not activate High Performance."
        }
    }
    catch {
        Write-ErrorText "Power plan operation failed."
    }
}

function Enable-PikaUltimatePerformance {

    try {

        $existing = powercfg /list

        if ($existing -match "Ultimate Performance") {

            $line = $existing |
                Where-Object { $_ -match "Ultimate Performance" } |
                Select-Object -First 1

            if ($line -match "([a-fA-F0-9-]{36})") {
                powercfg /setactive $matches[1]
                Write-Success "Ultimate Performance enabled."
                return
            }
        }

        $output = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1

        if ($LASTEXITCODE -eq 0) {

            $newList = powercfg /list

            $line = $newList |
                Where-Object { $_ -match "Ultimate Performance" } |
                Select-Object -Last 1

            if ($line -match "([a-fA-F0-9-]{36})") {

                powercfg /setactive $matches[1]

                Write-Success "Ultimate Performance enabled."
                return
            }
        }

        Write-WarningText "Ultimate Performance is unavailable."
    }
    catch {
        Write-ErrorText "Ultimate Performance failed."
    }
}

function Set-PikaVisualEffects {

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

    if (Set-PikaRegistryValue `
        -Path $path `
        -Name "VisualFXSetting" `
        -Value 2) {

        Write-Success "Windows visual effects optimized."
    }
}

function Set-PikaExplorerTweaks {

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    Set-PikaRegistryValue `
        -Path $path `
        -Name "TaskbarAnimations" `
        -Value 0 | Out-Null

    Set-PikaRegistryValue `
        -Path $path `
        -Name "ListviewAlphaSelect" `
        -Value 0 | Out-Null

    Write-Success "Explorer animations reduced."
}

function Disable-PikaSuggestions {

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

    Set-PikaRegistryValue `
        -Path $path `
        -Name "SubscribedContent-338388Enabled" `
        -Value 0 | Out-Null

    Set-PikaRegistryValue `
        -Path $path `
        -Name "SubscribedContent-353694Enabled" `
        -Value 0 | Out-Null

    Write-Success "Windows suggestions reduced."
}

function Set-PikaPrivacy {

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"

    Set-PikaRegistryValue `
        -Path $path `
        -Name "Enabled" `
        -Value 0 | Out-Null

    Write-Success "Basic advertising privacy setting applied."
}

# ------------------------------------------------------------
# CLEANUP
# ------------------------------------------------------------

function Invoke-PikaCleanup {

    Write-Host ""
    Write-Host "Cleaning temporary files..." -ForegroundColor Cyan

    $targets = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*"
    )

    foreach ($target in $targets) {

        try {
            Remove-Item `
                -Path $target `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
        catch {}
    }

    Write-Success "Temporary files cleaned."
}

function Clear-PikaRecycleBin {

    try {

        Clear-RecycleBin `
            -Force `
            -ErrorAction SilentlyContinue

        Write-Success "Recycle Bin emptied."
    }
    catch {

        Write-WarningText "Recycle Bin could not be emptied."
    }
}

# ------------------------------------------------------------
# NETWORK
# ------------------------------------------------------------

function Invoke-PikaDNSFlush {

    Write-Info "Flushing DNS cache..."

    try {

        ipconfig /flushdns | Out-Null

        Write-Success "DNS cache flushed."
    }
    catch {

        Write-ErrorText "DNS flush failed."
    }
}

function Invoke-PikaNetworkReset {

    if (-not (Confirm-PikaAction "Network reset can temporarily disconnect your PC. Continue?")) {
        return
    }

    Write-Info "Resetting network components..."

    try {

        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null

        Write-Success "Network reset completed."
        Write-WarningText "Restart Windows to finish the reset."
    }
    catch {

        Write-ErrorText "Network reset failed."
    }
}

# ------------------------------------------------------------
# DEBLOAT
# ------------------------------------------------------------

function Invoke-PikaDebloat {

    Show-PikaHeader

    Write-Host "CONSERVATIVE DEBLOAT" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] Remove Clipchamp"
    Write-Host "[2] Remove Solitaire"
    Write-Host "[3] Remove Xbox App"
    Write-Host "[4] List installed AppX packages"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {

        "1" {

            if (Confirm-PikaAction "Remove Clipchamp?") {

                Get-AppxPackage *Clipchamp* |
                    Remove-AppxPackage `
                    -ErrorAction SilentlyContinue

                Write-Success "Clipchamp removal attempted."
            }
        }

        "2" {

            if (Confirm-PikaAction "Remove Solitaire?") {

                Get-AppxPackage *Solitaire* |
                    Remove-AppxPackage `
                    -ErrorAction SilentlyContinue

                Write-Success "Solitaire removal attempted."
            }
        }

        "3" {

            if (Confirm-PikaAction "Remove Xbox App?") {

                Get-AppxPackage *XboxApp* |
                    Remove-AppxPackage `
                    -ErrorAction SilentlyContinue

                Write-Success "Xbox App removal attempted."
            }
        }

        "4" {

            Get-AppxPackage |
                Sort-Object Name |
                Select-Object Name, Version |
                Format-Table -AutoSize

            Pause-Pika
        }
    }
}

# ------------------------------------------------------------
# APP INSTALLER
# ------------------------------------------------------------

function Test-PikaWinGet {

    return ($null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue))
}

function Install-PikaApp {

    param(
        [string]$Name,
        [string]$Id
    )

    if (-not (Test-PikaWinGet)) {
        Write-ErrorText "WinGet is not available."
        return
    }

    Write-Info "Installing $Name..."

    winget install `
        --id $Id `
        --exact `
        --accept-source-agreements `
        --accept-package-agreements

    if ($LASTEXITCODE -eq 0) {
        Write-Success "$Name installed."
    }
    else {
        Write-WarningText "$Name installation returned code $LASTEXITCODE."
    }
}

function Invoke-PikaAppInstaller {

    while ($true) {

        Show-PikaHeader

        Write-Host "APP INSTALLER" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[1] Google Chrome"
        Write-Host "[2] Firefox"
        Write-Host "[3] Discord"
        Write-Host "[4] 7-Zip"
        Write-Host "[5] VLC"
        Write-Host "[6] Steam"
        Write-Host "[7] Epic Games"
        Write-Host "[8] OBS Studio"
        Write-Host "[9] Upgrade all"
        Write-Host "[0] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        switch ($choice) {

            "1" {
                Install-PikaApp "Google Chrome" "Google.Chrome"
            }

            "2" {
                Install-PikaApp "Mozilla Firefox" "Mozilla.Firefox"
            }

            "3" {
                Install-PikaApp "Discord" "Discord.Discord"
            }

            "4" {
                Install-PikaApp "7-Zip" "7zip.7zip"
            }

            "5" {
                Install-PikaApp "VLC" "VideoLAN.VLC"
            }

            "6" {
                Install-PikaApp "Steam" "Valve.Steam"
            }

            "7" {
                Install-PikaApp "Epic Games Launcher" "EpicGames.EpicGamesLauncher"
            }

            "8" {
                Install-PikaApp "OBS Studio" "OBSProject.OBSStudio"
            }

            "9" {

                if (Test-PikaWinGet) {

                    winget upgrade --all `
                        --accept-source-agreements `
                        --accept-package-agreements
                }
            }

            "0" {
                return
            }
        }

        Pause-Pika
    }
}

# ============================================================
# TWEAK DATABASE
# ============================================================

$script:TweakCatalog = @(
    [PSCustomObject]@{
        Id = 1
        Name = "Enable Game Mode"
        Category = "Gaming"
        Risk = "Safe"
        Recommended = $true
        Description = "Enables Windows Game Mode."
        Apply = { Enable-PikaGameMode }
    }

    [PSCustomObject]@{
        Id = 2
        Name = "Disable Game DVR"
        Category = "Gaming"
        Risk = "Safe"
        Recommended = $true
        Description = "Disables Windows background game capture."
        Apply = { Disable-PikaGameDVR }
    }

    [PSCustomObject]@{
        Id = 3
        Name = "Enable HAGS"
        Category = "Gaming"
        Risk = "Advanced"
        Recommended = $false
        Description = "Enables Hardware Accelerated GPU Scheduling."
        Apply = { Enable-PikaHAGS }
    }

    [PSCustomObject]@{
        Id = 4
        Name = "Return HAGS to Windows Default"
        Category = "Gaming"
        Risk = "Advanced"
        Recommended = $false
        Description = "Removes the custom HAGS setting."
        Apply = { Disable-PikaHAGS }
    }

    [PSCustomObject]@{
        Id = 5
        Name = "High Performance Power Plan"
        Category = "Performance"
        Risk = "Safe"
        Recommended = $true
        Description = "Activates the High Performance power plan."
        Apply = { Enable-PikaHighPerformance }
    }

    [PSCustomObject]@{
        Id = 6
        Name = "Ultimate Performance Power Plan"
        Category = "Performance"
        Risk = "Advanced"
        Recommended = $false
        Description = "Attempts to activate Ultimate Performance."
        Apply = { Enable-PikaUltimatePerformance }
    }

    [PSCustomObject]@{
        Id = 7
        Name = "Reduce Visual Effects"
        Category = "Windows"
        Risk = "Safe"
        Recommended = $true
        Description = "Reduces some Windows visual effects."
        Apply = { Set-PikaVisualEffects }
    }

    [PSCustomObject]@{
        Id = 8
        Name = "Reduce Explorer Animations"
        Category = "Windows"
        Risk = "Safe"
        Recommended = $false
        Description = "Reduces selected Explorer animations."
        Apply = { Set-PikaExplorerTweaks }
    }

    [PSCustomObject]@{
        Id = 9
        Name = "Disable Windows Suggestions"
        Category = "Windows"
        Risk = "Safe"
        Recommended = $true
        Description = "Reduces Windows promotional suggestions."
        Apply = { Disable-PikaSuggestions }
    }

    [PSCustomObject]@{
        Id = 10
        Name = "Basic Privacy"
        Category = "Privacy"
        Risk = "Safe"
        Recommended = $false
        Description = "Disables advertising personalization."
        Apply = { Set-PikaPrivacy }
    }

    [PSCustomObject]@{
        Id = 11
        Name = "Clean Temporary Files"
        Category = "Cleanup"
        Risk = "Safe"
        Recommended = $true
        Description = "Removes temporary files."
        Apply = { Invoke-PikaCleanup }
    }

    [PSCustomObject]@{
        Id = 12
        Name = "Empty Recycle Bin"
        Category = "Cleanup"
        Risk = "Action"
        Recommended = $false
        Description = "Permanently removes files currently in Recycle Bin."
        Apply = { Clear-PikaRecycleBin }
    }

    [PSCustomObject]@{
        Id = 13
        Name = "Flush DNS"
        Category = "Network"
        Risk = "Safe"
        Recommended = $true
        Description = "Clears the Windows DNS resolver cache."
        Apply = { Invoke-PikaDNSFlush }
    }

    [PSCustomObject]@{
        Id = 14
        Name = "Network Reset"
        Category = "Network"
        Risk = "Advanced"
        Recommended = $false
        Description = "Resets Winsock and TCP/IP components."
        Apply = { Invoke-PikaNetworkReset }
    }
)

# ============================================================
# TWEAK CENTER
# ============================================================

function Show-TweakCatalog {

    param(
        [array]$Tweaks,
        [System.Collections.ArrayList]$Selected
    )

    for ($i = 0; $i -lt $Tweaks.Count; $i++) {

        $tweak = $Tweaks[$i]

        if ($Selected -contains $tweak.Id) {
            $mark = "X"
        }
        else {
            $mark = " "
        }

        Write-Host "[$mark] $($tweak.Id.ToString().PadLeft(2))  $($tweak.Name)" `
            -ForegroundColor White

        Write-Host "       $($tweak.Category) | $($tweak.Risk)" `
            -ForegroundColor DarkGray
    }
}

function Invoke-PikaTweakCenter {

    $selected = New-Object System.Collections.ArrayList

    while ($true) {

        Show-PikaHeader

        Write-Host "TWEAK CENTER" -ForegroundColor Cyan
        Write-Host ""

        Show-TweakCatalog `
            -Tweaks $script:TweakCatalog `
            -Selected $selected

        Write-Host ""
        Write-Host "Selected: $($selected.Count)" -ForegroundColor Yellow
        Write-Host ""

        Write-Host "[number] Toggle tweak"
        Write-Host "[A] Select all"
        Write-Host "[R] Recommended"
        Write-Host "[C] Clear all"
        Write-Host "[S] Search"
        Write-Host "[V] View selected"
        Write-Host "[P] Apply selected"
        Write-Host "[B] Back"
        Write-Host ""

        $choice = Read-Host "Select"

        if ($choice -match "^[0-9]+$") {

            $id = [int]$choice

            $tweak = $script:TweakCatalog |
                Where-Object { $_.Id -eq $id } |
                Select-Object -First 1

            if ($null -ne $tweak) {

                if ($selected -contains $id) {
                    [void]$selected.Remove($id)
                }
                else {
                    [void]$selected.Add($id)
                }
            }
            else {
                Write-WarningText "Unknown tweak."
                Start-Sleep -Milliseconds 700
            }

            continue
        }

        switch ($choice.ToUpper()) {

            "A" {

                $selected.Clear()

                foreach ($tweak in $script:TweakCatalog) {
                    [void]$selected.Add($tweak.Id)
                }
            }

            "R" {

                $selected.Clear()

                foreach ($tweak in $script:TweakCatalog) {

                    if ($tweak.Recommended) {
                        [void]$selected.Add($tweak.Id)
                    }
                }
            }

            "C" {
                $selected.Clear()
            }

            "S" {

                $query = Read-Host "Search"

                if (-not [string]::IsNullOrWhiteSpace($query)) {

                    $results = $script:TweakCatalog |
                        Where-Object {
                            $_.Name -like "*$query*" -or
                            $_.Category -like "*$query*" -or
                            $_.Description -like "*$query*"
                        }

                    Show-PikaHeader

                    if ($results) {
                        Show-TweakCatalog `
                            -Tweaks $results `
                            -Selected $selected
                    }
                    else {
                        Write-WarningText "No tweaks found."
                    }

                    Pause-Pika
                }
            }

            "V" {

                Show-PikaHeader

                Write-Host "SELECTED TWEAKS" -ForegroundColor Cyan
                Write-Host ""

                foreach ($id in $selected) {

                    $tweak = $script:TweakCatalog |
                        Where-Object { $_.Id -eq $id } |
                        Select-Object -First 1

                    if ($null -ne $tweak) {

                        Write-Host "$($tweak.Id). $($tweak.Name)" `
                            -ForegroundColor White

                        Write-Host "   $($tweak.Description)" `
                            -ForegroundColor DarkGray

                        Write-Host ""
                    }
                }

                Pause-Pika
            }

            "P" {

                if ($selected.Count -eq 0) {

                    Write-WarningText "No tweaks selected."
                    Pause-Pika
                    continue
                }

                Show-PikaHeader

                Write-Host "SELECTED CHANGES" -ForegroundColor Cyan
                Write-Host ""

                foreach ($id in $selected) {

                    $tweak = $script:TweakCatalog |
                        Where-Object { $_.Id -eq $id } |
                        Select-Object -First 1

                    Write-Host " - $($tweak.Name)"
                }

                Write-Host ""

                if (-not (Confirm-PikaAction "Apply these tweaks?")) {
                    continue
                }

                New-PikaBackup | Out-Null

                Write-Host ""

                foreach ($id in @($selected)) {

                    $tweak = $script:TweakCatalog |
                        Where-Object { $_.Id -eq $id } |
                        Select-Object -First 1

                    if ($null -eq $tweak) {
                        continue
                    }

                    Write-Host ""
                    Write-Host ">>> $($tweak.Name)" -ForegroundColor Cyan

                    try {
                        & $tweak.Apply
                    }
                    catch {
                        Write-ErrorText "$($tweak.Name) failed."
                        Write-PikaLog $_.Exception.Message
                    }
                }

                Write-Host ""
                Write-Success "Selected tweaks finished."
                Write-WarningText "Some Windows changes require a restart."

                Pause-Pika
            }

            "B" {
                return
            }
        }
    }
}

# ============================================================
# ONE CLICK OPTIMIZE
# ============================================================

function Invoke-PikaOneClick {

    Show-PikaHeader

    Write-Host "ONE-CLICK OPTIMIZE" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Recommended profile:"
    Write-Host ""
    Write-Host "  + Game Mode"
    Write-Host "  + Disable Game DVR"
    Write-Host "  + High Performance"
    Write-Host "  + Reduce Visual Effects"
    Write-Host "  + Windows Suggestions"
    Write-Host "  + Temporary File Cleanup"
    Write-Host "  + DNS Flush"
    Write-Host ""
    Write-Host "Windows Security will NOT be disabled."
    Write-Host "Hardware will NOT be overclocked."
    Write-Host ""

    if (-not (Confirm-PikaAction "Run One-Click Optimize?")) {
        return
    }

    New-PikaBackup | Out-Null

    Write-Host ""
    Write-Info "Creating restore point..."
    New-PikaRestorePoint | Out-Null

    Write-Host ""

    Enable-PikaGameMode
    Disable-PikaGameDVR
    Enable-PikaHighPerformance
    Set-PikaVisualEffects
    Disable-PikaSuggestions
    Invoke-PikaCleanup
    Invoke-PikaDNSFlush

    Write-Host ""
    Write-Success "One-Click Optimize completed."
    Write-WarningText "Restart Windows for the best result."

    Pause-Pika
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

function Show-PikaSystemInfo {

    Show-PikaHeader

    Write-Host "SYSTEM INFORMATION" -ForegroundColor Cyan
    Write-Host ""

    try {

        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor |
            Select-Object -First 1

        $gpu = Get-CimInstance Win32_VideoController |
            Where-Object { $_.Name -notlike "*Microsoft*" } |
            Select-Object -First 1

        $ramGB = [math]::Round(
            $os.TotalVisibleMemorySize / 1MB,
            1
        )

        Write-Host "OS       : $($os.Caption)"
        Write-Host "Version  : $($os.Version)"
        Write-Host "CPU      : $($cpu.Name)"
        Write-Host "Cores    : $($cpu.NumberOfCores)"
        Write-Host "Threads  : $($cpu.NumberOfLogicalProcessors)"
        Write-Host "RAM      : $ramGB GB"

        if ($null -ne $gpu) {
            Write-Host "GPU      : $($gpu.Name)"
        }

        Write-Host "Hostname : $env:COMPUTERNAME"
        Write-Host ""

    }
    catch {

        Write-ErrorText "Could not retrieve all system information."
    }

    Pause-Pika
}

# ============================================================
# MAINTENANCE
# ============================================================

function Invoke-PikaMaintenance {

    Show-PikaHeader

    Write-Host "MAINTENANCE" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1] SFC Scan"
    Write-Host "[2] DISM CheckHealth"
    Write-Host "[3] DISM RestoreHealth"
    Write-Host "[4] DISM ScanHealth"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    switch ($choice) {

        "1" {
            sfc /scannow
            Pause-Pika
        }

        "2" {
            DISM /Online /Cleanup-Image /CheckHealth
            Pause-Pika
        }

        "3" {
            DISM /Online /Cleanup-Image /RestoreHealth
            Pause-Pika
        }

        "4" {
            DISM /Online /Cleanup-Image /ScanHealth
            Pause-Pika
        }
    }
}

# ============================================================
# WINDOWS SETTINGS
# ============================================================

function Open-PikaSettings {

    Show-PikaHeader

    Write-Host "WINDOWS SETTINGS" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1] Windows Update"
    Write-Host "[2] Display"
    Write-Host "[3] Sound"
    Write-Host "[4] Network"
    Write-Host "[5] Apps"
    Write-Host "[6] Startup Apps"
    Write-Host "[7] Windows Security"
    Write-Host "[8] System"
    Write-Host "[0] Back"
    Write-Host ""

    $choice = Read-Host "Select"

    $uri = switch ($choice) {

        "1" { "ms-settings:windowsupdate" }
        "2" { "ms-settings:display" }
        "3" { "ms-settings:sound" }
        "4" { "ms-settings:network" }
        "5" { "ms-settings:appsfeatures" }
        "6" { "ms-settings:startupapps" }
        "7" { "ms-settings:windowsdefender" }
        "8" { "ms-settings:system" }
        default { $null }
    }

    if ($null -ne $uri) {
        Start-Process $uri
    }
}

# ============================================================
# UPDATE
# ============================================================

function Update-PikaTweaks {

    Show-PikaHeader

    Write-Host "PIKATWEAKS UPDATE" -ForegroundColor Cyan
    Write-Host ""

    $url = "https://raw.githubusercontent.com/Gombou2012/PikaTweaks/main/PikaTweaks.ps1"

    $destination = Join-Path `
        $env:USERPROFILE `
        "Downloads\PikaTweaks-latest.ps1"

    Write-Info "Downloading latest version..."

    try {

        Invoke-WebRequest `
            -Uri $url `
            -OutFile $destination `
            -UseBasicParsing

        if (Test-Path $destination) {

            Write-Success "Latest script downloaded:"
            Write-Host $destination
            Write-Host ""

            Write-WarningText "The downloaded file has NOT been automatically executed."
        }
    }
    catch {

        Write-ErrorText "Update download failed."
        Write-Host $_.Exception.Message
    }

    Pause-Pika
}

# ============================================================
# ABOUT
# ============================================================

function Show-PikaAbout {

    Show-PikaHeader

    Write-Host "PIKATWEAKS" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version : $script:PikaVersion"
    Write-Host "Platform: Windows 11"
    Write-Host ""
    Write-Host "A free Windows optimization utility."
    Write-Host ""
    Write-Host "PikaTweaks does not intentionally:"
    Write-Host " - Disable Windows Security"
    Write-Host " - Install malware"
    Write-Host " - Overclock hardware"
    Write-Host " - Modify firmware"
    Write-Host ""

    Pause-Pika
}

# ============================================================
# MAIN MENU
# ============================================================

function Start-PikaTweaks {

    while ($true) {

        Show-PikaHeader

        Write-Host "MAIN MENU" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[1]  Dashboard / System Information"
        Write-Host "[2]  ONE-CLICK OPTIMIZE" -ForegroundColor Green
        Write-Host "[3]  Tweak Center"
        Write-Host "[4]  Network"
        Write-Host "[5]  Cleanup"
        Write-Host "[6]  Debloat"
        Write-Host "[7]  App Installer"
        Write-Host "[8]  Maintenance"
        Write-Host "[9]  Windows Settings"
        Write-Host "[10] Backup / Restore"
        Write-Host "[11] Create Restore Point"
        Write-Host "[12] Update PikaTweaks"
        Write-Host "[13] About"
        Write-Host "[0]  Exit"
        Write-Host ""

        $choice = Read-Host "PikaTweaks"

        switch ($choice) {

            "1" {
                Show-PikaSystemInfo
            }

            "2" {
                Invoke-PikaOneClick
            }

            "3" {
                Invoke-PikaTweakCenter
            }

            "4" {

                Show-PikaHeader

                Write-Host "NETWORK" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "[1] Flush DNS"
                Write-Host "[2] Network Reset"
                Write-Host "[0] Back"
                Write-Host ""

                $networkChoice = Read-Host "Select"

                switch ($networkChoice) {

                    "1" {
                        Invoke-PikaDNSFlush
                        Pause-Pika
                    }

                    "2" {
                        Invoke-PikaNetworkReset
                        Pause-Pika
                    }
                }
            }

            "5" {

                Show-PikaHeader

                Write-Host "CLEANUP" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "[1] Clean Temporary Files"
                Write-Host "[2] Empty Recycle Bin"
                Write-Host "[0] Back"
                Write-Host ""

                $cleanupChoice = Read-Host "Select"

                switch ($cleanupChoice) {

                    "1" {
                        Invoke-PikaCleanup
                        Pause-Pika
                    }

                    "2" {

                        if (Confirm-PikaAction "Empty Recycle Bin?") {
                            Clear-PikaRecycleBin
                        }

                        Pause-Pika
                    }
                }
            }

            "6" {
                Invoke-PikaDebloat
            }

            "7" {
                Invoke-PikaAppInstaller
            }

            "8" {
                Invoke-PikaMaintenance
            }

            "9" {
                Open-PikaSettings
            }

            "10" {
                Restore-PikaBackup
            }

            "11" {
                Show-PikaHeader
                New-PikaRestorePoint | Out-Null
                Pause-Pika
            }

            "12" {
                Update-PikaTweaks
            }

            "13" {
                Show-PikaAbout
            }

            "0" {
                Clear-Host
                Write-Host "PikaTweaks closed." -ForegroundColor Cyan
                return
            }

            default {
                Write-WarningText "Invalid option."
                Start-Sleep -Milliseconds 700
            }
        }
    }
}

# ============================================================
# START
# ============================================================

Restart-PikaAsAdmin

Write-PikaLog "PikaTweaks $script:PikaVersion started."

Start-PikaTweaks
