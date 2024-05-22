#!/bin/bash

# Run this Bash script with a command like:
#  bash copy-m3u-playlist-files-to-directory.sh playlist.m3u /home/user/Music/somefiles

# Check if an m3u file is provided
if [ -z "$1" ]; then
    echo "No m3u file given, defaulting to playlist.m3u" >&2
    m3ufile="playlist.m3u"
fi

m3ufile="$1"


# Check for destination argument
if [ -z "$2" ]; then
    dest="."
else
    dest="$2"
    mkdir -p "$dest"
fi

files=()
skipped=()

# Read the m3u file and collect file paths
if [ ! -f "$m3ufile" ]; then
    echo "File not found." >&2
    exit 1
fi

counter=1
while IFS= read -r line; do
    line=$(echo "$line" | xargs)  # Trim whitespace
    if [[ -n "$line" && "$line" != \#* ]]; then
        files+=("$(echo -e "${line//%/\\x}")")  # Decode URL encoding
    fi
done < "$m3ufile"

goal=${#files[@]}
progress=0

# Copy files to the destination directory with incrementing numbers
for path in "${files[@]}"; do
    if [ -e "$path" ]; then
        filename=$(basename "$path")
        extension="${filename##*.}"
        base="${filename%.*}"
        new_filename="${counter}_${base}.${extension}"
        cp "$path" "$dest/$new_filename"
        ((progress++))
        ((counter++))
        echo -e "\033[2J${progress} of ${goal} collected!!"
    else
        skipped+=("$path")
    fi
done

# Report missing files
if [ ${#skipped[@]} -ne 0 ]; then
    echo "Missing files:" >&2
    for path in "${skipped[@]}"; do
        echo "$path" >&2
    done
    exit 2
else
    echo "All files collected in ${dest} directory. Enjoy!"
fi
