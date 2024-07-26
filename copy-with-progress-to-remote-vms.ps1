#Usage:
# Copy-WithProgress -Source "C:\projects" -Destination "U:\Backup\test"
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
