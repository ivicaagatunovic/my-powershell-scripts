<#
.SYNOPSIS
    This script fetches VPN exit IPs from ProtonMail API and filters for servers located in a specified country.

.DESCRIPTION
    The function `Get-ProtonVPNExitIPs` retrieves the list of logical servers from the ProtonMail API 
    and extracts exit IP addresses for servers located in the specified country. The results are exported to a CSV file.

.PARAMETER CountryCode
    The 2-letter country code (ISO 3166-1 alpha-2) for which the exit IPs will be retrieved (e.g., 'BE' for Belgium).

.PARAMETER OutputFile
    The name of the output CSV file to which the exit IPs will be saved. Defaults to 'protonvpn_exit_ips.csv'.

.EXAMPLE
    Get-ProtonVPNExitIPs -CountryCode 'BE' -OutputFile 'belgium_ips.csv'
#>

function Get-ProtonVPNExitIPs {
    param (
        [string]$CountryCode,
        [string]$OutputFile = 'c:\temp\protonvpn_exit_ips.csv'
    )
    
    # Validate that the CountryCode is provided
    if (-not $CountryCode) {
        Write-Error "You must specify a CountryCode (e.g., 'BE' for Belgium)."
        return
    }

    # Define the URL for the ProtonMail API
    $url = 'https://api.protonmail.ch/vpn/logicals'
    
    # Send a GET request to the API
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
    } catch {
        Write-Error "Failed to retrieve data from the API. $_"
        return
    }

    # Initialize an array to hold the exit IPs for the specified country
    $countryIpList = @()

    # Iterate through logical servers and their respective servers
    foreach ($server in $response.LogicalServers) {
        # Check if the ExitCountry of the current logical server matches the specified CountryCode
        if ($server.ExitCountry -eq $CountryCode) {
            foreach ($serverInfo in $server.Servers) {
                $exitIp = $serverInfo.ExitIP
                $countryIpList += $exitIp # Add exit IP to the list
            }
        }
    }

    # Convert the country IP list to a format for CSV
    $countryIpListForCsv = $countryIpList | ForEach-Object { 
        [PSCustomObject]@{ ExitIP = $_ } 
    }

    # Write the country IPs to the output CSV file
    $countryIpListForCsv | Export-Csv -Path $OutputFile -NoTypeInformation

    # Get the count of country IPs and print a message
    $numCountryIps = $countryIpList.Count
    Write-Host "$numCountryIps exit IPs located in $CountryCode exported to $OutputFile"
}

# Execute the function for Belgium as an example
Get-ProtonVPNExitIPs -CountryCode 'DE'