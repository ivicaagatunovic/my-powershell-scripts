<#
    .SYNOPSIS
        Cleans up .json and .mof files in the specified directory older than a specified number of days.

    .DESCRIPTION
        This function performs the following tasks:
        1. Initializes event logging.
        2. Logs the start of the cleanup process.
        3. Deletes .json and .mof files older than the specified number of days in the given directory.
        4. Logs the completion of the cleanup process.
        5. Handles exceptions and logs any errors encountered during the process.

    .PARAMETER CleanupPath
        The path to the directory where the cleanup will be performed. Default is "C:\Windows\System32\Configuration\ConfigurationStatus".

    .PARAMETER HistoryInDays
        The number of days to retain files. Files older than this will be deleted. Default is 10 days.

    .PARAMETER EventIDStart
        The event ID used to log the start of the cleanup process. Default is 777.

    .PARAMETER EventIDEnd
        The event ID used to log the successful completion of the cleanup process. Default is 888.

    .PARAMETER EventIDError
        The event ID used to log any errors encountered during the cleanup process. Default is 999.

    .EXAMPLE
        Cleanup-DSCFiles -CleanupPath "C:\Windows\System32\Configuration\ConfigurationStatus" -HistoryInDays 10

    .NOTES
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024 

        - Ensure the script is run with appropriate permissions to delete files in the specified directory.
        - The script logs events in the Application log with the source 'DSC_CLEANUP'.
#>

function Cleanup-DSCFiles {
    [CmdletBinding()]
    param (
        [string]$CleanupPath = "C:\Windows\System32\Configuration\ConfigurationStatus",
        [int]$HistoryInDays = 10,
        [int]$EventIDStart = 777,
        [int]$EventIDEnd = 888,
        [int]$EventIDError = 999
    )

    $date = ([System.DateTime]::Now).AddDays(-$HistoryInDays)

    New-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -ErrorAction SilentlyContinue
    Write-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -EntryType Information -EventID $EventIDStart -Message "DSC Files Cleanup Started"

    try {
        foreach ($file in ([System.IO.Directory]::EnumerateFiles($CleanupPath, "*.*", "AllDirectories").Where({[System.IO.File]::GetLastWriteTime($_) -le $date}))) {
            [System.IO.File]::Delete($file)
        }
        Write-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -EntryType Information -EventID $EventIDEnd -Message "DSC Files Cleanup Finished"
    }
    catch {
        Write-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -EntryType Error -EventID $EventIDError -Message "DSC Files Cleanup Failed due to: [$($_.Exception.Message)]"
        Throw "-=== Something went wrong [$($_.Exception.Message)] ===-"
    }
}

# Example usage of the function
# Cleanup-DSCFiles -CleanupPath "C:\Windows\System32\Configuration\ConfigurationStatus" -HistoryInDays 10
