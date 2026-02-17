<#
Copy files referenced in an M3U playlist to a destination directory.

Usage:
  .\copy-m3u-playlist-files-to-directory.ps1 playlist.m3u C:\destination\
  .\copy-m3u-playlist-files-to-directory.ps1 -nomixtape playlist.m3u C:\destination\
  .\copy-m3u-playlist-files-to-directory.ps1 --no-mixtape playlist.m3u C:\destination\
#>

param (
    [string]$m3ufile = "playlist.m3u",
    [string]$dest = ".",
    [switch]$SkipMissing = $false,
    [switch]$Verbose = $false,
    [switch]$nomixtape = $false
)

# -nomixtape is bound directly from the param block above.
# --no-mixtape uses a double-dash which PowerShell does not accept as a named
# parameter, so it falls through to $args and is checked manually here.
$no_mixtape_flag = $false
if ($args -contains "--no-mixtape" -or $nomixtape) {
    $no_mixtape_flag = $true
}

# Decode URL-encoded strings (%20 -> space, etc.)
function Decode-Url {
    param ([string]$url)
    return [System.Uri]::UnescapeDataString($url)
}

# Detect file encoding by inspecting raw bytes, returning a .NET Encoding object.
#
# FIX: The old script hardcoded -Encoding UTF8 on Get-Content, which silently
# corrupts characters like e-umlaut (0xEB) in Windows-1252/ANSI files saved by
# Winamp or Windows Media Player.
#
# FIX: The new script returned encoding strings ("Default", "unicode", etc.) to
# Get-Content -Encoding. This broke on PowerShell 7+: "Default" means system ANSI
# on PS5 but UTF-8 on PS7, so ANSI files still failed silently.
#
# This version returns .NET Encoding objects and the caller uses
# [System.IO.File]::ReadAllText() directly, which behaves identically on PS5 and PS7.
#
# Detection order:
#   1. BOM check (UTF-8, UTF-16 LE, UTF-16 BE) -- unambiguous, always checked first
#   2. Strict UTF-8 decode -- if whole file decodes without error it is valid UTF-8
#   3. Fall back to Windows-1252 (cp1252) -- covers Winamp/WMP ANSI output,
#      superset of ISO-8859-1, built into .NET on all platforms including PS7 on Linux
function Get-FileEncoding {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    # UTF-8 BOM (EF BB BF)
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8
    }

    # UTF-16 LE BOM (FF FE)
    if ($bytes.Length -ge 2 -and
        $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode
    }

    # UTF-16 BE BOM (FE FF)
    if ($bytes.Length -ge 2 -and
        $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [System.Text.Encoding]::BigEndianUnicode
    }

    # Try strict UTF-8 (second argument $true = throwOnInvalidBytes)
    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    try {
        [void]$utf8Strict.GetString($bytes)
        return [System.Text.Encoding]::UTF8
    } catch {
        # Not valid UTF-8, fall through to Windows-1252
    }

    # Fall back to Windows-1252. GetEncoding(1252) is available on all .NET
    # platforms including Linux/macOS builds of PowerShell 7.
    return [System.Text.Encoding]::GetEncoding(1252)
}

# Search for a file by exact path first, then by filename in common locations.
# Uses -LiteralPath throughout so square brackets and apostrophes in paths are
# treated as literal characters and not wildcards.
#
# FIX: Old script used Get-ChildItem -Name $filename. -Name is a switch that makes
# the cmdlet return strings instead of objects; the filename was being passed as a
# stray positional argument, not a name filter. Fixed with Where-Object.
function Find-File {
    param ([string]$originalPath)

    # If original path exists, return it
    if (Test-Path -LiteralPath $originalPath) {
        return $originalPath
    }

    # Extract filename
    $filename = [System.IO.Path]::GetFileName($originalPath)

    # Search current directory and subdirectories
    $found = Get-ChildItem -Path (Get-Location) -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $filename } |
        Select-Object -First 1

    if ($found) { return $found.FullName }

    # Search common music directories if they exist
    $commonPaths = @(
        "$env:USERPROFILE\Music",
        "$env:PUBLIC\Music",
        "C:\Music",
        "D:\Music"
    )

    foreach ($basePath in $commonPaths) {
        if (Test-Path -LiteralPath $basePath) {
            $found = Get-ChildItem -LiteralPath $basePath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq $filename } |
                Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    return $null
}

# Validate M3U file
if (-not (Test-Path -LiteralPath $m3ufile)) {
    Write-Error "M3U file '$m3ufile' not found"
    exit 1
}

# Create destination directory if it does not exist.
# [System.IO.Directory]::CreateDirectory() is consistent across PS5 and PS7
# and silently succeeds if the directory already exists.
if (-not (Test-Path -LiteralPath $dest)) {
    [System.IO.Directory]::CreateDirectory($dest) | Out-Null
    Write-Host "Created destination directory: $dest"
}

$files   = @()
$skipped = @()

# Read the playlist using the detected encoding.
# [System.IO.File]::ReadAllText() with an Encoding object is used instead of
# Get-Content -Encoding because Get-Content's string encoding names have
# version-dependent behaviour ("Default" = ANSI on PS5, UTF-8 on PS7).
# Lines are split manually to handle \r\n (Windows), \n (Unix), and \r (old Mac).
try {
    $encoding = Get-FileEncoding -Path $m3ufile
    Write-Host "Detected encoding: $($encoding.EncodingName)" -ForegroundColor Cyan

    $content = [System.IO.File]::ReadAllText($m3ufile, $encoding)
    $lines   = $content -split "`r`n|`n|`r"

    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $files += (Decode-Url $line)
        }
    }
} catch {
    Write-Error "Error reading file '$m3ufile': $($_.Exception.Message)"
    exit 1
}

$goal = $files.Count

if ($goal -eq 0) {
    Write-Host "No files found in playlist."
    exit 1
}

$progress = 0
$counter  = 1

# Display mode information
$modeText = if ($no_mixtape_flag) { "without numbering" } else { "with numbering" }
Write-Host "Processing $goal files from playlist ($modeText)..." -ForegroundColor Green

# Copy files to the destination directory
foreach ($path in $files) {

    $foundPath = Find-File -originalPath $path

    if ($foundPath) {
        try {
            $filename = [System.IO.Path]::GetFileName($foundPath)

            # Create filename based on -nomixtape or --no-mixtape flag
            if ($no_mixtape_flag) {
                $new_filename = $filename
            } else {
                $extension    = [System.IO.Path]::GetExtension($filename)
                $base         = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $new_filename = "{0:D3}_{1}{2}" -f $counter, $base, $extension
            }

            $destinationPath = Join-Path -Path $dest -ChildPath $new_filename

            # -LiteralPath on source handles square brackets and apostrophes
            Copy-Item -LiteralPath $foundPath -Destination $destinationPath -ErrorAction Stop

            $progress++
            $counter++

            if ($Verbose) {
                # FIX: verbose must show when numbering
                if ($no_mixtape_flag) {
                    Write-Host "[$progress/$goal] Copied: $filename" -ForegroundColor Gray
                } else {
                    Write-Host "[$progress/$goal] Copied: $filename -> $new_filename" -ForegroundColor Gray
                }
            } else {
                Write-Progress -Activity "Copying files" `
                    -Status "$progress of $goal files copied" `
                    -PercentComplete (($progress / $goal) * 100)
            }

        } catch {
            Write-Warning "Failed to copy '$foundPath': $($_.Exception.Message)"
            $skipped += $path
        }
    } else {
        $skipped += $path
        if ($Verbose) {
            Write-Host "Missing: $([System.IO.Path]::GetFileName($path))" -ForegroundColor Yellow
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
