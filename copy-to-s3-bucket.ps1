<#
.SYNOPSIS
    Installs necessary AWS PowerShell modules, uploads files to an S3 bucket, and verifies the upload.

.DESCRIPTION
    This script performs the following tasks:
    1. Installs the AWS PowerShell tools required to interact with AWS S3.
    2. Uploads files from a specified local directory to a designated S3 bucket.
    3. Verifies the files uploaded to the S3 bucket by listing the objects in the bucket.

    The script uses AWS access keys for authentication and assumes the user has appropriate permissions for S3 access.

.PARAMETER None
    This script does not accept any parameters. AWS credentials, bucket name, and file paths are hardcoded within the script.

.EXAMPLE
    Run the script as follows:
    ```powershell
    .\UploadToS3.ps1
    ```
    This will upload all files from the local `C:\temp` directory to the specified S3 bucket.

.NOTES
    - Replace `<Get Your Own>` with your actual AWS Access Key and Secret Key.
    - Ensure that the `AWS.Tools.Installer` and `AWS.Tools.S3` modules are installed.
    - Make sure the S3 bucket exists, and you have permissions to upload files.
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024

    The script uses bucket-owner-full-control ACL to give the bucket owner full access to the uploaded objects.
#>

# Install AWS Tools module if not already installed
Install-Module -Name AWS.Tools.Installer -Force

# Install the AWS S3 module, cleaning up any older versions
Install-AWSToolsModule AWS.Tools.S3 -CleanUp

# Define the S3 bucket name
$bucket = 'some-s3-bucket'

# Set AWS Credentials (replace <Get Your Own> with actual credentials)
Set-AWSCredential `
    -AccessKey '<Get Your Own>' `
    -SecretKey '<Get Your Own>'

# Gather files from the local directory 'C:\temp' to upload
$files = Get-ChildItem 'C:\temp\*'

# Upload the files to the specified S3 bucket
foreach ($file in $files) {
    $filePath = Join-Path $file.Directory $file.Name
    
    # Output status of the file upload process
    Write-Host ("Uploading '{0}'..." -f $file.Name)
    
    # Upload each file to the S3 bucket
    Write-S3Object -BucketName $bucket -File $filePath -Key $file.Name -CannedACLName bucket-owner-full-control
}

# Notify user that the upload process is complete
Write-Host "File upload completed."

# Verify the upload by listing the objects in the S3 bucket
Write-Host "Verifying uploaded files in S3..."
Get-S3Object -BucketName $bucket

Write-Host "Verification complete."
