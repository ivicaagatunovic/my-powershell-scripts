$metricName   = 'windows_ntp_client'
$hostname     = $env:computername

#Get ntp metrics from w32tm
$NTPStatus = w32tm /query /status /verbose
$rootdelay = ($NTPStatus | Select-String -Pattern 'Root Delay:' -CaseSensitive -SimpleMatch)  -replace "Root Delay: ","" -replace "s",""
$rootdesp = ($NTPStatus | Select-String -Pattern 'Root Dispersion:' -CaseSensitive -SimpleMatch) -replace "Root Dispersion: ","" -replace "s",""
$phaseoffset = ($NTPStatus | Select-String -Pattern 'Phase Offset:' -CaseSensitive -SimpleMatch) -replace "Phase Offset: ","" -replace "s",""
$lastgoodsync = ($NTPStatus | Select-String -Pattern 'Time since Last Good Sync Time:' -CaseSensitive -SimpleMatch) -replace "Time since Last Good Sync Time: ","" -replace "s",""
$updinterval = $NTPStatus | Select-String -Pattern 'Poll Interval:'

#Extract time update interval value
$Regex = [Regex]::new("(?<=\().*(?=s)")
$Match = $Regex.Match($updinterval)
if($Match.Success)
{
    $updintvalue = $Match.Value
}

Write-Output "$metricName{label=`"windows_time_service.root_delay`",Hostname=`"$hostname`"} $rootdelay"
Write-Output "$metricName{label=`"windows_time_service.root_desp`",Hostname=`"$hostname`"} $rootdesp"
Write-Output "$metricName{label=`"windows_time_service.phase_offset`",Hostname=`"$hostname`"} $phaseoffset"
Write-Output "$metricName{label=`"windows_time_service.last_good_sync`",Hostname=`"$hostname`"} $lastgoodsync"
Write-Output "$metricName{label=`"windows_time_service.update_interval`",Hostname=`"$hostname`"} $updintvalue"
