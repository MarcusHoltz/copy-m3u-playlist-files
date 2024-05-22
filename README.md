# 🎶 Copy music files in a playlist for export 💿

This script will: 

- Collect files in your music playlist

- Order the songs

- Copy them into a new directory. 


Now can burn your collection to a CD, or send the playlist to friends. 👍


* * *

## Using copy-m3u-playlist-files-to-directory

The script can, optionally, take two arguments:

- The name of the m3u playlist file.

- The location to place the contents of the playlist. 

> If neither is specified, the script defaults to `playlist.m3u` and `current working directory`.


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
copy-m3u-playlist-files-to-directory.ps1 name-of-your-playlist.m3u C:\path\to\destination\somefolder\
```


* * * 

### Python

To run this as a cross-platform Python script:

```
python copy-m3u-playlist-files-to-directory.py example-playlist.m3u /path/to/destination
```


* * *

* * *

## Thanks!

Thanks hope this helps someone also trying to accomplish the same task. 😎
