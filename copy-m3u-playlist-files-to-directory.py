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

files = []

# Read the m3u file
try:
    with open(m3ufile, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip().replace('\r', '')  # Remove carriage returns and whitespace
            if line and not line.startswith('#'):
                # URL decode the line
                try:
                    decoded_line = unquote(line)
                    files.append(decoded_line)
                except Exception:
                    # If URL decoding fails, use the original line
                    files.append(line)
except IOError:
    print(f"File not found: {m3ufile}", file=sys.stderr)
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
for i, path in enumerate(files, 1):
    if os.path.exists(path):
        filename = os.path.basename(path)
        
        # Create filename based on --no-mixtape flag
        if no_mixtape:
            new_filename = filename
        else:
            # Create new filename with zero-padded counter
            new_filename = f"{counter:03d}_{filename}"
        
        dest_path = os.path.join(dest, new_filename)
        
        try:
            shutil.copy2(path, dest_path)  # copy2 preserves metadata
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