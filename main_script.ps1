# Windows To Go PowerShell Script

# Check admin privileges
function Check-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Run as admin" -ForegroundColor Red
        Exit
    }
}

# Display banner
function Show-Banner {
    param ([string]$Title)
    Clear-Host
    Write-Host ("=" * 80)
    Write-Host "    $Title".PadRight(80)
    Write-Host ("=" * 80)
}

# Display menu prompt
function Show-Prompt {
    param ([string]$MenuOptions = "1-#")
    Write-Host ("=" * 80)
    Write-Host "Selection; Menu Options = $MenuOptions, Exit Program = X: " -NoNewline
}

# Check for exit
function Check-ForExit {
    param ([string]$input)
    if ($input -eq 'X') {
        Show-Banner "Exiting Program"
        Exit
    }
}

# Handle command failures
function Check-CommandStatus {
    param (
        [string]$CommandName,
        [int]$ExitCode
    )
    if ($ExitCode -ne 0) {
        Write-Host "$CommandName failed" -ForegroundColor Red
        Exit
    }
}

# Select Windows image
function Select-WindowsImage {
    Show-Banner "Select Windows Image"
    do {
        $imagePath = Read-Host "Enter ISO/WIM path (X to exit)"
        Check-ForExit $imagePath

        if (-not (Test-Path $imagePath)) {
            Write-Host "Invalid path" -ForegroundColor Red
            $imagePath = $null
        } elseif (-not ($imagePath -match '\.(iso|wim)$')) {
            Write-Host "Not ISO/WIM" -ForegroundColor Red
            $imagePath = $null
        } else {
            Write-Host "Image selected" -ForegroundColor Green
        }
    } while (-not $imagePath)
    
    return $imagePath
}

# Detect USB drives
function Detect-USBDrives {
    Show-Banner "Detect USB Drives"
    do {
        $usbDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' }

        if ($usbDrives.Count -eq 0) {
            Write-Host "No USB found" -ForegroundColor Red
            $retry = Read-Host "Retry or exit (X)"
            Check-ForExit $retry
            continue
        }

        Write-Host "    Drives:"
        $usbDrives | ForEach-Object { 
            Write-Host "$($_.Number): USB - $([math]::Round($_.Size / 1GB, 2)) GB"
        }

        $usbDrive = Read-Host "Enter drive number (X to exit)"
        Check-ForExit $usbDrive

        if ($usbDrive -notin $usbDrives.Number) {
            Write-Host "Invalid drive" -ForegroundColor Red
            $usbDrive = $null
        }
    } while (-not $usbDrive)

    return $usbDrive
}

# Partition USB drive
function Partition-USB {
    param (
        [string]$DriveNumber,
        [string]$PartitionType
    )

    Show-Banner "Partition USB Drive"
    Write-Host "Formatting USB"
    $diskPartScript = @"
select disk $DriveNumber
clean
$(if ($PartitionType -eq 'GPT') { "convert gpt" } else { "convert mbr" })
create partition primary
format fs=ntfs quick label="Windows To Go"
assign
$(if ($PartitionType -eq 'GPT') { "set id=`"ebd0a0a2-b9e5-4433-87c0-68b6b72699c7`"" } else { "active" })
exit
"@

    $diskPartScript | Out-File -FilePath "diskpart_script.txt" -Encoding ASCII
    $diskPartProcess = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s diskpart_script.txt" -Wait -PassThru
    Check-CommandStatus -CommandName "DiskPart" -ExitCode $diskPartProcess.ExitCode
    Remove-Item "diskpart_script.txt" -Force

    $usbVolume = Get-Partition -DiskNumber $DriveNumber | Get-Volume
    if ($usbVolume) {
        return $usbVolume.DriveLetter
    } else {
        Write-Host "No volume found" -ForegroundColor Red
        Exit
    }
}

# Apply Windows image
function Apply-WindowsImage {
    param (
        [string]$ImagePath,
        [string]$DriveLetter
    )

    Show-Banner "Apply Windows Image"
    Write-Host "Applying image"
    $dismCommand = "dism /apply-image /imagefile:`"$ImagePath`" /index:1 /applydir:${DriveLetter}:"
    $dismProcess = Start-Process -FilePath "dism.exe" -ArgumentList $dismCommand -Wait -PassThru -NoNewWindow
    Check-CommandStatus -CommandName "DISM" -ExitCode $dismProcess.ExitCode
}

# Configure bootloader
function Configure-Bootloader {
    param ([string]$DriveLetter)

    Show-Banner "Configure Bootloader"
    Write-Host "Configuring bootloader"
    $bcdCommand = "bcdboot ${DriveLetter}:\Windows /s ${DriveLetter}: /f ALL"
    $bcdProcess = Start-Process -FilePath "bcdboot.exe" -ArgumentList $bcdCommand -Wait -PassThru -NoNewWindow
    Check-CommandStatus -CommandName "BCDBoot" -ExitCode $bcdProcess.ExitCode
}

# Create Windows To Go USB
function Create-WindowsToGoUSB {
    Show-Banner "Create WinToGo Bootable"
    
    Write-Host "    Drives:"
    Get-Volume | ForEach-Object {
        Write-Host "$($_.DriveLetter): - $($_.DriveType)"
    }
    
    Write-Host "`n    Current Configuration:"
    Write-Host "Partition Type: $script:partitionType"
    
    Write-Host ("`n" + "-" * 80)
    $script:windowsImage = Select-WindowsImage
    $script:usbDrive = Detect-USBDrives
    if (-not $usbDrive) {
        Write-Host "USB selection failed" -ForegroundColor Red
        return
    }
    $script:driveLetter = Partition-USB -DriveNumber $usbDrive -PartitionType $script:partitionType
    Apply-WindowsImage -ImagePath $windowsImage -DriveLetter $driveLetter
    Configure-Bootloader -DriveLetter $driveLetter
    
    Write-Host "Windows To Go created" -ForegroundColor Green
    Pause
}

# Show configuration
function Show-Configuration {
    Show-Banner "Current Configuration"
    Write-Host "Image: $script:windowsImage"
    Write-Host "USB Drive: $script:usbDrive"
    Write-Host "Drive Letter: $script:driveLetter"
    Write-Host "Partition Type: $script:partitionType"
    Pause
}

# View logs (placeholder)
function View-Logs {
    Show-Banner "View Logs"
    Write-Host "Logs not implemented" -ForegroundColor Yellow
    Write-Host "Check Event Viewer" -ForegroundColor Yellow
    Pause
}

# Set partition type
function Set-PartitionType {
    Show-Banner "Set Partition Type"
    do {
        Write-Host "`n`n"
        Write-Host "1. MBR"
        Write-Host "`n"
        Write-Host "2. GPT"
        Write-Host "`n`n"
        Write-Host "`nCurrent: $script:partitionType"
        Show-Prompt "1-2"
        $choice = Read-Host
        Check-ForExit $choice

        switch ($choice) {
            1 { $script:partitionType = 'MBR'; return }
            2 { $script:partitionType = 'GPT'; return }
            default { Write-Host "Invalid choice" -ForegroundColor Red }
        }
    } while ($true)
}

# Tools and Extras
function Show-ToolsAndExtras {
    do {
        Show-Banner "Tools and Extras"
        Write-Host "`n`n"
        Write-Host "    1. View Logs"
        Write-Host "`n"
        Write-Host "    2. Set Partition Type"
        Write-Host "`n"
        Write-Host "    3. Current Configuration"
        Write-Host "`n`n"
        Show-Prompt
        $extraChoice = Read-Host

        Check-ForExit $extraChoice

        switch ($extraChoice) {
            1 { View-Logs }
            2 { Set-PartitionType }
            3 { Show-Configuration }
            default { Write-Host "Invalid choice" -ForegroundColor Red }
        }
    } while ($true)
}

# Main execution
Check-Administrator

$script:windowsImage = $null
$script:usbDrive = $null
$script:driveLetter = $null
$script:partitionType = 'GPT'

do {
    Show-Banner "Windows To Go Creator"
    Write-Host "`n`n"
    Write-Host "    1. Create WinToGo Bootable"
    Write-Host "`n"
    Write-Host "    2. Tools and Extras"
    Write-Host "`n`n"
    Show-Prompt
    $mainChoice = Read-Host

    Check-ForExit $mainChoice

    switch ($mainChoice) {
        1 { Create-WindowsToGoUSB }
        2 { Show-ToolsAndExtras }
        default { Write-Host "Invalid choice" -ForegroundColor Red }
    }
} while ($true)
