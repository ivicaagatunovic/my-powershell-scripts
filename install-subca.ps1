    <#
        .SYNOPSIS
            This function will install PKI SubCA.
        .DESCRIPTION
            This function will :
                - Install ADCS Role
                - Install Enterprise SubCA
                - Configure CRL
                - Configure AIA
                - Configure SubCA settings
                
        .PARAMETER CACommonName
            The CA Certificate Common Name (Ex: "My Enterprise CA")
        .PARAMETER CRLFilePath
            The CRL File path where CRL are published (Default is C:\Windows\System32\CertSrv\CertEnroll)
        .PARAMETER CRLURLPath
            The CRL URL Path registered as CRL/AIA extensions in client certificates generated Ex: "pki.domain.local")
        .NOTES
            Author : Ivica Agatunovic
            WebSite: https://github.com/ivicaagatunovic
            Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024

#>
Function Install-SubCA {
    
    [CmdletBinding()]
    param (
            [Parameter(Mandatory=$true)]
            [string]$CACommonName,   
            [Parameter(Mandatory=$false)]
            [string]$CRLFilePath="C:\Windows\System32\CertSrv\CertEnroll",
            [Parameter(Mandatory=$true)]
            [string]$CRLURLPath
    )

    try 
    {   
        # Install the ADCS Role
        Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
    }
    catch 
    {
        Write-Output "Error - Unable to install ADCS Role"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Install Enterprise SubCA  
        Install-AdcsCertificationAuthority -CAType EnterpriseSubordinateCA -CACommonName $CACommonName -KeyLength 2048 -HashAlgorithm SHA256 -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -DatabaseDirectory $(Join-Path $env:SystemRoot "System32\CertLog") -OverwriteExistingKey -OverwriteExistingDatabase -Force
  
    }
    catch 
    {
        Write-Output "Error - Unable to install Enterprise SubCA"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Configure CRL 
        #Remove CRL's
        $crllist = Get-CACrlDistributionPoint
        foreach ($crl in $crllist) {
        Remove-CACrlDistributionPoint $crl.uri -Force
        }
        
        #Add New CRL's
        Add-CACrlDistributionPoint -Uri $CRLFilePath"\"$CACommonName".crl" -PublishToServer -Force
        Add-CACrlDistributionPoint -Uri "http://"$CRLURLPath"/"$CACommonName".crl" -AddToCertificateCdp -Force
    }
    catch 
    {
        Write-Output "Error - Unable to configure CRL"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Configure AIA
        #Remove unneccesary AIA's
        Get-CAAuthorityInformationAccess | where {$_.uri -like '*ldap*'-or $_.Uri -like '*http*' -or $_.Uri -like '*file*'} | Remove-CAAuthorityInformationAccess -Force
        
        #Add new AIA
        Add-CAAuthorityInformationAccess -AddToCertificateAia "http://"+$CRLURLPath"/"$CACommonName".crt" -Force
    }
    catch 
    {
        Write-Output "Error - Unable to configure AIA"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Configure SubCA settings
        #Push some settings
        certutil -setreg CA\CRLPeriodUnits 1
        certutil -setreg CA\CRLPeriod "Weeks"
        certutil -setreg CA\CRLOverlapPeriod "Hours"
        certutil -setreg CA\CRLOverlapUnits 12
        #Disabling Delta CRL publishing
        certutil -setreg CA\CRLDeltaPeriodUnits 0
        certutil.exe -setreg CA\ValidityPeriodUnits 10
        certutil.exe -setreg CA\ValidityPeriod "Years"
        certutil.exe -setreg CA\AuditFilter 127
        # We have to remove the "digital signature" from the Future certificate we will generate.
        certutil.exe -setreg policy\editflags -EDITF_ADDOLDKEYUSAGE
   
    }
    catch 
    {
        Write-Output "Error - Unable to configure SubCA settings"
        Write-Output $ErrorMessage
        exit 1
    }
}

Function Install-CRLWebSite {
    <#
        .SYNOPSIS
            This function will install IIS WebSite for CRL checks.
        .DESCRIPTION
            This function will :
                - Install IIS Role
                - Remove Default Web Site
                - Create new WebSite for CRL checks
                - Configure CRL checks WebSite
                
        .PARAMETER CRLWebSiteName
            The CRL Web Site Name (Default is: "PKI")
        .PARAMETER CRLFilePath
            The CRL File path where CRL are published (Default is C:\Windows\System32\CertSrv\CertEnroll)
        .PARAMETER CRLURLPath
            The CRL URL Path (Ex: "pki.domain.local")
    #>
    
    [CmdletBinding()]
    param (
            [Parameter(Mandatory=$false)]
            [string]$CRLWebSiteName="PKI",   
            [Parameter(Mandatory=$false)]
            [string]$CRLFilePath="C:\Windows\System32\CertSrv\CertEnroll",
            [Parameter(Mandatory=$true)]
            [string]$CRLURLPath
    )

    try 
    {   
        # Install the IIS Role
        Add-WindowsFeature Web-Server -IncludeManagementTools
    }
    catch 
    {
        Write-Output "Error - Unable to install IIS Role"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Remove Default Web Site
        Remove-WebSite -Name "Default Web Site"
    }
    catch 
    {
        Write-Output "Error - Unable to remove Default Web Site"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Create CRL Web Site
        New-WebSite -Name $CRLWebSiteName -Port 80 -PhysicalPath $CRLFilePath
    }
    catch 
    {
        Write-Output "Error - Unable to Create new WebSite for CRL checks"
        Write-Output $ErrorMessage
        exit 1
    }
    try 
    {   
        #Configure CRL Web Site
        Get-WebBinding -Name $CRLWebSiteName | Remove-WebBinding
        New-WebBinding -Name $CRLWebSiteName  -IPAddress "*" -HostHeader $CRLURLPath -Port 80
    }
    catch 
    {
        Write-Output "Error - Unable to configure CRL Web Site"
        Write-Output $ErrorMessage
        exit 1
    }
}
