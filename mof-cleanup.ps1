#Cleanup .json and .mof files present in the C:\Windows\System32\Configuration\ConfigurationStatus
$cleanuppath = "C:\Windows\System32\Configuration\ConfigurationStatus"
$historyindays = 10
$date = ([System.DateTime]::Now).AddDays(-$historyindays)
$eventidstart = 777
$eventidend = 888
$eventiderror = 999

New-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -ErrorAction SilentlyContinue
Write-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -EntryType Information -EventID $eventidstart -Message "DSC Files Cleanup Started"

    try {
        foreach ($mof in ([System.IO.Directory]::EnumerateFiles("C:\Windows\System32\Configuration\ConfigurationStatus", "*.*", "AllDirectories").Where({[System.IO.File]::GetLastWriteTime($_) -le $date})))
        { [System.IO.File]::Delete($mof) }
        Write-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -EntryType Information -EventID $eventidend -Message "DSC Files Cleanup Finished"
    }

    catch {
        Throw "-=== Something went wrong [$($Error[0])] ===-"
        Write-EventLog -LogName 'Application' -Source 'DSC_CLEANUP' -EntryType Information -EventID $eventiderror -Message "DSC Files Cleanup Failed due to: [$($Error[0])]!!!"   
    }
