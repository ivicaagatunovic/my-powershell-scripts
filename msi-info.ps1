<#
    .SYNOPSIS
        This script retrieves specific property information from an MSI file.

    .DESCRIPTION
        It uses the Windows Installer COM object to read properties from the MSI database. The script performs the following tasks:
        1. Validates the input parameters.
        2. Opens the MSI database.
        3. Queries the specified property.
        4. Retrieves the property value.
        5. Returns the value of the specified property.
        6. Handles exceptions and performs cleanup of COM objects to avoid memory leaks.

    .PARAMETER Path
        The full path to the MSI file.

    .PARAMETER Property
        The property to retrieve from the MSI file. Valid values are:
        - ProductCode
        - ProductVersion
        - ProductName
        - Manufacturer
        - ProductLanguage
        - FullVersion

    .EXAMPLE
        .\Get-MSIFileInformation.ps1 -Path "D:\Source$\Apps\7-zip\7z920-x64.msi" -Property ProductCode

    .NOTES
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024 

        - Ensure the script is run with appropriate permissions to access the MSI file.
        - The script returns the value of the specified property.
        - It handles exceptions and performs cleanup of COM objects to avoid memory leaks.
#>

param(
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.IO.FileInfo]$Path,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("ProductCode", "ProductVersion", "ProductName", "Manufacturer", "ProductLanguage", "FullVersion")]
    [string]$Property
)

Process {
    try {
        # Read property from MSI database
        $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
        $MSIDatabase = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $WindowsInstaller, @($Path.FullName, 0))
        $Query = "SELECT Value FROM Property WHERE Property = '$($Property)'"
        $View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, ($Query))
        $View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
        $Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $View, $null)
        $Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)

        # Commit database and close view
        $MSIDatabase.GetType().InvokeMember("Commit", "InvokeMethod", $null, $MSIDatabase, $null)
        $View.GetType().InvokeMember("Close", "InvokeMethod", $null, $View, $null)           
        $MSIDatabase = $null
        $View = $null

        # Return the value
        return $Value
    } 
    catch {
        Write-Warning -Message $_.Exception.Message ; break
    }
}

End {
    # Run garbage collection and release ComObject
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WindowsInstaller) | Out-Null
    [System.GC]::Collect()
}