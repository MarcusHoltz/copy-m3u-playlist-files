# Run this Powershell script with a command like:
#  copy-m3u-playlist-files-to-directory.ps1 playlist.m3u C:\path\to\destination\somefolder\


param (
    [string]$m3ufile = "playlist.m3u",
    [string]$dest = "."
)

# Function to decode URL-encoded strings
function Decode-Url {
    param (
        [string]$url
    )
    return [System.Uri]::UnescapeDataString($url)
}

# Check if m3u file is provided
if (-not $m3ufile) {
    Write-Error "No m3u file given"
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path -Path $dest)) {
    New-Item -ItemType Directory -Path $dest | Out-Null
}

$files = @()
$skipped = @()

# Read the m3u file and collect file paths
try {
    $lines = Get-Content -Path $m3ufile
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -and $line[0] -ne '#') {
            $files += (Decode-Url $line)
        }
    }
} catch {
    Write-Error "File not found."
    exit 1
}

$goal = $files.Count
$progress = 0
$counter = 1  # Initialize counter for incrementing filenames

# Copy files to the destination directory with incrementing numbers
foreach ($path in $files) {
    if (Test-Path -Path $path) {
        $filename = Split-Path -Path $path -Leaf
        $extension = [System.IO.Path]::GetExtension($filename)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        $new_filename = "{0}_{1:D3}{2}" -f $counter, $base, $extension
        Copy-Item -Path $path -Destination (Join-Path -Path $dest -ChildPath $new_filename)
        $progress++
        $counter++
        Write-Host ("`e[2J{0} of {1} collected!!" -f $progress, $goal)
    } else {
        $skipped += $path
    }
}

# Report missing files
if ($skipped.Count -ne 0) {
    Write-Error "Missing files:"
    foreach ($path in $skipped) {
        Write-Error $path
    }
    exit 2
} else {
    Write-Host ("All files collected in {0} directory. Enjoy!" -f $dest)
}
