<#
.SYNOPSIS
    Copies files from a specified source directory to a destination directory on remote computers with progress reporting.

.DESCRIPTION
    This script defines a function `Copy-WithProgress` that:
    1. Takes a source directory, a destination directory, and a list of remote hosts.
    2. Connects to each remote host using a PowerShell session.
    3. Copies files from the source directory to the destination directory on each remote host.
    4. Displays progress information for each file being copied.

.PARAMETER Source
    The path to the source directory on the local machine from which files will be copied.

.PARAMETER Destination
    The path to the destination directory on the remote computers where files will be copied to.

.PARAMETER RemoteHost
    An array of remote computer names or IP addresses to which files will be copied.

.EXAMPLE
    Copy-WithProgress -Source "C:\projects" -Destination "U:\Backup\test" -RemoteHost "vm1", "vm2"

    This example copies files from "C:\projects" on the local machine to "U:\Backup\test" on the remote computers "vm1" and "vm2".
    Progress is displayed for each file being copied.

.NOTES
    - The function uses PowerShell remoting (New-PSSession) to connect to remote computers.
    - Ensure that PowerShell remoting is enabled and properly configured on the remote computers.
    - The `-UseSSL` parameter in `New-PSSession` requires that the remote session be secured with SSL.
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024
#>
Function Copy-WithProgress
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $Source,
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $Destination,
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [string[]]$RemoteHost
    )

    $Source=$Source.tolower()
    $Filelist=Get-Childitem "$Source" -Recurse
    $Total=$Filelist.count
    $Position=0

    Write-Host "Number of items to copy: $Total"
    Write-Host "Source: $Source"
    Write-Host "Destination $Destination"

    foreach($Computer in $RemoteHost){
        Write-Output "attempting to open a session to $Computer"
        try{
            $session = New-PSSession -ComputerName $Computer -Name copysession -UseSSL
            Write-Output "Successfully opened a connection to $Computer"
            Write-Output "Copying the files to $Computer"
            foreach ($File in $Filelist)
            {
                $Filename=$File.Fullname.tolower().replace($Source,'')
                $DestinationFile=($Destination+$Filename)
                Write-Progress -Activity "Copying data from '$source' to '$Destination'" -Status "Copying File $Filename" -PercentComplete (($Position/$total)*100)
                Copy-Item $File.FullName -Destination $DestinationFile -ToSession $session -Force
                $Position++
            }
            Remove-PSSession -Session $session
        }
        catch{
        Write-Output "connection to $Computer failed"
            }
        }
}

Copy-WithProgress -Source "source" -Destination "c:\TEMP" -RemoteHost vm1, vm2
