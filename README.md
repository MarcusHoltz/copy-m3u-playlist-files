# [ 🎶 ](https://github.com/MarcusHoltz/marcusholtz.github.io/blob/main/assets/html/Internet-Radio-Stations.m3u) Copy music files in a playlist for export [ 💿 ](https://github.com/MarcusHoltz/marcusholtz.github.io/blob/main/assets/html/Internet-Radio-Stations.m3u)

This script will: 

- Collect files in your music playlist

- Order the songs

- Copy them into a new directory. 


Now can now burn your collection to a CD, or send the playlist to friends. 👍


* * *

## Using copy-m3u-playlist-files-to-directory

The script can, optionally, take three arguments:

- The name of the m3u playlist file.

- The location to place the contents of the playlist. 

- The `--no-mixtape` flag will copy files with their original names (no numbered track prefixes).

> If none of this is specified, the script defaults to `playlist.m3u` and `current working directory`.


* * *

## Examples


* * * 


### Linux 

Using the bash version of this script as an example, run this Bash script with a command like:

```
bash copy-m3u-playlist-files-to-directory.sh name-of-playlist.m3u /home/user/Music/somefiles
```

* * * 

### Windows

Run this Powershell version of this script with a command like:

```
Unblock-File .\copy-m3u-playlist-files-to-directory.ps1
copy-m3u-playlist-files-to-directory.ps1 name-of-your-playlist.m3u C:\path\to\destination\somefolder\ -SkipMissing -Verbose
```


* * * 

### Python

To run this as a cross-platform Python script:

```
python3 copy-m3u-playlist-files-to-directory.py name-of-your-playlist.m3u /path/to/destination
```


* * *

### No playlist order in filenames

To copy your files, with the same filenames - no numbers infront to indicate their order in the playlist, add `--no-mixtape` or `-nomixtape` to the script execution. This feature works on all the scripts:

```
python3 copy-m3u-playlist-files-to-directory.py --no-mixtape name-of-your-playlist.m3u /path/to/destination
```



* * *

* * *

## Thanks!

Thanks hope this helps someone also trying to accomplish the same task. 😎
