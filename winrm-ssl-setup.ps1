# This script configures Windows Remote Management (WinRM) with HTTPS listener using a self-signed certificate.
# It performs the following tasks:
# 1. Retrieves system details such as the computer's DNS name.
# 2. Creates an event log source if it doesn't already exist.
# 3. Logs the start of the WinRM configuration process.
# 4. Removes any existing HTTP listeners.
# 5. Generates a self-signed certificate for WinRM.
# 6. Configures WinRM settings for secure communication.
# 7. Restarts the WinRM service to apply the changes.
# 8. Configures the Windows Firewall to allow WinRM HTTPS traffic.
# 9. Logs the completion of the configuration process along with execution time.
#
# Variables:
# - $StartTime: Start time of the script execution.
# - $LogSource: Source name for event logging.
# - $EventID: Event ID for logging.
# - $DnsName: DNS name of the computer.
#
# Notes:
# - Ensure the script is run with administrative privileges.
# - Modify the script as necessary for specific configuration requirements.

# Variable initialization
# variable
$StartTime    = (Get-Date).Second
$LogSource    = "WinRMsetup"
$EventID      = "1111"
$DnsName      = (Get-WmiObject Win32_Computersystem).Name

# Create EventLog
try {
    # Create New event Log
    New-EventLog -LogName Application -Source $LogSource
}
catch {
    $ErrorMessage = $_.Exception.Message
    Throw "Error while creating Event Log type  [$ErrorMessage]"
    exit 1     
}

Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Configuration starting..."

# Remove HTTP listener
Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Remove any existing HTTP Listener."

try {
    Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
    Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] All listener(s) successfully removed"
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId $EventID -Message "[WinRM] Unable to remove existing listener(s) [$ErrorMessage]"    
}

# Generate Certificate
Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Generating self signed certificate."

try {
    $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName $DnsName
    New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force
    Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Certificate successfully generated."
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId $EventID -Message "[WinRM] Unable to generate self signed certificate [$ErrorMessage]"
    exit 1    
}

# WinRM
Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Configuring WinRM."

try {
    winrm quickconfig -q
    winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
    winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
    winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
    winrm set "winrm/config/client" '@{AllowUnencrypted="true"}'
    winrm set "winrm/config/service/auth" '@{Basic="true"}'
    winrm set "winrm/config/client/auth" '@{Basic="true"}'
    winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
    winrm set "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"$($DnsName)`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"
    Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] WinRM configuration successfully applied."
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId $EventID -Message "[WinRM] Unable configure winrm [$ErrorMessage]"
    exit 1     
}

# Restart service
Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Restarting WinRM service"

try {
    Restart-Service WinRM
    Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] WinRM service successfully restarted."
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId $EventID -Message "[WinRM] Unable restart winrm service [$ErrorMessage]"     
}

# Firewall
Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Restarting WinRM service"

try {
    netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow
    Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] firewall flow for https 5986 successfully added."
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-EventLog -LogName Application -Source $LogSource -EntryType Error -EventId $EventID -Message "[WinRM] Unable add firewall rule for winrm in local firewall [$ErrorMessage]"     
}

$EndTime = (Get-Date).Second
Write-EventLog -LogName Application -Source $LogSource -EntryType Information -EventId $EventID -Message "[WinRM] Configuration finished [Exection time : $($EndTime - $Starttime)s]"
