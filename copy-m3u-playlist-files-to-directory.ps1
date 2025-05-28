# Run this Powershell script with a command like:
#  copy-m3u-playlist-files-to-directory.ps1 playlist.m3u C:\path\to\destination\somefolder\
#  copy-m3u-playlist-files-to-directory.ps1 -nomixtape playlist.m3u C:\path\to\destination\somefolder\
#  copy-m3u-playlist-files-to-directory.ps1 --no-mixtape playlist.m3u C:\path\to\destination\somefolder\

param (
    [string]$m3ufile = "playlist.m3u",
    [string]$dest = ".",
    [switch]$SkipMissing = $false,
    [switch]$Verbose = $false,
    [switch]$nomixtape = $false
)

# Check for --no-mixtape in $args (PowerShell doesn't handle -- parameters in param block)
$no_mixtape_flag = $false
if ($args -contains "--no-mixtape" -or $nomixtape) {
    $no_mixtape_flag = $true
}

# Function to decode URL-encoded strings
function Decode-Url {
    param (
        [string]$url
    )
    return [System.Uri]::UnescapeDataString($url)
}

# Function to search for files in common locations
function Find-File {
    param (
        [string]$originalPath
    )
    
    # If original path exists, return it
    if (Test-Path -Path $originalPath) {
        return $originalPath
    }
    
    # Extract filename
    $filename = Split-Path -Path $originalPath -Leaf
    
    # Search in current directory and subdirectories
    $found = Get-ChildItem -Path "." -Recurse -Name $filename -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return (Join-Path -Path (Get-Location) -ChildPath $found)
    }
    
    # Try common music directories if they exist
    $commonPaths = @(
        "$env:USERPROFILE\Music",
        "$env:PUBLIC\Music",
        "C:\Music",
        "D:\Music"
    )
    
    foreach ($basePath in $commonPaths) {
        if (Test-Path -Path $basePath) {
            $found = Get-ChildItem -Path $basePath -Recurse -Name $filename -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                return (Join-Path -Path $basePath -ChildPath $found)
            }
        }
    }
    
    return $null
}

# Check if m3u file is provided
if (-not $m3ufile) {
    Write-Error "No m3u file given"
    exit 1
}

if (-not (Test-Path -Path $m3ufile)) {
    Write-Error "M3U file '$m3ufile' not found"
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path -Path $dest)) {
    New-Item -ItemType Directory -Path $dest | Out-Null
    Write-Host "Created destination directory: $dest"
}

$files = @()
$skipped = @()
$found = @()

# Read the m3u file and collect file paths
try {
    $lines = Get-Content -Path $m3ufile -Encoding UTF8
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -and $line[0] -ne '#') {
            $files += (Decode-Url $line)
        }
    }
} catch {
    Write-Error "Error reading file '$m3ufile': $($_.Exception.Message)"
    exit 1
}

$goal = $files.Count
$progress = 0
$counter = 1

# Display mode information
$modeText = if ($no_mixtape_flag) { "without numbering" } else { "with numbering" }
Write-Host "Processing $goal files from playlist ($modeText)..." -ForegroundColor Green

# Copy files to the destination directory
foreach ($path in $files) {
    $foundPath = Find-File -originalPath $path
    
    if ($foundPath) {
        try {
            $filename = Split-Path -Path $foundPath -Leaf
            
            # Create filename based on -nomixtape or --no-mixtape parameter
            if ($no_mixtape_flag) {
                $new_filename = $filename
            } else {
                $extension = [System.IO.Path]::GetExtension($filename)
                $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $new_filename = "{0:D3}_{1}{2}" -f $counter, $base, $extension
            }
            
            Copy-Item -Path $foundPath -Destination (Join-Path -Path $dest -ChildPath $new_filename) -ErrorAction Stop
            $progress++
            $counter++
            
            if ($Verbose) {
                if ($no_mixtape_flag) {
                    Write-Host "[$progress/$goal] Copied: $filename" -ForegroundColor Gray
                } else {
                    Write-Host "[$progress/$goal] Copied: $filename -> $new_filename" -ForegroundColor Gray
                }
            } else {
                Write-Progress -Activity "Copying files" -Status "$progress of $goal files copied" -PercentComplete (($progress / $goal) * 100)
            }
            
            $found += $foundPath
        } catch {
            Write-Warning "Failed to copy '$foundPath': $($_.Exception.Message)"
            $skipped += $path
        }
    } else {
        $skipped += $path
        if ($Verbose) {
            Write-Host "Missing: $(Split-Path -Path $path -Leaf)" -ForegroundColor Yellow
        }
    }
}

Write-Progress -Activity "Copying files" -Completed

# Report results
Write-Host "`nCopy completed!" -ForegroundColor Green
Write-Host "Successfully copied: $progress files" -ForegroundColor Green

if ($skipped.Count -gt 0) {
    Write-Host "Missing files: $($skipped.Count)" -ForegroundColor Yellow
    
    if (-not $SkipMissing) {
        Write-Host "`nMissing files:" -ForegroundColor Yellow
        foreach ($path in $skipped) {
            Write-Host "  $path" -ForegroundColor Red
        }
        
        Write-Host "`nTip: Use -SkipMissing to suppress missing file list" -ForegroundColor Cyan
        Write-Host "Tip: Use -Verbose for detailed copy information" -ForegroundColor Cyan
        Write-Host "Tip: Use -nomixtape or --no-mixtape to copy without numbered prefixes" -ForegroundColor Cyan
    }
    
    if ($progress -eq 0) {
        exit 2
    }
} else {
    Write-Host "All files found and copied successfully!" -ForegroundColor Green
}

Write-Host "`nFiles copied to: $dest" -ForegroundColor Cyan