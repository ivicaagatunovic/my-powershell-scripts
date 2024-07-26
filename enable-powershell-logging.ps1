<#
.SYNOPSIS
    Enables detailed logging for PowerShell script blocks and modules.

.DESCRIPTION
    This script enables three types of logging for PowerShell:
    1. **Script Block Logging**: Logs all executed script blocks to aid in auditing and security monitoring.
    2. **Module Logging**: Logs the execution of PowerShell modules, providing insights into which modules are being used.
    3. **All Module Logging**: Configures logging to capture activity from all PowerShell modules.

    The script performs the following actions:
    1. Checks for and creates the necessary registry keys if they do not exist.
    2. Configures the registry settings to enable script block and module logging.
    3. Sets the module logging configuration to log all modules.

.PARAMETER None
    This script does not take any parameters. It directly modifies registry settings.

.EXAMPLE
    Run the script as follows:
    ```powershell
    .\Enable-PSScriptBlockLogging.ps1
    ```
    This will enable script block logging, module logging, and logging for all modules on the local machine.

.NOTES
    - This script modifies the Windows Registry to enable logging features.
    - Administrative privileges are required to modify these registry settings.
    - Script block logging and module logging can be useful for security and auditing purposes.
    - Ensure you review and understand the implications of enabling detailed logging, as it may affect system performance and generate large log files.
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024
#>
function Enable-PSScriptBlockLogging
{
    $basePath = 'HKLM:\Software\Policies\Microsoft\Windows' +
    '\PowerShell\ScriptBlockLogging'
    if(-not (Test-Path $basePath))
    {
        $null = New-Item $basePath -Force
    }
    Set-ItemProperty $basePath -Name EnableScriptBlockLogging -Value "1"
}

# This function checks for the correct registry path and creates it
function Enable-PSModuleLogging
{
    # Registry path
    $basePath = 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
    # Create the key if it does not exist
    if(-not (Test-Path $basePath))
    {
        $null = New-Item $basePath -Force
        # Create the correct properties
        New-ItemProperty $basePath -Name "EnableModuleLogging" -PropertyType Dword
    }
    # These can be enabled (1) or disabled (0) by changing the value
    Set-ItemProperty $basePath -Name "EnableModuleLogging" -Value "1"
}

# This function creates another key value to enable logging for all modules
Function Enable-AllModuleLogging
{
    $basePath = 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames' 
    # Create the key if it does not exist
    if(-not (Test-Path $basePath))
    {
	$null = New-Item $basePath -Force
    }
    # Set the key value to log all modules
    Set-ItemProperty $basePath -Name "*" -Value "*"
}
Enable-PSScriptBlockLogging
Enable-PSModuleLogging
Enable-AllModuleLogging
