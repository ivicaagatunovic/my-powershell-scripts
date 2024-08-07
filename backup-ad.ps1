#*********************************************************************************************
 # BareMetalADDisasterBackupScript.ps1
 # Version 1.0
 # Date: 8/03/2013
 # Author: Cengiz KUSKAYA 
 # Description: A PowerShell script to make a full server backup of a Domain Controller,
 # all group policies, all group policy links,
 # all Distinguished Name of objects and AD integrated DNS.
 #*********************************************************************************************
 # Requirements:
 # Create a folder named "C:\Script" prior executing the Script and a BATCH file 
 # named C:\Script\DNSBackup.bat . Copy and paste the following commands 
 # into the BATCH file.
 # dnscmd /enumzones > C:\Script\AllZones.txt
 # for /f %%a in (C:\Script\AllZones.txt) do dnscmd /ZoneExport %%a Export\%%a.dns
 # Additionaly, create a Text file named C:\Script\Script.txt.
 # Paste the following command into the text file "delete shadows all".
 # It will delete all full server backup shadow copies for efficient disk space management.
 #*********************************************************************************************

#Logging function
function Write-Log {
    <#
    .Synopsis
       Write-Log writes a message to a specified log file with the current time stamp.
    .DESCRIPTION
       The Write-Log function is designed to add logging capability to other scripts.
       In addition to writing output and/or verbose you can write to a log file for
       later debugging.
    .NOTES
       Created by: Jason Wasser @wasserja
       Modified: 11/24/2015 09:30:19 AM  
    
       Changelog:
        * Code simplification and clarification - thanks to @juneb_get_help
        * Added documentation.
        * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks
        * Revised the Force switch to work as it should - thanks to @JeffHicks
    
       To Do:
        * Add error handling if trying to create a log file in a inaccessible location.
        * Add ability to write $Message to $Verbose or $Error pipelines to eliminate
          duplicates.
    .PARAMETER Message
       Message is the content that you wish to add to the log file. 
    .PARAMETER Path
       The path to the log file to which you would like to write. By default the function will 
       create the path and file if it does not exist. 
    .PARAMETER Level
       Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
    .PARAMETER NoClobber
       Use NoClobber if you do not wish to overwrite an existing file.
    .EXAMPLE
       Write-Log -Message 'Log message' 
       Writes the message to c:\Logs\PowerShellLog.log.
    .EXAMPLE
       Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
       Writes the content to the specified log file and creates the path and file specified. 
    .EXAMPLE
       Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
       Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
    .LINK
       https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
    #>
        [CmdletBinding()]
        Param
        (
            [Parameter(Mandatory=$true,
                       ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [Alias("LogContent")]
            [string]$Message,
    
            [Parameter(Mandatory=$false)]
            [Alias('LogPath')]
            [string]$Path='C:\Logs\PowerShellLog.log',
            
            [Parameter(Mandatory=$false)]
            [ValidateSet("Error","Warn","Info")]
            [string]$Level="Info",
            
            [Parameter(Mandatory=$false)]
            [switch]$NoClobber
        )
    
        Begin
        {
            # Set VerbosePreference to Continue so that verbose messages are displayed.
            $VerbosePreference = 'Continue'
        }
        Process
        {
            
            # If the file already exists and NoClobber was specified, do not write to the log.
            if ((Test-Path $Path) -AND $NoClobber) {
                Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
                Return
                }
    
            # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
            elseif (!(Test-Path $Path)) {
                Write-Verbose "Creating $Path."
                $NewLogFile = New-Item $Path -Force -ItemType File
                }
    
            else {
                # Nothing to see here yet.
                }
    
            # Format Date for our Log File
            $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
            # Write message to error, warning, or verbose pipeline and specify $LevelText
            switch ($Level) {
                'Error' {
                    Write-Error $Message
                    $LevelText = 'ERROR:'
                    }
                'Warn' {
                    Write-Warning $Message
                    $LevelText = 'WARNING:'
                    }
                'Info' {
                    Write-Verbose $Message
                    $LevelText = 'INFO:'
                    }
                }
            
            # Write log entry to $Path
            "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
        }
        End
        {
        }
}

function CleanGPO {
    <#
    .Synopsis
       CleanGPO will delete the GPO present in the folder
    .DESCRIPTION
       The Write-Log function is designed to add logging capability to other scripts.
       In addition to writing output and/or verbose you can write to a log file for
       later debugging.
    .NOTES
       Created by: Jason Wasser @wasserja
       Modified: 11/24/2015 09:30:19 AM  
    
       Changelog:
        * Code simplification and clarification - thanks to @juneb_get_help
        * Added documentation.
        * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks
        * Revised the Force switch to work as it should - thanks to @JeffHicks
    
       To Do:
        * Add error handling if trying to create a log file in a inaccessible location.
        * Add ability to write $Message to $Verbose or $Error pipelines to eliminate
          duplicates.
    .PARAMETER Message
       Message is the content that you wish to add to the log file. 
    .PARAMETER Path
       The path to the log file to which you would like to write. By default the function will 
       create the path and file if it does not exist. 
    .PARAMETER Level
       Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
    .PARAMETER NoClobber
       Use NoClobber if you do not wish to overwrite an existing file.
    .EXAMPLE
       Write-Log -Message 'Log message' 
       Writes the message to c:\Logs\PowerShellLog.log.
    .EXAMPLE
       Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
       Writes the content to the specified log file and creates the path and file specified. 
    .EXAMPLE
       Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
       Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
    .LINK
       https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
    #>
    Begin {
        write-Log -Message "--- Start Cleaning GPO ---" -Path $LogFile -Level Info
    }
    process {
        try {
            $DestDelGPO = "S:\WindowsImageBackup\GPOAll\*"
            if (Test-Path $DestDelGPO) {
                Get-ChildItem $DestDelGPO | where {$_.Lastwritetime -lt (date).adddays(-2)} | Remove-Item -force -recurse -Confirm:$false
                write-Log -Message "Done." -Path $LogFile -Level Info
            }
            else {
                write-Log -Message "Folder not present" -Path $LogFile -Level Info
            }
            
        }
        catch{
            write-Log -Message "Cleaning Failed. [$($_exception.message)]" -Path $LogFile -Level Error
            exit 3
        }
    
    }
    end{
        write-Log -Message "--- Finish Cleaning GPO ---" -Path $LogFile -Level Info
    }
}

function CleanGPLink {
    <#
    .Synopsis
       CleanGPLink will delete the old GP Link
    .DESCRIPTION
       The Write-Log function is designed to add logging capability to other scripts.
       In addition to writing output and/or verbose you can write to a log file for
       later debugging.
    .NOTES
       Created by: Jason Wasser @wasserja
       Modified: 11/24/2015 09:30:19 AM  
    
       Changelog:
        * Code simplification and clarification - thanks to @juneb_get_help
        * Added documentation.
        * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks
        * Revised the Force switch to work as it should - thanks to @JeffHicks
    
       To Do:
        * Add error handling if trying to create a log file in a inaccessible location.
        * Add ability to write $Message to $Verbose or $Error pipelines to eliminate
          duplicates.
    .PARAMETER Message
       Message is the content that you wish to add to the log file. 
    .PARAMETER Path
       The path to the log file to which you would like to write. By default the function will 
       create the path and file if it does not exist. 
    .PARAMETER Level
       Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
    .PARAMETER NoClobber
       Use NoClobber if you do not wish to overwrite an existing file.
    .EXAMPLE
       Write-Log -Message 'Log message' 
       Writes the message to c:\Logs\PowerShellLog.log.
    .EXAMPLE
       Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
       Writes the content to the specified log file and creates the path and file specified. 
    .EXAMPLE
       Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
       Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
    .LINK
       https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
    #>
    begin {
        write-Log -Message "--- Start Cleaning GP Link ---" -Path $LogFile -Level Info
    }
    Process {
        try {  
            $DestGPLinkAllDelPath = "S:\WindowsImageBackup\GPLinkAll\*"
            if (Test-Path $DestGPLinkAllDelPath) {  
                Get-ChildItem $DestGPLinkAllDelPath | where {$_.Lastwritetime -lt (date).adddays(-5)} | Remove-Item -force -recurse -Confirm:$false
                write-Log -Message "Done." -Path $LogFile -Level Info
            }
            else {
                write-Log -Message "Folder not present" -Path $LogFile -Level Info
            }
        }
        catch {
            write-Log -Message "Cleaning Failed. [$($_exception.message)]" -Path $LogFile -Level Error
        }
    }
    end {
        write-Log -Message "--- Finish Cleaning GP Link ---" -Path $LogFile -Level Info
    }

}

function CleanDNO {
    begin {
        write-Log -Message "--- Start Cleaning Distinguished Name of Objects in the Root Domain" -Path $LogFile -Level Info
    }
    Process {
        try {
            $DNFolderDelPath = "S:\WindowsImageBackup\DNAll\*"
            if (Test-Path $DNFolderDelPath)
            {
                Get-ChildItem $DNFolderDelPath | where {$_.Lastwritetime -lt (date).adddays(-10)} | Remove-Item -force -recurse -Confirm:$false
                write-Log -Message "Done." -Path $LogFile -Level Info
            }
            else {
                write-Log -Message "Folder not present" -Path $LogFile -Level Info
            }
        }
        catch {
            write-Log -Message "Cleaning Failed. $($_exception.message)]" -Path $LogFile -Level Error
        }
    }
    end {
        write-Log -Message "--- Finish Cleaning Distinguished Name of Objects in the Root Domain" -Path $LogFile -Level Info
    }
}

Function CleanDNS {
    begin {
        write-Log -Message "-- Start Cleaning DNS ---" -Path $LogFile -Level Info
    }
    Process {
    try {
        $DNSOldLogDelPath = "S:\WindowsImageBackup\DNSBackup\*"
        if (Test-Path $DNSOldLogDelPath)
        {
            Get-ChildItem $DNSOldLogDelPath | where {$_.Lastwritetime -lt (date).adddays(-5)} | Remove-Item -force -recurse -Confirm:$false
            write-Log -Message "Done." -Path $LogFile -Level Info
        }
        else {
            write-Log -Message "Folder not present." -Path $LogFile -Level Info
        }
    }
    catch {
        write-Log -Message "Cleaning Failed. $($_exception.message)]" -Path $LogFile -Level Error
    }
    }
    end {
        write-Log -Message "-- Finish Cleaning DNS ---" -Path $LogFile -Level Info
    }
}

# START
$logfile = "C:\INFRA\LOGS\adbackup.log"
write-Log -Message "Start Active Directory Backup" -Path $LogFile -Level Info

#Import required PowerShell Modules
write-Log -Message "--- Start Loading Modules ---" -Path $LogFile -Level Info
try {
    Import-Module ActiveDirectory, GroupPolicy, WindowsServerBackup
    write-Log -Message "Modules loaded" -Path $LogFile -Level Info
}
catch {
    write-Log -Message "Loading failed. [$($_exception.message)]" -Path $LogFile -Level Error
    exit 1
}
write-Log -Message "--- Finish Loading Modules ---" -Path $LogFile -Level Info

write-Log -Message "--- Start Cleaning Old Backup --- " -Path $LogFile -Level Info
CleanGPO
CleanGPLink
CleanDNO
CleanDNS
write-Log -Message "--- Finish Cleaning Old Backup --- " -Path $LogFile -Level Info

#Backup systemstate and delete all backups except last 4 copies
write-Log -Message "--- Start Windows Backup ---" -Path $LogFile -Level Info
#Get Defender Real Time Monitoring
$DefenderStatus=(Get-MpPreference).DisableRealtimeMonitoring
#Disable Real Time Monitoring (Only if it is enabled)
if ($DefenderStatus -eq $False) {
    Write-Log -Message "Stopping Windows Defender Real Time Monitoring" -Path $LogFile -Level Info
    Set-MpPreference -DisableRealtimeMonitoring $True
}
try {
    #wbadmin start backup -backuptarget:E: -systemState -vssCopy -exclude:c:\sysmon -include:c:\*,d:\* -quiet | out-file $logfile -Append -Force
    $BackupPolicy = New-WBPolicy
    Add-WBSystemState -Policy $BackupPolicy
    $target = New-WBBackupTarget -VolumePath "E:"
    Add-WBBackupTarget -Policy $BackupPolicy -Target $target | out-file $logfile -Append -Force
    if (Test-Path c:\sysmon){
        $exclusion = New-WBFileSpec -FileSpec C:\sysmon -Exclude
        Add-WBFileSpec -Policy $BackupPolicy $exclusion
    }
    else{
    }
    Add-WBBareMetalRecovery -Policy $BackupPolicy
    Start-WBBackup -Policy $BackupPolicy | out-file $logfile -Append -Force
    write-Log -Message "Done." -Path $LogFile -Level Info
}
catch
{
    write-Log -Message "Backup failed. [$($_exception.message)]" -Path $LogFile -Level Error
    exit 2
}
#Enable back Real Time Monitoring (Only if it was already enabled)
Write-Log -Message "Starting Windows Defender Real Time Monitoring" -Path $LogFile -Level Info
Set-MpPreference -DisableRealtimeMonitoring $False
write-Log -Message "--- Finish Windows Backup ---" -Path $LogFile -Level Info

#Backup all Group Policies
write-Log -Message "--- Start GPO Backup ---" -Path $LogFile -Level Info
try {
    $Computer = $env:computername
    $date = Get-Date -format ddMMyyyyHHmm
    $GPOPath = "S:\WindowsImageBackup\GPOAll"
    $GPOPathDest = "S:\WindowsImageBackup\GPOAll\" + $Computer + "-" + $date
    
   # Test-Path -Path $GPOPath -PathType Container
    if ( -Not (Test-Path $GPOPath))
    {
        $null = New-Item -Path $GPOPath -ItemType Directory
    }
    else
    {
        #Do Nothing
    }
    New-Item -Path $GPOPathDest -ItemType Directory -Confirm:$false | Out-Null
    if (Test-Path $GPOPathDest) {
        #Get-GPO -all -Server localhost | Backup-GPO -path $GPOPathDest 
        $GPOs =  Get-GPO -all -server localhost
        foreach ($gpo in $GPOs)
        {
            write-Log -Message "Exporting $($gpo.displayname)" -Path $LogFile -Level Info
            backup-gpo -guid $gpo.id -path $GPOPathDest | out-null
        }
    }
    write-Log -Message "Done." -Path $LogFile -Level Info

}
catch{
    write-Log -Message "Backup failed. [$($_exception.message)]" -Path $LogFile -Level Error
}
write-Log -Message "--- Finish GPO Backup ---" -Path $LogFile -Level Info
#END Backup all Group Policies.

#Start Backup all Group Policy Links
write-Log -Message "--- Start GP link backup ---" -Path $LogFile -Level Info
try {
    $GPLinkAllPath = "S:\WindowsImageBackup\GPLinkAll"
    $DestGPLinkAllPath = "S:\WindowsImageBackup\GPLinkAll\" + $Computer + "-" + $date
    if ( -Not (Test-Path $GPLinkAllPath))
    {
        $null = New-Item -Path $GPLinkAllPath -ItemType Directory
    }
    else
    {
        #Do Nothing
    }

    New-Item -Path $DestGPLinkAllPath -ItemType Directory -Confirm:$false | Out-Null

    if (Test-Path $DestGPLinkAllPath)
    {
        Get-ADOrganizationalUnit -Filter 'Name -like "*"' |
        foreach-object {(Get-GPInheritance -Target $_.DistinguishedName).GpoLinks} | export-csv $DestGPLinkAllPath\GPLinkBackup.csv -notypeinformation -delimiter ';'
    }
    write-Log -Message "Done." -Path $LogFile -Level Info
        
}
catch {
    write-Log -Message "Backup failed. $($_exception.message)]" -Path $LogFile -Level Error
}
write-Log -Message "--- Finish GP link backup ---" -Path $LogFile -Level Info
#Backup all Group Policy Links

#Backup all Distinguished Name of Objects in the Root Domain.START

write-Log -Message "--- Start Distinguished Name of Objects in the Root Domain ---" -Path $LogFile -Level Info

try {
    $DNFolderPath = "S:\WindowsImageBackup\DNAll"

    if ( -Not (Test-Path $DNFolderPath))
    {
        $null = New-Item -Path $DNFolderPath -ItemType Directory
    }
    else
    {
        #Do Nothing
    }

    $DNFileName = "DNBackup_$(get-date -Uformat "%Y%m%d-%H%M%S").txt"
    $DNFilePath = "S:\WindowsImageBackup\DNAll\$DNFileName"
    $DNList_command = "dsquery * domainroot -scope subtree -attr modifytimestamp distinguishedname -limit 0 > $DNFilePath"
    Invoke-expression $DNList_command
    write-Log -Message "Done." -Path $LogFile -Level Info
    
}
catch {
    write-Log -Message "Backup failed. $($_exception.message)]" -Path $LogFile -Level Error
}
write-Log -Message "--- Finish Distinguished Name of Objects in the Root Domain ---" -Path $LogFile -Level Info
# END Backup all Distinguished Name of Objects in the Root Domain

write-Log -Message "--- Start DNS Backup ---" -Path $LogFile -Level Info
try {
    #Backup all DNS Zones defined on a Windows DNS Server
    #Get Name of the server with env variable
    $DnsServer = $env:computername
    #Define folder where to store backup
    $BackupFolder = "S:\dns\backup"
    #Output File to store Dns Settings
    $StrFile = Join-Path $BackupFolder "input.csv"
    #Check if folder exists. if exists, delete contents
    if (-not(test-path $BackupFolder)) {
        New-Item $BackupFolder -Type Directory | Out-Null
    }
    else {

        Remove-Item $BackupFolder"\*" -recurse
    }
    #Get DNS Settings using WMI Object
    $List = Get-WmiObject -ComputerName $DnsServer -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone

    #Export information into input.csv file
    #Line wrapped should be only one line
    $list | Select-Object Name, ZoneType, AllowUpdate, @{Name = "MasterServers"; Expression = { $_.MasterServers } },DsIntegrated | Export-csv $strFile -NoTypeInformation

    $Zones = @(Get-DnsServerZone)
    foreach ($zone in $zones) 
    {
        if ($zone.isautocreated -eq $true -or $zone.zonetype -eq 'Forwarder')
        {
            write-Log -Message "Excluding Autocreated or Forwarder zone $($zone.zonename)" -Path $LogFile -Level Warn
        }       
        else
        {
            write-Log -Message "Exporting $($zone.zonename) Zone" -Path $LogFile -Level info
            $filename = $zone.zonename
            export-dnsserverzone -name $zone.zonename -filename $filename
            start-sleep 2
            move-item c:\windows\system32\dns\$filename -destination S:\dns\backup -force
        }
    }

    write-Log -Message "Done." -Path $LogFile -Level Info
}
catch {
    write-Log -Message "Unable to do the DNS backup. $($_exception.message)]" -Path $LogFile -Level Error
}
write-Log -Message "--- Finish DNS Backup ---" -Path $LogFile -Level Info
write-Log -Message "End Active Directory Backup" -Path $LogFile -Level Info