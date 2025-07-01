# qBittorrent Torrent File Whitelist

A shell script to filter and clean torrents automatically in qBittorrent, by only allowing whitelisted file extensions (like .mp4, .mkv, etc.) in selected categories (e.g. tv, movies).
If a torrent contains no allowed files, it is deleted; if it contains mixed files, non-allowed files are disabled.

## Why?

There’s an increasing number of torrents containing non-video files (e.g. .arj, .001, .uue) often associated with junk or malware.
Sonarr/Radarr and qBittorrent don’t filter these for you, leading to wasted disk writes, unnecessary seeding, and sharing potential junk.
This script enforces a strict whitelist for torrent content, applied only to your specified categories.

## Usage

1. **Copy and configure your `.env` file**  
   Use `.env.example` as a template. Fill in your qBittorrent URL, username, password, log path, and allowed extensions.

2. **Configure qBittorrent**  
   In qBittorrent’s “Run external program on torrent added”, set this script with arguments:
   ```sh
   /path/to/qbt-torrent-file-whitelist.sh "%I" "%C"
   ```
   > **Note:** The script (and the `.env` file) must be accessible and executable by the same user running qBittorrent.
   > - If you use Docker, mount the script and `.env` into the container and set appropriate permissions.
   > - On Synology, make sure the script path is accessible to the `qbittorrent` user or group.

3. **Set permissions**
   Make sure the script is executable and that `.env` is readable (but not world-readable).

4. **Monitor logs**
   Log output is controlled via the `LOGFILE` path in your `.env`.

## Example .env

```sh
QB_URL="http://localhost:8080"
QB_USER="user"
QB_PASS="pass"
LOGFILE="/tmp/on-torrent-added.log"
COOKIE_JAR="/tmp/qbt-cookies.txt"
ALLOWED_EXTENSIONS="mp4|mkv|avi|mov|wmv|flv|webm|mpeg|mpg|ts|m4v"
FILTER_CATEGORIES="tv|movies"
```

## Requirements

- `jq`
- `curl`
- Shell: `/bin/sh` (POSIX), tested on Synology Docker

## Important: Line Endings

> **Make sure all files (including `.env`, scripts, and configs) use Unix line endings (LF), not Windows (CRLF).**
> If you edit files on Windows with VS Code or another editor, always convert/save with LF.
> Wrong line endings (CRLF) will break the script or prevent authentication.

## Troubleshooting

- If nothing happens when torrents are added, check:
  - Script path and permissions.
  - That `jq` and `curl` are installed and in PATH for qBittorrent’s environment.
  - Log output at the location specified in your `.env`.

- If the script fails with login errors or strange issues, check that all files use **LF (Unix) line endings**.
  - In VS Code, click `CRLF` in the bottom-right and change to `LF`, then save the file.
  - On Linux/Mac, you can run `dos2unix yourfile.sh` to convert.
