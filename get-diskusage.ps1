function Get-DiskUsage {
    <#
    .SYNOPSIS
    Analyzes disk usage for a specified path and provides detailed folder size information.
    
    .DESCRIPTION
    This function retrieves disk usage information for a specified path and lists the largest folders/files.
    It will alert if the free disk space for the drive is below 10%. Additionally, it organizes folder info 
    by depth and uses visual indicators.

    .EXAMPLE
    To get the top 10 largest folders/files of path 'C:\Windows\System32' up to a depth of 3:

    Get-DiskUsage -Path "C:\Windows\System32" -TopN 10 -Depth 3

    .EXAMPLE
    To get detailed folder size information for path 'C:\' considering top 5 items:

    Get-DiskUsage -Path "C:\" -TopN 5 -Depth 2

    .PARAMETER Path
    Specifies the directory path to analyze. Default is 'C:\'.
    
    .PARAMETER TopN
    Specifies the number of top items to be displayed. Default is 10.
    
    .PARAMETER Depth
    Specifies the depth to explore within the directory structure. Default is 1.
    .NOTES
    Author : Ivica Agatunovic
    WebSite: https://github.com/ivicaagatunovic
    Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024
    #>
    param (
        [string]$Path = "C:\",
        [int]$TopN = 10,
        [int]$Depth = 1
    )

    if (-not (Test-Path $Path)) {
        Write-Error "Path '$Path' does not exist."
        return
    }

    # Get disk size details
    $drive = Get-PSDrive -Name ($Path[0]) -ErrorAction SilentlyContinue
    if (-not $drive) {
        Write-Error "Invalid drive or unable to retrieve drive information."
        return
    }

    $diskInfo = [PSCustomObject]@{
        Drive        = $drive.Name
        UsedSpaceGB  = [math]::Round(($drive.Used / 1GB), 2)
        FreeSpaceGB  = [math]::Round(($drive.Free / 1GB), 2)
        TotalSpaceGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
        FreeSpacePct = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 2)
    }

    # Check if Free Space is below 10% and display a warning
    if ($diskInfo.FreeSpacePct -lt 10) {
        Write-Host "`n⚠️⚠️ WARNING: Low Disk Space! ⚠️⚠️" -ForegroundColor Red
    }

    $diskInfo | Format-Table -AutoSize

    Write-Host "Analyzing top $TopN largest folders/files in '$Path' up to a depth of $Depth...`n" -ForegroundColor Cyan

    # Function to compute the size of a directory
    function Get-DirectorySize {
        param (
            [string]$DirectoryPath
        )
        return (Get-ChildItem -Path $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object {!$_.PSIsContainer} |
                Measure-Object -Property Length -Sum).Sum
    }

    # Improved path truncation to show more relevant parts
    function Set-TruncatePath {
        param (
            [string]$Path,
            [int]$MaxLength = 60
        )
        if ($Path.Length -gt $MaxLength) {
            $front = [math]::Ceiling($MaxLength / 2) - 3
            $end = $MaxLength - $front - 3
            return $Path.Substring(0, $front) + "..." + $Path.Substring($Path.Length - $end, $end)
        }
        return $Path
    }

    # Function to get top N directories at each requested depth
    function Get-TopDirectories {
        param (
            [string]$ParentPath,
            [int]$CurrentDepth
        )

        if ($CurrentDepth -gt $Depth) {
            return
        }

        # Get top N directories at the current depth
        $childItems = Get-ChildItem -Path $ParentPath -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.FullName
                Size = Get-DirectorySize -DirectoryPath $_.FullName
            }
        } | Sort-Object Size -Descending | Select-Object -First $TopN

        foreach ($item in $childItems) {
            $sizeGB = [math]::Round($item.Size / 1GB, 2)
            $sizePct = [math]::Round(($item.Size / $totalSpace) * 100, 2)
            $indent = "   " * ($CurrentDepth - 1) + "└── "

            try {
                # Use full path for root level and only folder name for deeper levels if possible
                $displayName = if ($CurrentDepth -eq 1) { $item.Name } else { (Get-Item -LiteralPath $item.Name -ErrorAction SilentlyContinue).Name }
            } catch {
                $displayName = "[Error: Can't Retrieve Name]"
            }

            if ($CurrentDepth -eq 1) {
                # Color the root directory name
                Write-Host ($($indent + "📁 " + (Set-TruncatePath $displayName)).PadRight(70) + ("💾 " + $sizeGB.ToString()).PadRight(10) + ("% " + $sizePct.ToString()).PadRight(10) + $CurrentDepth.ToString().PadRight(5)) -ForegroundColor Yellow
            } else {
                # Standard output for subfolders
                Write-Host ($($indent + "📁 " + (Set-TruncatePath $displayName)).PadRight(70) + ("💾 " + $sizeGB.ToString()).PadRight(10) + ("% " + $sizePct.ToString()).PadRight(10) + $CurrentDepth.ToString().PadRight(5))
            }

            # Recursive call for the next depth level
            Get-TopDirectories -ParentPath $item.Name -CurrentDepth ($CurrentDepth + 1)
        }
    }

    # Calculate total space in bytes
    $totalSpace = $diskInfo.TotalSpaceGB * 1GB

    # Display headers
    Write-Host ("Name".PadRight(70) + "SizeGB".PadRight(10) + "Percent".PadRight(10) + "Depth")
    Write-Host ("----".PadRight(70, '-') + "------".PadRight(10, '-') + "----------".PadRight(10, '-') + "-----")

    # Start with the provided path
    Get-TopDirectories -ParentPath $Path -CurrentDepth 1

    # Get the largest overall items
    $items = Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.PSIsContainer) {
            $size = Get-DirectorySize -DirectoryPath $_.FullName
        } else {
            $size = $_.Length
        }
        [PSCustomObject]@{
            Name = $_.FullName
            SizeGB = [math]::Round(($size / 1GB), 2)
        }
    } | Sort-Object SizeGB -Descending | Select-Object -First $TopN

    # Assign colors for gradient
    $colors = @('Red', 'DarkYellow', 'Yellow')

    if ($items) {
        # Calculate bar chart representation for top 10 folders
        Write-Host "`nTop 10 Folders by Size (Bar Chart Representation):"
        $topItems = $items | Sort-Object SizeGB -Descending | Select-Object -First 10
        $maxSize = $topItems | Measure-Object -Property SizeGB -Maximum | Select-Object -ExpandProperty Maximum

        for ($i = 0; $i -lt $topItems.Count; $i++) {
            $item = $topItems[$i]
            $bar = "█" * ([math]::Round(($item.SizeGB / $maxSize) * 50))
            $colorIndex = [math]::Round((($colors.Length - 1) * $i) / ($topItems.Count - 1))
            $color = $colors[$colorIndex]
            Write-Host ((Set-TruncatePath $item.Name).PadRight(55) + "$bar " + "($($item.SizeGB)GB)") -ForegroundColor $color
        }
    } else {
        Write-Host "No large files or folders found in '$Path'." -ForegroundColor Yellow
    }
}

# Example usage
Get-DiskUsage -Path "C:\Windows\System32\" -TopN 3 -Depth 3
