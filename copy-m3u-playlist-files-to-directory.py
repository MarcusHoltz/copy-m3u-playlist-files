#!/usr/bin/env python3

import shutil
import os
import sys
from urllib.parse import unquote

# Run this Python script with a command like:
#   python3 copy-m3u-playlist-files-to-directory.py playlist.m3u /path/to/destination
#   python3 copy-m3u-playlist-files-to-directory.py --no-mixtape playlist.m3u /path/to/destination
#   python3 copy-m3u-playlist-files-to-directory.py -nomixtape playlist.m3u /path/to/destination

# Parse arguments
no_mixtape = False
args = sys.argv[1:]

# Check for --no-mixtape or -nomixtape flags
if '--no-mixtape' in args:
    no_mixtape = True
    args.remove('--no-mixtape')
elif '-nomixtape' in args:
    no_mixtape = True
    args.remove('-nomixtape')

# Get m3u file argument
if len(args) < 1:
    print("No m3u file given, defaulting to playlist.m3u", file=sys.stderr)
    m3ufile = 'playlist.m3u'
else:
    m3ufile = args[0]

# Get destination argument
if len(args) < 2:
    dest = '.'
else:
    dest = args[1]
    os.makedirs(dest, exist_ok=True)

if not os.path.isfile(m3ufile):
    print(f"File not found: {m3ufile}", file=sys.stderr)
    sys.exit(1)

# Detect encoding using stdlib only -- no third-party packages required.
#
# Steps:
# 1. BOM check (raw bytes): catches UTF-8-sig and UTF-16 LE/BE, which are written
#    by some players and editors and cannot be reliably detected any other way.
# 2. Try strict UTF-8: if the entire file decodes without error it is valid UTF-8.
# 3. Fall back to cp1252 (Windows-1252/ANSI): this is the encoding Windows apps
#    such as Winamp and Windows Media Player use when saving M3U files. It covers
#    characters like e-umlaut (0xEB) in the Tisto example. cp1252 is built into
#    Python's stdlib on all platforms.
# 4. Final fallback to latin-1: maps bytes 0x00-0xFF directly to Unicode U+0000-
#    U+00FF and never raises a decode error, so it always produces something usable.
def detect_encoding(file_path):
    with open(file_path, 'rb') as f:
        raw = f.read(4)

    # BOM-based detection
    if raw.startswith(b'\xef\xbb\xbf'):
        return 'utf-8-sig'
    if raw.startswith(b'\xff\xfe') or raw.startswith(b'\xfe\xff'):
        return 'utf-16'

    # Try strict UTF-8 on the whole file
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            f.read()
        return 'utf-8'
    except UnicodeDecodeError:
        pass

    # Try cp1252 (Windows-1252 / ANSI) -- covers most Windows-created M3U files
    try:
        with open(file_path, 'r', encoding='cp1252') as f:
            f.read()
        return 'cp1252'
    except UnicodeDecodeError:
        pass

    # latin-1 never fails on any byte sequence -- safe last resort
    return 'latin-1'

m3uencoding = detect_encoding(m3ufile)

files = []
# Read the m3u file
#
# errors = for any byte that still cannot be decoded, which is 
# safer than 'ignore'  -- which silently drops bytes and can corrupt filenames 
# and if they're corrupted they no longer match what is on disk!
try:
    with open(m3ufile, 'r', encoding=m3uencoding, errors='replace') as f:
        for line in f:
            # strip() handles both \r\n (Windows) and \n (Unix) line endings
            line = line.strip()
            if line and not line.startswith('#'):
                # URL decode the line
                try:
                    # Pass the same encoding to unquote so %XX sequences in
                    # the path are decoded with the correct character set
                    decoded_line = unquote(line, encoding=m3uencoding)
                    files.append(decoded_line)
                except Exception:
                    # If URL decoding fails, use the original line
                    files.append(line)
except IOError:
    print(f"Could not open file: {m3ufile}", file=sys.stderr)
    sys.exit(1)

if not files:
    print("No files found in playlist.")
    sys.exit(1)

goal = len(files)
skipped = []
counter = 1

mode_text = "without numbering" if no_mixtape else "with numbering"
print(f"Found {goal} files in playlist. Starting copy ({mode_text})...")

# Copy files to destination
os.makedirs(dest, exist_ok=True)
for i, path in enumerate(files, 1):
    playlist_dir = os.path.dirname(os.path.abspath(m3ufile))

    #checks if path is relative and if so, joins path to the abspath of the playlist
    if not os.path.isabs(path):
        path = os.path.join(playlist_dir, path)
    if os.path.exists(path):
        filename = os.path.basename(path)        
        # Create filename based on --no-mixtape flag
        if no_mixtape:
            new_filename = filename
        else:
            # Create new filename with zero-padded counter
            new_filename = f"{counter:03d}_{filename}"
        print(new_filename)
        dest_path = os.path.join(dest, new_filename)

        try:
            shutil.copy2(path, dest_path)  # copy2 preserves file metadata
            print(f"Copied {i} of {goal}: {filename}")
            counter += 1
        except Exception as e:
            print(f"Error copying {filename}: {e}", file=sys.stderr)
            skipped.append(path)
    else:
        print(f"File not found: {path}", file=sys.stderr)
        skipped.append(path)

# Report results
if skipped:
    print(f"\nMissing or failed files ({len(skipped)}):", file=sys.stderr)
    for path in skipped:
        print(f"  {path}", file=sys.stderr)
    sys.exit(2)
else:
    print(f"\nAll {goal} files successfully collected in '{dest}' directory. Enjoy!")

