<#
	.Synopsis
		Script prevents screen lock by executing scroll-lock key every X seconds
		
	.Description
		Script prevents screen lock by executing scroll-lock key every X seconds
		
	.Example
		scree-lock-off.ps1
		This will start the script
	
	.OUTPUTS
		PS C:\> c:\scripts\screen-lock-off.ps1

        Waiting  240  seconds
        Press Scroll lock
        Waiting  240  seconds
        Press Scroll lock
        Waiting  240  seconds
        Press Scroll lock

	.Notes
		Author : Ivica Agatunovic
		WebSite: https://github.com/ivicaagatunovic
		Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024 

#>

Clear-Host
Write-Output "...Lock screen avoider..."
$WShell = New-Object -com "Wscript.Shell"
$sleep = 300
while ($true)
{
    $WShell.sendkeys("{SCROLLLOCK}")
    Start-Sleep -Milliseconds 100
    Write-Host "Press Scroll lock"
    $WShell.sendkeys("{SCROLLLOCK}")
    Write-Host "Waiting " $sleep " seconds" 
    Start-Sleep -Seconds $sleep
}
