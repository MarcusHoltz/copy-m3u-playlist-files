#!/bin/bash

# Run this Bash script with a command like:
# bash copy-m3u-playlist-files-to-directory.sh playlist.m3u /home/user/Music/somefiles
# bash copy-m3u-playlist-files-to-directory.sh --no-mixtape playlist.m3u /home/user/Music/somefiles
# bash copy-m3u-playlist-files-to-directory.sh -nomixtape playlist.m3u /home/user/Music/somefiles

# Parse arguments for --no-mixtape and -nomixtape flags
no_mixtape=false
args=()

for arg in "$@"; do
    if [ "$arg" = "--no-mixtape" ] || [ "$arg" = "-nomixtape" ]; then
        no_mixtape=true
    else
        args+=("$arg")
    fi
done

# Check if an m3u file is provided
if [ -z "${args[0]}" ]; then
    echo "No m3u file given, defaulting to playlist.m3u" >&2
    m3ufile="playlist.m3u"
else
    m3ufile="${args[0]}"
fi

# Check for destination argument
if [ -z "${args[1]}" ]; then
    dest="."
else
    dest="${args[1]}"
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
while IFS= read -r line || [ -n "$line" ]; do
    # Remove carriage returns and trim whitespace manually
    line=$(echo "$line" | tr -d '\r')
    # Trim leading and trailing whitespace without xargs
    line="${line#"${line%%[![:space:]]*}"}"  # Remove leading whitespace
    line="${line%"${line##*[![:space:]]}"}"  # Remove trailing whitespace
    
    if [[ -n "$line" && "$line" != \#* ]]; then
        # Simple URL decoding for common cases
        decoded_line=$(printf '%b' "${line//%/\\x}" 2>/dev/null || echo "$line")
        files+=("$decoded_line")
    fi
done < "$m3ufile"

goal=${#files[@]}
progress=0

# Display mode information
if [ "$no_mixtape" = true ]; then
    mode_text="without numbering"
else
    mode_text="with numbering"
fi

echo "Found $goal files in playlist. Starting copy ($mode_text)..."

# Copy files to the destination directory
for path in "${files[@]}"; do
    if [ -e "$path" ]; then
        filename=$(basename "$path")
        
        # Create filename based on --no-mixtape flag
        if [ "$no_mixtape" = true ]; then
            new_filename="$filename"
        else
            # Use printf to format counter with leading zeros
            new_filename=$(printf "%03d_%s" "$counter" "$filename")
        fi
        
        cp "$path" "$dest/$new_filename"
        ((progress++))
        ((counter++))
        printf "Copied %d of %d: %s\n" "$progress" "$goal" "$filename"
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