<#
    .SYNOPSIS
        This script configures and manages an Rclone service to mount cloud storage.

    .DESCRIPTION
        It performs the following tasks:
        1. Defines parameters for Rclone configuration and service management.
        2. Creates or overwrites the Rclone configuration file with provided settings.
        3. Determines the service status and start type based on input parameters.
        4. Constructs Rclone mount parameters including options for cache, drive type, and logging.
        5. Installs or reconfigures the Rclone service using NSSM (Non-Sucking Service Manager).
        6. Ensures the service is running or stopped based on input parameters.
        7. Sets the service startup type to automatic or disabled as specified.

    .EXAMPLE
        .\rclone-drive-map-s3.ps1 -rclone_enabled 'enabled' -rclone_drive_letter 'Z:' -rclone_vfs_cache_mode 'full' -rclone_bucket_name 'mybucket' -log_file 'C:\LOGS\rclone\logfile.log' -log_level 'INFO'

    .NOTES
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024 
#>

# Define parameters with default values
param (
    [string]$rclone_enabled = 'enabled',
    [string]$rclone_drive_letter = 'Z:',
    [string]$rclone_vfs_cache_mode = 'full',
    [string]$rclone_bucket_name = 'mybucket',
    [string]$rclone_drive_type = 'fixed_drive',
    [bool]$disable_checksum = $false,
    [bool]$disable_modtime = $false,
    [bool]$disable_seek = $false,
    [string]$log_file = 'C:\LOGS\rclone\logfile.log',
    [string]$log_level = 'INFO',
    [string]$nssm_path = 'C:\install\nssm.exe',
    [string]$install_path = 'C:\install\rclone.exe',
    [string]$config_path = 'C:\ProgramData\Rclone\rclone.conf',
    [string]$programfiles_path = 'C:\ProgramData\Rclone',
    [string]$rclone_cache_dir = 'C:\ProgramData\Rclone\Cache'
)

# Create or overwrite the rclone configuration file
$config_content = @"
[rclone]
type = "s3"
provider = "AWS"
access_key_id = "your_access_key_id"
secret_access_key = "your_secret_access_key"
region = "your_region"
endpoint = "your_endpoint"
bucket = "$rclone_bucket_name"
vfs_cache_mode = "$rclone_vfs_cache_mode"
cache_dir = "$rclone_cache_dir"
"@

# Ensure the directory for the configuration file exists
$directory = [System.IO.Path]::GetDirectoryName($config_path)
if (-not (Test-Path -Path $directory)) {
    New-Item -Path $directory -ItemType Directory -Force
}

# Write the configuration content to the file
$config_content | Out-File -FilePath $config_path -Encoding utf8

# Determine service status and start type
if ($rclone_enabled -eq 'enabled') {
    $service_ensure = 'Running'
    $service_enable = $true
} elseif ($rclone_enabled -eq 'disabled') {
    $service_ensure = 'Stopped'
    $service_enable = $false
} else {
    Write-Error 'Invalid enabled option!'
    exit 1
}

# Determine drive type
if ($rclone_drive_type -eq 'network_drive') {
    $drive_type = '--network-mode'
} else {
    $drive_type = ''
}

# Determine checksum, modtime, and seek options
$checksum = if ($disable_checksum) { '--no-checksum' } else { '' }
$modtime = if ($disable_modtime) { '--no-modtime' } else { '' }
$seek = if ($disable_seek) { '--no-seek' } else { '' }

# Build mount parameters
$mount_parameters = "mount ${rclone_bucket_name}:$rclone_bucket_name $rclone_drive_letter --vfs-cache-mode $rclone_vfs_cache_mode --cache-dir $rclone_cache_dir $checksum $modtime $seek $drive_type --config $config_path --log-file $log_file --log-level $log_level"

# Install or reconfigure rclone service
if (-Not (Get-Service -Name 'rclone' -ErrorAction SilentlyContinue)) {
    & "$nssm_path" install rclone "$install_path"
    & "$nssm_path" set rclone AppDirectory "$programfiles_path"
    & "$nssm_path" set rclone AppParameters "$mount_parameters"
    & "$nssm_path" set rclone Start SERVICE_AUTO_START
    & "$nssm_path" set rclone DisplayName Rclone
    & "$nssm_path" set rclone Description 'Cloud storage mount service'
    & "$nssm_path" set rclone ObjectName LocalSystem
    & "$nssm_path" set rclone AppStdout 'C:\LOGS\rclone\stdout.log'
    & "$nssm_path" set rclone AppStderr 'C:\LOGS\rclone\stderr.log'
} else {
    # Update service parameters if necessary
    $currentconfig = (& "$nssm_path" get rclone AppParameters).Trim()
    if ($mount_parameters -ne $currentconfig) {
        & "$nssm_path" set rclone AppParameters "$mount_parameters"
    }
}

# Ensure the service is running or stopped based on parameters
$service = Get-Service -Name 'rclone' -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -ne $service_ensure) {
        if ($service_ensure -eq 'Running') {
            Start-Service -Name 'rclone'
        } else {
            Stop-Service -Name 'rclone'
        }
    }
} else {
    if ($service_enable) {
        Start-Service -Name 'rclone'
    } else {
        Stop-Service -Name 'rclone'
    }
}

# Ensure the service is enabled/disabled
# Set-Service -Name 'rclone' -StartupType ($service_enable ? 'Automatic' : 'Disabled')