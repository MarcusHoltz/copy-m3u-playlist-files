from __future__ import print_function
from itertools import count
import shutil
import os
import sys
import urllib

# Run this Python script with a command like:
#  python copy-m3u-playlist-files-to-directory.py playlist.m3u /path/to/destination

try:
    m3ufile = sys.argv.pop(1)
except IndexError:
    print("No m3u file given, defaulting to playlist.m3u", file=sys.stderr)
    m3ufile = 'playlist.m3u'

# check for destination arg
try:
    dest = sys.argv.pop(1)
except IndexError:
    dest = '.'
else:
    os.makedirs(dest, exist_ok=True)

files = []

try:
    with open(m3ufile) as f:
        for line in f:
            line = line.strip()
            if line and line[0] != '#':
                files.append(urllib.unquote(line).decode('utf8'))
except IOError:
    print("File not found.")
    sys.exit(1)

progress, goal = count(1), len(files)
skipped = []
counter = 1  # Initialize counter for incrementing filenames

for path in files:
    if os.path.exists(path):
        filename = os.path.basename(path)
        extension = os.path.splitext(filename)[1]
        base = os.path.splitext(filename)[0]
        new_filename = f"{counter:03d}_{filename}"
        shutil.copy(path, os.path.join(dest, new_filename))
        print(f"\x1b[2J{next(progress)} of {goal} collected!!")
        counter += 1
    else:
        skipped.append(path)

if skipped:
    print("Missing files:", file=sys.stderr)
    for path in skipped:
        print(path, file=sys.stderr)
    sys.exit(2)
else:
    print(f"All files collected in {dest} directory. Enjoy!")
