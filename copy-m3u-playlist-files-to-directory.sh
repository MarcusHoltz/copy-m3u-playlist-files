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

# URL decode function.
#
# FIX: The old approach used `printf '%b' "${line//%/\\x}"` which replaces every
# '%' with '\x' then hands the whole string to printf %b. printf %b also interprets
# \n, \t, \r, etc., so Windows paths like C:\notes\track.mp3 have \n turned into a
# literal newline, breaking the file lookup silently.
#
# This regex-based function decodes only %XX sequences one at a time via BASH_REMATCH,
# calling printf only on the two hex digits -- never on the surrounding path text.
# printf '%s' is used for the final output so no further interpretation occurs.
# Apostrophes, square brackets, and backslashes all pass through unchanged.
urldecode() {
    local s="$1"
    local result=""
    while [[ "$s" =~ ^([^%]*)%([0-9A-Fa-f]{2})(.*)$ ]]; do
        result+="${BASH_REMATCH[1]}"
        # bash turns \\x into \x before printf sees it, so printf receives \xHH
        # and outputs the corresponding byte (standard printf \x escape behaviour).
        result+=$(printf "\\x${BASH_REMATCH[2]}")
        s="${BASH_REMATCH[3]}"
    done
    printf '%s' "${result}${s}"
}

# Detect file encoding and normalise to UTF-8.
#
# FIX: Previous BOM detection used `grep -q $'\xff\xfe'` which is locale-sensitive
# and can silently fail. `od -An -tx1` gives reliable raw hex output regardless of locale.
#
# FIX: Added Latin-1 / Windows-1252 support. Characters like e-umlaut (0xEB) in the
# Tisto example are Windows-1252. `file -b --mime-encoding` detects this along with
# UTF-16 and other encodings. BOM-based od detection is the fallback when `file`
# is unavailable.
tmpfile=$(mktemp)

if command -v file >/dev/null 2>&1; then
    detected=$(file -b --mime-encoding "$m3ufile" 2>/dev/null)
    case "$detected" in
        utf-16le | utf-16-le)
            iconv -f UTF-16LE -t UTF-8 "$m3ufile" > "$tmpfile"
            ;;
        utf-16be | utf-16-be)
            iconv -f UTF-16BE -t UTF-8 "$m3ufile" > "$tmpfile"
            ;;
        iso-8859-* | windows-1252 | latin-*)
            # WINDOWS-1252 is a superset of ISO-8859-1; iconv accepts both names.
            # Fall back to a plain copy if iconv fails on an unknown variant.
            iconv -f WINDOWS-1252 -t UTF-8 "$m3ufile" > "$tmpfile" 2>/dev/null \
                || cp "$m3ufile" "$tmpfile"
            ;;
        *)
            # utf-8, us-ascii, or anything unrecognised -- copy as-is
            cp "$m3ufile" "$tmpfile"
            ;;
    esac
else
    # Fallback: detect BOM via raw hex bytes.
    # od -An -tx1 prints hex bytes without an address; tr strips whitespace.
    first2=$(head -c 2 "$m3ufile" | od -An -tx1 | tr -d ' \n')
    case "$first2" in
        fffe) iconv -f UTF-16LE -t UTF-8 "$m3ufile" > "$tmpfile" ;;
        feff) iconv -f UTF-16BE -t UTF-8 "$m3ufile" > "$tmpfile" ;;
        *)    cp "$m3ufile" "$tmpfile" ;;
    esac
fi

counter=1

while IFS= read -r line || [ -n "$line" ]; do
    # Remove Windows carriage returns (handles both \r\n and \n line endings)
    line="${line//$'\r'/}"

    # Trim leading whitespace (POSIX parameter expansion, no external tools needed)
    line="${line#"${line%%[![:space:]]*}"}"
    # Trim trailing whitespace
    line="${line%"${line##*[![:space:]]}"}"

    if [[ -n "$line" && "$line" != \#* ]]; then
        decoded_line=$(urldecode "$line")
        files+=("$decoded_line")
    fi
done < "$tmpfile"

rm -f "$tmpfile"

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
        # basename -- guards against filenames beginning with a dash
        filename=$(basename -- "$path")

        # Create filename based on --no-mixtape flag
        if [ "$no_mixtape" = true ]; then
            new_filename="$filename"
        else
            # Use printf to format counter with leading zeros
            new_filename=$(printf "%03d_%s" "$counter" "$filename")
        fi

        # cp -- guards against source paths beginning with a dash;
        # double-quoting handles spaces, apostrophes, and square brackets
        cp -- "$path" "$dest/$new_filename"
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
