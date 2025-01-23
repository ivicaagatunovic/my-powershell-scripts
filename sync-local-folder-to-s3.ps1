<#
.SYNOPSIS
    Uploads files to an S3 bucket

.DESCRIPTION
    This script performs the following tasks:
    1. Unseals local secret store vault to grab AWS credentials.
    2. Checks if a folder exists in the S3 bucket and creates it if it does not.
    3. Fetches the current files in the S3 bucket under a specified folder.
    4. Identifies files to delete from the S3 bucket that are not present locally.
    5. Uploads files from a specified local directory to a designated S3 bucket.
    6. Logs the start, end, and completion of the sync process to the Windows Event Log.
    7. Logs all the steps of the sync process to local file.

    The script uses AWS access keys for authentication and assumes the user has appropriate permissions for S3 access.

.PARAMETER None
    This script does not accept any parameters. AWS credentials, bucket name, and file paths are hardcoded within the script.

.EXAMPLE
    Run the script as follows:
    ```powershell
    .\sync-local-folder-to-s3.ps1
    ```
    This will upload all files from the local `C:\temp` directory to the specified S3 bucket.

.NOTES
    - Ensure that the `AWS.Tools.Installer` and `AWS.Tools.S3` modules are installed.
    - The script uses the `bucket-owner-full-control` canned ACL to give the bucket owner full access to the uploaded objects.
    - Make sure secrets are stored in the local secret store vault.
    - Make sure unseal key and encrypted string are stored in the specified paths. 
    - Make sure the S3 bucket exists, and you have permissions to upload files.
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
#>

# Initialize logging 

# Define the log file path
$logFilePath = "C:\LOGS\s3-sync.log"

# Initialize the log file (clean for every execution)
if (Test-Path $logFilePath) {
    Remove-Item $logFilePath -Force
}
New-Item -ItemType File -Path $logFilePath -Force | Out-Null

# Function to write log entries
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logEntry | Add-Content -Path $logFilePath
    Write-Host $logEntry
}

if (-not [System.Diagnostics.EventLog]::SourceExists("s3-backup")) {
    New-EventLog -LogName Application -Source "s3-backup"
    Write-Log "Event log source 's3-backup' created successfully."
} else {
    Write-Log "Event log source 's3-backup' already exists."
}

# Get the hostname of the VM
$hostName = $env:COMPUTERNAME
Write-Log "Hostname determined: $hostName."
# Define the folder path in the S3 bucket
$destfolder = "$hostName/"
Write-Log "Destination folder in S3: $destfolder."
# Start logging
Write-Log "Script execution started."

# Define the S3 bucket name and local directory path
$endpoint = 'https://s3.core.emea.gi.worldline-solutions.com/'
$bucket = 'your-bucket-name'
$localDirectoryPath = "E:\"
$excludePath = "E:\path-to-exclude"
Write-Log "S3 endpoint: $endpoint "
Write-Log "S3 bucket: $bucket "

# Ensure the local directory exists
if (-Not (Test-Path $localDirectoryPath)) {
    $errorMessage = "The local directory $localDirectoryPath does not exist."
    Write-Log $errorMessage "ERROR"
    Write-EventLog -LogName Application -Source "s3-backup" -EntryType Warning -EventId 1004 -Message "The local directory $localDirectoryPath does not exist."
    exit 1
}

Write-Log "Local directory verified: $localDirectoryPath."

# Unseal local secret store vault
Write-Log "Unsealing local secret store vault..."
$key = Get-Content -Path "C:\Windows\System32\config\systemprofile\enc_key_secure_store.bin" -Encoding Byte
$encryptedString = Get-Content -Path "C:\Windows\System32\config\systemprofile\EncryptedString.txt"
$pass = $encryptedString | ConvertTo-SecureString -Key $key
Unlock-SecretStore -Password $pass
Write-Log "Secret store unlocked."

# Set AWS credentials
$secureAwsAccessKey = Get-Secret -Name s3_accesskey -Vault aws_s3 -AsPlainText
$secureAwsSecretKey = Get-Secret -Name s3_secretkey -Vault aws_s3 -AsPlainText

Import-Module AWS.Tools.S3
Import-Module AWS.Tools.Installer

Set-AWSCredential -AccessKey $secureAwsAccessKey -SecretKey $secureAwsSecretKey
Write-Log "AWS credentials set successfully."

# Check if a folder exists in the S3 bucket
function Test-S3FolderExists {
    param (
        [string]$BucketName,
        [string]$FolderPath
    )

    $objects = Get-S3Object -BucketName $bucket -Prefix $destfolder -EndpointUrl $endpoint -MaxKeys 1
    return $objects.Count -gt 0
}

# Check if the folder exists
$isFolderExists = Test-S3FolderExists -BucketName $bucket -FolderPath $destfolder -EndpointUrl $endpoint

if (-not $isFolderExists) {
    Write-Log "Folder '$destfolder' does not exist. Creating..."
    $tempFilePath = [System.IO.Path]::GetTempFileName()
    Write-S3Object -BucketName $bucket -Key $destfolder -File $tempFilePath -EndpointUrl $endpoint
    Remove-Item $tempFilePath
    Write-Log "Folder '$destfolder' created successfully."
} else {
    Write-Log "Folder '$destfolder' already exists in bucket '$bucket'."
}

$files = Get-ChildItem -Path $localDirectoryPath -Recurse -File | Where-Object { $_.FullName -notlike "$excludePath*" }
Write-Log "Local files retrieved for upload."

Write-EventLog -LogName Application -Source "s3-backup" -EntryType Information -EventId 1001 -Message "Starting sync with S3 bucket"

Write-Log "Fetching file list from S3..."
$s3Objects = Get-S3Object -BucketName $bucket -Prefix $destfolder -EndpointUrl $endpoint
$currentS3Keys = $s3Objects | ForEach-Object { $_.Key }
$localRelativePaths = $files | ForEach-Object { ($_.FullName.Substring($localDirectoryPath.Length).TrimStart('\')).Replace("\", "/") }
Write-Log "Fetched current files in S3."

$keysToDelete = $currentS3Keys | Where-Object { ($_ -like "$destfolder*") -and ($_ -notin $localRelativePaths) }

$deletedFilesCount = 0
$uploadedFilesCount = 0

foreach ($key in $keysToDelete) {
    Write-Log "Deleting outdated file '$key'..."
    Remove-S3Object -BucketName $bucket -Key $key -EndpointUrl $endpoint -Confirm:$false | Out-Null
    $deletedFilesCount++
}

Write-EventLog -LogName Application -Source "s3-backup" -EntryType Information -EventId 1002 -Message "S3 bucket cleanup complete. $deletedFilesCount files deleted. Proceeding with file upload..."
Write-Log "$deletedFilesCount outdated files deleted."

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($localDirectoryPath.Length).TrimStart('\')
    $s3Key = "$destfolder$relativePath".Replace("\", "/")
    Write-S3Object -BucketName $bucket -Key $s3Key -File $file.FullName -CannedACLName bucket-owner-full-control -EndpointUrl $endpoint -Confirm:$false
    Write-Log "Syncing file '$s3Key'..."
    $uploadedFilesCount++
}

Write-Log "$uploadedFilesCount files synced to S3 bucket."
Write-Log "Script execution completed."
Write-EventLog -LogName Application -Source "s3-backup" -EntryType Information -EventId 1003 -Message "S3 bucket sync completed! $uploadedFilesCount files uploaded."