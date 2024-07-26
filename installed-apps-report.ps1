# This script generates a report of installed applications on a Windows system and uploads it to an S3 bucket.
# 
# Summary:
# The script performs the following tasks:
# 1. Retrieves system details such as FQDN, computer name, and OS version.
# 2. Creates an event log source if it doesn't already exist.
# 3. Defines a function to get installed applications from the registry.
# 4. Determines the OS architecture and fetches applications accordingly.
# 5. Formats the application data and outputs it to the console, a CSV file, or a GridView.
# 6. Imports required PowerShell modules for AWS S3 operations.
# 7. Generates the installed applications report and logs the event.
# 8. Uploads the generated report to an S3 bucket.
# 9. Logs the success or failure of the upload operation.
#
# Variables:
# - $fqdn: Fully Qualified Domain Name of the computer.
# - $computername: Name of the computer.
# - $osversion: Operating system version.
# - $EndpointUrl: S3 bucket endpoint URL.
# - $reportKey: Access key for the S3 bucket.
# - $reportSecret: Secret key for the S3 bucket.
# - $reportpath: Path to save the generated report.
# - $eventidreport: Event ID for report generation.
# - $eventidupload: Event ID for a successful upload.
# - $eventiduploaderror: Event ID for upload error.
# - $modules: List of PowerShell modules required for the script.
#
# Functions:
# - Get-InstalledApplication: Retrieves installed applications from the registry.
# - Import-PSModule: Imports the required PowerShell modules if not already imported.
#
# Example Usage:
# - To generate and upload a report of installed applications:
#   Run the script without any parameters.
#
# - To view the installed applications in a GridView:
#   Modify the 'Get-InstalledApplication' call to use '-OutputType 'GridView''.
#
# - To output the installed applications to the console:
#   Modify the 'Get-InstalledApplication' call to use '-OutputType 'Console''.
#
# Notes:
# - Ensure the required AWS Tools PowerShell modules are installed and available.
# - Ensure the appropriate permissions are set for the S3 bucket access.

$fqdn = ([System.Net.Dns]::GetHostByName(($env:computerName))).hostname
$computername = $env:computerName
$osversion = (Get-CimInstance win32_OperatingSystem).Caption
$EndpointUrl ="https:\\s3bucketendpoint"
$reportKey = $env:mapsreportkey
$reportSecret = $env:mapsreportsecret
$reportpath = "C:\MAPS\REPORTS\$fqdn.csv"
$eventidreport = 1111
$eventidupload = 2222
$eventiduploaderror = 3333
$modules = ("AWS.Tools.Common","AWS.Tools.S3")

New-EventLog -LogName 'Application' -Source 'MAPS' -ErrorAction SilentlyContinue

Function Get-InstalledApplication
    {
        Param(
        [Parameter(Mandatory=$true)]
        [String[]]$OutputType,
        [string[]]$outpath
    )
#Registry Hives

$Object =@()

# Since I am doing a report only for Microsoft products, I filter out only Micriosfr apps in the array
$includeArray = @("*Office*","*SQL*","*Microsoft*","*Windows*","*Visio*","*Project*","*Visual*","*System*","*Agent*","*Access*","*Autoroute*","*MapPoint*","*AX2012*","*AX2009*","*CRM*","*Configuration Manager*","*Dynamics*","*Word*","*PowerPoint*","*Excel*","*Access*","*Operations*","*Power Bi*","SharePoint","*Team*","*OneNote*","*Skype*")


[long]$HIVE_HKROOT = 2147483648
[long]$HIVE_HKCU = 2147483649
[long]$HIVE_HKLM = 2147483650
[long]$HIVE_HKU = 2147483651
[long]$HIVE_HKCC = 2147483653
[long]$HIVE_HKDD = 2147483654

$Query = Get-WmiObject -query "Select AddressWidth, DataWidth,Architecture from Win32_Processor" 
    foreach ($i in $Query)
        {
            If($i.AddressWidth -eq 64){            
            $OSArch='64-bit'
        }
                    
    Else{            
            $OSArch='32-bit'            
        }
    }

Switch ($OSArch)
    {

    "64-bit"{
        $RegProv = GWMI -Namespace "root\Default" -list | where{$_.Name -eq "StdRegProv"}
        $Hive = $HIVE_HKLM
        $RegKey_64BitApps_64BitOS = "Software\Microsoft\Windows\CurrentVersion\Uninstall"
        $RegKey_32BitApps_64BitOS = "Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        $RegKey_32BitApps_32BitOS = "Software\Microsoft\Windows\CurrentVersion\Uninstall"

#############################################################################

# Get SubKey names

$SubKeys = $RegProv.EnumKey($HIVE, $RegKey_64BitApps_64BitOS)

# Make Sure No Error when Reading Registry

if ($SubKeys.ReturnValue -eq 0)
    {  # Loop through all returned subkeys
        ForEach ($Name in $SubKeys.sNames)
    {
$SubKey = "$RegKey_64BitApps_64BitOS\$Name"
$ValueName = "DisplayName"
$ValuesReturned = $RegProv.GetStringValue($Hive, $SubKey, $ValueName)
$AppName = $ValuesReturned.sValue
$Version = ($RegProv.GetStringValue($Hive, $SubKey, "DisplayVersion")).sValue 
$Publisher = ($RegProv.GetStringValue($Hive, $SubKey, "Publisher")).sValue 

if($AppName.length -gt "0"){

    Foreach($include in $includeArray) {

    if ($AppName -like $include) {

            $Object += New-Object PSObject -Property @{
            ServerName = $fqdn;
            OSversion = $osversion;
            Application = $AppName;
            Architecture  = "64-BIT";
            Version = $Version;
            Publisher= $Publisher;
            }
                        }
        }

}

    }}

#############################################################################

$SubKeys = $RegProv.EnumKey($HIVE, $RegKey_32BitApps_64BitOS)

# Make Sure No Error when Reading Registry

if ($SubKeys.ReturnValue -eq 0)

{

# Loop Through All Returned SubKEys

    ForEach ($Name in $SubKeys.sNames)

    {

    $SubKey = "$RegKey_32BitApps_64BitOS\$Name"

$ValueName = "DisplayName"
$ValuesReturned = $RegProv.GetStringValue($Hive, $SubKey, $ValueName)
$AppName = $ValuesReturned.sValue
$Version = ($RegProv.GetStringValue($Hive, $SubKey, "DisplayVersion")).sValue 
$Publisher = ($RegProv.GetStringValue($Hive, $SubKey, "Publisher")).sValue 

if($AppName.length -gt "0"){
    Foreach($include in $includeArray) {

        if ($AppName -like $include) {
            
            $Object += New-Object PSObject -Property @{
            ServerName = $fqdn;
            OSversion = $osversion;
            Application = $AppName;
            Architecture  = "32-BIT";
            Version = $Version;
            Publisher= $Publisher;
            }
                        }
            }
        }

    }

}

} #End of 64 Bit
######################################################################################
###########################################################################################

"32-bit"{

$RegProv = GWMI -Namespace "root\Default" -list | where{$_.Name -eq "StdRegProv"}

$Hive = $HIVE_HKLM

$RegKey_32BitApps_32BitOS = "Software\Microsoft\Windows\CurrentVersion\Uninstall"

#############################################################################

# Get SubKey names

$SubKeys = $RegProv.EnumKey($HIVE, $RegKey_32BitApps_32BitOS)

# Make Sure No Error when Reading Registry

if ($SubKeys.ReturnValue -eq 0)

{  # Loop Through All Returned SubKEys

    ForEach ($Name in $SubKeys.sNames)

    {
$SubKey = "$RegKey_32BitApps_32BitOS\$Name"
$ValueName = "DisplayName"
$ValuesReturned = $RegProv.GetStringValue($Hive, $SubKey, $ValueName)
$AppName = $ValuesReturned.sValue
$Version = ($RegProv.GetStringValue($Hive, $SubKey, "DisplayVersion")).sValue 
$Publisher = ($RegProv.GetStringValue($Hive, $SubKey, "Publisher")).sValue 

if($AppName.length -gt "0"){

$Object += New-Object PSObject -Property @{
            ServerName = $fqdn;
            OSversion = $osversion;
            Application = $AppName;
            Architecture  = "32-BIT";
            Version = $Version;
            Publisher= $Publisher;
            }
            }

    }}

}#End of 32 bit

} # End of Switch

#}

#$AppsReport

$column1 = @{expression="ServerName"; width=15; label="Name"; alignment="left"}
$column2 = @{expression="OSversion"; width=15; label="Name"; alignment="left"}
$column3 = @{expression="Architecture"; width=10; label="32/64 Bit"; alignment="left"}
$column4 = @{expression="Application"; width=80; label="Application"; alignment="left"}
$column5 = @{expression="Version"; width=15; label="Version"; alignment="left"}
$column6 = @{expression="Publisher"; width=30; label="Publisher"; alignment="left"}

if ($outputType -eq "Console")
{
"#"*80
"Installed Software Application Report"
"Number of Installed Application count : $($object.count)"
"Generated $(get-date)"
"Generated from $(gc env:computername)"
"#"*80
$object |Format-Table $column1, $column2, $column3 ,$column4, $column5, $column6
}

elseif ($OutputType -eq "GridView")
{
$object|Out-GridView 
}
elseif ($OutputType -eq "CSV")
{

[string]$outFile = "$outpath\temp.csv"

New-Item -ItemType file $outfile -Force
$object | export-csv -path $outfile -NoTypeInformation
Get-Content "$outfile" | Get-Unique > "C:\MAPS\REPORTS\$fqdn.csv"
Remove-Item "$outfile" -Force -ErrorAction SilentlyContinue
}

else
    {
        write-host " Invalid Output Type $OutputType"
    }

}

function Import-PSModule ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Force
            write-host "INFO: Module available on disk but not loaded. Importing $m ... "
        }
        else {
            # If module is not imported, not available on disk, but is in online gallery then install and import
            Install-Module $m
            write-host "INFO: Installing PS module $m ... "
            Import-Module $m -Force
            write-host "INFO: Importing PS module $m ... "
        }
    }
}

foreach ($module in $modules) {
    Import-PSModule $module
}

Get-InstalledApplication -OutputType 'CSV' -outpath 'C:\MAPS\REPORTS'
Write-EventLog -LogName 'Application' -Source 'MAPS' -EntryType Information -EventID $eventidreport -Message "Installed Applications report generated on $fqdn"

#Upload report to Cloudian S3 bucket
    if (Test-Path $reportpath){
            Write-Host "INFO :: Uploading report to -> S3"
            import-module AWS.Tools.Common ;  import-module AWS.Tools.S3
            Set-AWSCredential -AccessKey $reportKey -SecretKey $reportSecret
            Write-S3Object -BucketName 'appsreport' -File $reportpath -EndpointUrl $endpointUrl
            Write-Host "SUCCES :: succesfully uploaded $reportpath -> S3"
            Write-EventLog -LogName 'Application' -Source 'MAPS' -EntryType Information -EventID $eventidupload -Message "Report uploaded to S3"
            #clean up after upload
            #remove-item $report
    }else{
        Write-Host "WARNING :: no report to upload..."
        Write-EventLog -LogName 'Application' -Source 'MAPS' -EntryType Information -EventID $eventiduploaderror -Message "WARNING :: no report to upload..."
    }
