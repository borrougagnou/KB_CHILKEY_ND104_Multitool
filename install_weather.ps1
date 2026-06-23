<#
.SYNOPSIS
Install ND104_Multitool_Weather

.DESCRIPTION
Downloads the latest .exe release from Github,
saves it into the AppData\Local\Programs folder,
create a config file,
creates a scheduled tasks.

.PARAMETER help
Display this help and exit.

.PARAMETER TargetLocalAppData
Optional LocalAppData path of the user. (Useful when the script is elevated)

.PARAMETER TargetUser
Optional user name of the real desktop user. (Useful when the script is elevated)

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -help

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -TargetUser MyAccount -TargetLocalAppData "C:\Users\Me\AppData\Local"

.NOTES
You can also read this help with:
Get-Help .\install.ps1 -Full
#>
param(
    [switch]$help,
    [string]$TargetLocalAppData = "",
    [string]$TargetUser = ""
)

#######################################################################
# Thx Powershell.... it's ugly to do that... but I don't have choice
# Script compatible with Powershell v2
# Tested with :
# - Windows XP SP3 (ALL PATCH UP TO 2014 APPLIED)
# - Windows 10 22H2
#######################################################################

$ErrorActionPreference = "Stop"

# ================#
# Global settings #
# ================#

$ApplicationName = "ND104_Multitool_Weather"
$RepoUrl = "https://github.com/borrougagnou/KB_CHILKEY_ND104_Multitool"
$ProgramFileName = "ND104_Multitool_Weather_Weather.exe"

$PeriodicTaskName = "ND104_Multitool_Weather - Periodic"
$StartupTaskName = "ND104_Multitool_Weather - User Logon"

# Full path of the current installer script:
$InstallerScriptPath = $MyInvocation.MyCommand.Path

# Full path of the powershell executable:
$PowerShellExePath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $PowerShellExePath)) {
    $PowerShellExePath = "powershell.exe"
}

# Full path of the Task Scheduler executable:
$SchtasksExePath = Join-Path $env:SystemRoot "System32\schtasks.exe"
if (-not (Test-Path $SchtasksExePath)) {
    $SchtasksExePath = "schtasks.exe"
}

function Show-ScriptHelp {
    Write-Host ""
    Write-Host "ND104_Multitool_Weather installer"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File install.ps1"
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File install.ps1 -help"
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -TargetUser MyAccount -LocalAppData 'C:\Users\Me\AppData\Local'"
    Write-Host ""
    Write-Host "Optional parameters:"
    Write-Host "  -TargetLocalAppData \"C:\\...\""
    Write-Host "  -TargetUser \"DOMAIN\\User\""
    Write-Host ""
    Write-Host "This script will:"
    Write-Host "- download the latest .exe release"
    Write-Host "- write config.ini in your AppData > Local > ND104_Multitool_Weather folder"
    Write-Host "- create scheduled tasks"
    Write-Host ""
    Write-Host "You can also use: Get-Help .\install.ps1 -Full"
}

#====================#
# Is Administrator ? #
#====================#

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $currentIdentity

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-InstallerAsAdministrator {
    if ($InstallerScriptPath -eq $null -or $InstallerScriptPath -eq "") {
        throw "Cannot restart as administrator because the script path is unknown."
    }

    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$InstallerScriptPath`""

    if ($TargetLocalAppData -ne "") {
        $arguments = $arguments + " -TargetLocalAppData `"$TargetLocalAppData`""
    }

    if ($TargetUser -ne "") {
        $arguments = $arguments + " -TargetUser `"$TargetUser`""
    }

    Write-Host "Restarting installer as administrator..."
    Start-Process -FilePath $PowerShellExePath -Verb RunAs -ArgumentList $arguments
    exit
}

#==================================#
# Download exe from github release #
#==================================#

function Download-ProgramFromRepoUrl {
    param(
        [string]$RepoUrl,
        [string]$OutputFilePath
    )

    # Little trick on my own to use TLS 1.2 in case the user uses old Windows,
    # but very old systems may still fail depending on .NET and system updates.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        } catch {
            Write-Warning "Could not force TLS 1.2. GitHub download may fail on old Windows."
        }
    }

    $cleanRepoUrl = $RepoUrl.TrimEnd("/")
    $apiUrl = $cleanRepoUrl.Replace("https://github.com/", "https://api.github.com/repos/") + "/releases/latest"

    Write-Host "Reading latest release:"
    Write-Host $apiUrl

    $client = New-Object System.Net.WebClient
    $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.19041.5737")
    $releaseJson = $client.DownloadString($apiUrl)

    $downloadUrlRegex = '"browser_download_url"\s*:\s*"([^"]*\.exe[^"]*)"'
    $match = [Regex]::Match($releaseJson, $downloadUrlRegex, [Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if (-not $match.Success) {
        throw "No .exe file was found in the latest release."
    }

    $downloadUrl = $match.Groups[1].Value
    $downloadUrl = $downloadUrl.Replace('\/', '/')

    $outputDirectory = Split-Path -Parent $OutputFilePath
    if (-not (Test-Path $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    }

    Write-Host "Downloading:"
    Write-Host $downloadUrl

    $client.DownloadFile($downloadUrl, $OutputFilePath)

    if (-not (Test-Path $OutputFilePath)) {
        throw "Download failed: $OutputFilePath"
    }
}

#====================#
# Questions for user #
#====================#

function Read-Coordinate {
    param(
        [string]$CoordinateName,
        [double]$MinimumValue,
        [double]$MaximumValue
    )

    while ($true) {
        $numberText = Read-Host "Enter $CoordinateName using dot decimal format, eg: 44.8378"

        if ($numberText -notmatch '^-?[0-9]{1,3}\.[0-9]+$') {
            Write-Host "Wrong format. Use a dot, for example: 44.8378 or -0.5792"
            continue
        }

        $number = 0.0
        $parsed = [double]::TryParse(
            $numberText,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$number
        )

        if (-not $parsed) {
            Write-Host "This is not a valid number."
            continue
        }

        if ($number -lt $MinimumValue -or $number -gt $MaximumValue) {
            Write-Host "$CoordinateName must be between $MinimumValue and $MaximumValue."
            continue
        }

        return $numberText
    }
}

function Ask-LocationConfiguration {
    while ($true) {
        Write-Host ""
        Write-Host "Location setup:"
        Write-Host "1 - Use geolocalisation (default)"
        Write-Host "2 - Enter coordinates manually"

        $choice = Read-Host "Choose 1 or 2 or press Enter for default"

        if ($choice -eq "" -or $choice -eq "1") {
            $config = New-Object PSObject
            $config | Add-Member -MemberType NoteProperty -Name Mode -Value "geoloc"
            $config | Add-Member -MemberType NoteProperty -Name Longitude -Value ""
            $config | Add-Member -MemberType NoteProperty -Name Latitude -Value ""
            return $config
        }

        if ($choice -eq "2") {
            $longitude = Read-Coordinate -CoordinateName "longitude" -MinimumValue -180 -MaximumValue 180
            $latitude = Read-Coordinate -CoordinateName "latitude" -MinimumValue -90 -MaximumValue 90

            Write-Host "Longitude: $longitude valid."
            Write-Host "Latitude:  $latitude  valid."

            $config = New-Object PSObject
            $config | Add-Member -MemberType NoteProperty -Name Mode -Value "manual"
            $config | Add-Member -MemberType NoteProperty -Name Longitude -Value $longitude
            $config | Add-Member -MemberType NoteProperty -Name Latitude -Value $latitude
            return $config
        }

        Write-Host "Please choose 1, 2, or press Enter."
    }
}

function Ask-IntervalHours {
    while ($true) {
        $text = Read-Host "How often should $ApplicationName run (hours)? (1 to 23, default: 6)"

        if ($text -eq "") {
            return 6
        }

        if ($text -notmatch '^[0-9]+$') {
            Write-Host "Please enter a number only."
            continue
        }

        $hours = [int]$text

        if ($hours -lt 1) {
            Write-Host "The interval cannot be lower than 1 hour."
            continue
        }

        if ($hours -gt 23) {
            Write-Host "The interval cannot be higher than 23 hours."
            continue
        }

        return $hours
    }
}

#=============#
# Config file #
#=============#

function Write-ProgramConfigFile {
    param(
        [string]$ConfigFilePath,
        [object]$LocationConfig,
        [int]$IntervalHours
    )

    $directory = Split-Path -Parent $ConfigFilePath
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $lines = @()
    $lines += "[location]"
    $lines += "mode=" + $LocationConfig.Mode
    $lines += "longitude=" + $LocationConfig.Longitude
    $lines += "latitude=" + $LocationConfig.Latitude
    $lines += ""
    $lines += "[schedule]"
    $lines += "interval_hours=$IntervalHours"

    Set-Content -Path $ConfigFilePath -Value $lines -Encoding ASCII
}

#=================#
# Scheduled tasks #
#=================#

function Create-ScheduledTask {
    param(
        [string]$TaskName,
        [string]$Schedule,
        [string]$Modifier,
        [string]$CommandLine,
        [string]$RunAsUser
    )

    Write-Host "Creating scheduled task: $TaskName"

    & $SchtasksExePath /Delete /TN $TaskName /F 2>$null | Out-Null

    # that's ugly.... not thx M$$$
    $arguments = @("/Create", "/TN", $TaskName, "/SC", $Schedule, "/TR", $CommandLine)

    if ($Modifier -ne "") {
        $arguments += "/MO"
        $arguments += $Modifier
    }

    if ($Schedule -eq "HOURLY") {
        $startTime = (Get-Date).AddMinutes(2).ToString("HH:mm")
        $arguments += "/ST"
        $arguments += $startTime
    }

    # First try INTERACTIVE mode to avoid storing a password.
    $interactiveArguments = $arguments + @("/RU", "INTERACTIVE")
    & $SchtasksExePath @interactiveArguments

    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Warning "Could not create task with /RU INTERACTIVE."

    if ($RunAsUser -eq $null -or $RunAsUser -eq "") {
        throw "Could not create scheduled task because the target user is unknown."
    }

    # No more choice
    Write-Host "Retrying with user account: $RunAsUser"
    Write-Host "Windows may ask for the password of this user."

    $userArguments = $arguments + @("/RU", $RunAsUser, "/RP", "*")
    & $SchtasksExePath @userArguments

    if ($LASTEXITCODE -ne 0) {
        throw "Could not create scheduled task: $TaskName"
    }
}

function Create-ProgramScheduledTasks {
    param(
        [string]$ProgramPath,
        [string]$ConfigFilePath,
        [int]$IntervalHours,
        [string]$RunAsUser
    )

    # Two tasks are created:
    # 1) a periodic task every X hours
    # 2) a logon task so the program starts when the user session opens
    $programCommand = "`"$ProgramPath`" -config `"$ConfigFilePath`""

    Create-ScheduledTask `
        -TaskName $PeriodicTaskName `
        -Schedule "HOURLY" `
        -Modifier ([string]$IntervalHours) `
        -CommandLine $programCommand `
        -RunAsUser $RunAsUser

    Create-ScheduledTask `
        -TaskName $StartupTaskName `
        -Schedule "ONLOGON" `
        -Modifier "" `
        -CommandLine $programCommand `
        -RunAsUser $RunAsUser
}

#======#
# Main #
#======#

function Main {
    if ($Help) {
        Show-ScriptHelp
        return
    }

    if (-not (Test-IsAdministrator)) {
        Restart-InstallerAsAdministrator
    }

    Write-Host ""
    Write-Host "Installer is running as administrator."

    $localAppData = $TargetLocalAppData

    if ($localAppData -eq "") {
        if ($env:LOCALAPPDATA -ne $null -and $env:LOCALAPPDATA -ne "") {
            $localAppData = $env:LOCALAPPDATA
        } else {
            $localAppData = Join-Path $env:USERPROFILE "Local Settings\Application Data"
        }
    }

    if ($TargetUser -eq "") {
        $TargetUser = $env:USERDOMAIN + "\" + $env:USERNAME
    }

    Write-Host "Target user: $TargetUser"
    Write-Host "Target LocalAppData: $localAppData"

    Write-Host         "If Target user is Administrator or another user, then it is not your actual user. press CTRL + C now if needed."
    Write-Host         ""
    Write-Host        "Press Enter if the information is correct."
    Read-Host -Prompt "Else stop the script and restart it with manual parameters"

    # Last resort
    Start-Sleep -Seconds 5

    $applicationDirectory = Join-Path $localAppData $ApplicationName
    $programDirectory = Join-Path (Join-Path $localAppData "Programs") $ApplicationName

    $programPath = Join-Path $programDirectory $ProgramFileName
    $configFilePath = Join-Path $applicationDirectory "config.ini"

    $locationConfig = Ask-LocationConfiguration
    $intervalHours = Ask-IntervalHours

    Download-ProgramFromRepoUrl -RepoUrl $RepoUrl -OutputFilePath $programPath

    Write-ProgramConfigFile `
        -ConfigFilePath $configFilePath `
        -LocationConfig $locationConfig `
        -IntervalHours $intervalHours

    Create-ProgramScheduledTasks `
        -ProgramPath $programPath `
        -ConfigFilePath $configFilePath `
        -IntervalHours $intervalHours `
        -RunAsUser $TargetUser

    Write-Host ""
    Write-Host "Installation complete."
    Write-Host "Program: $programPath"
    Write-Host "Config:  $configFilePath"
    Write-Host "Scheduled tasks:"
    Write-Host "- $PeriodicTaskName"
    Write-Host "- $StartupTaskName"
}

Main

