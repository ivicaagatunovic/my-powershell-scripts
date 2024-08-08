<#
.SYNOPSIS
    Retrieves local password and account lockout policy settings.

.DESCRIPTION
    This script exports the local security policy to a temporary file using `secedit` and then parses
    the file to extract password policy and account lockout settings based on the specified parameters.
    The settings are displayed in a formatted list for easy review.

.PARAMETER OutputPath
    The path to the temporary file where the local security policy will be exported.

.PARAMETER ExportPasswordPolicies
    Switch to include password policy settings in the output.

.PARAMETER ExportLockoutPolicies
    Switch to include account lockout policy settings in the output.

.EXAMPLE
    Get-LocalSecurityPolicies -OutputPath "C:\Temp\secpol.cfg" -ExportPasswordPolicies -ExportLockoutPolicies

    This example exports the local security policy to "C:\Temp\secpol.cfg" and displays both the password and
    account lockout settings.

.EXAMPLE
    Get-LocalSecurityPolicies -OutputPath "C:\Temp\secpol.cfg" -ExportPasswordPolicies

    This example exports the local security policy to "C:\Temp\secpol.cfg" and displays only the password settings.

.NOTES
    Author : Ivica Agatunovic
    WebSite: https://github.com/ivicaagatunovic
    Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024
#>

function Get-LocalSecurityPolicies {
    param (
        [string]$OutputPath = "C:\Temp\secpol.cfg",
        [switch]$ExportPasswordPolicies,
        [switch]$ExportLockoutPolicies
    )

    # Ensure the output directory exists
    $outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force
    }

    # Export local security policy to a temporary file
    secedit /export /cfg $OutputPath

    # Read the exported file
    $secpol = Get-Content -Path $OutputPath

    # Initialize hashtable to store policy settings
    $policySettings = @{}

    # Extract password policy settings if specified
    if ($ExportPasswordPolicies) {
        $policySettings.MinPasswordLength    = ($secpol | Select-String -Pattern "MinimumPasswordLength" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
        $policySettings.PasswordHistorySize  = ($secpol | Select-String -Pattern "PasswordHistorySize" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
        $policySettings.MaxPasswordAge       = ($secpol | Select-String -Pattern "MaximumPasswordAge" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
        $policySettings.MinPasswordAge       = ($secpol | Select-String -Pattern "MinimumPasswordAge" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
        $policySettings.ComplexityEnabled    = ($secpol | Select-String -Pattern "PasswordComplexity" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
    }

    # Extract lockout policy settings if specified
    if ($ExportLockoutPolicies) {
        $policySettings.LockoutDuration      = ($secpol | Select-String -Pattern "LockoutDuration" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
        $policySettings.LockoutThreshold     = ($secpol | Select-String -Pattern "LockoutBadCount" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
        $policySettings.ResetLockoutCount    = ($secpol | Select-String -Pattern "ResetLockoutCount" | ForEach-Object { $_.Line.Split('=')[1].Trim() })
    }

    # Display the extracted policy settings
    if ($policySettings.Count -gt 0) {
        $policySettings | Format-List
    } else {
        Write-Host "No policy settings specified for export." -ForegroundColor Yellow
    }

    # Clean up the temporary file
    Remove-Item -Path $OutputPath -Force
}

# Example usage of the function
Get-LocalSecurityPolicies -OutputPath "C:\Temp\secpol.cfg" -ExportPasswordPolicies -ExportLockoutPolicies
